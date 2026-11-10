"""Validation checks. Any FAIL makes the build fail. Writes data/build/validation_report.md and .json."""
import json, re, sqlite3, unicodedata, collections
from lxml import etree
import books, importers
from paths import *
from sources import DEFAULT_OK, PERSONAL_OK

HEB_LETTER = re.compile("[\u05D0-\u05EA\uFB1D-\uFB4F]")
HEB_POINT = re.compile("[\u05B0-\u05BC\u05C1\u05C2\u05C7]")
HEB_ACCENT = re.compile("[\u0591-\u05AF]")
CODE = {b["order"]: b["code"] for b in books.BOOKS}

class Report:
    def __init__(self): self.checks = []
    def add(self, name, ok, detail, samples=None, warn=False):
        self.checks.append(dict(check=name, status="PASS" if ok else ("WARN" if warn else "FAIL"), detail=detail, samples=(samples or [])[:15]))

def counts(con, version):
    q = """SELECT b.code, COUNT(*), COUNT(DISTINCT v.chapter) FROM verse v JOIN version x ON x.id=v.version_id JOIN book b ON b.id=v.book_id
           WHERE x.code=? AND v.verse>0 GROUP BY b.code"""
    return {r[0]: (r[1], r[2]) for r in con.execute(q, (version,))}

def verse_set(con, version):
    q = "SELECT v.book_id, v.chapter, v.verse FROM verse v JOIN version x ON x.id=v.version_id WHERE x.code=? AND v.verse>0"
    return set(con.execute(q, (version,)))

def wlc_counts():
    per_book = {}; per_ch = {}
    for f in sorted(WLC.glob("*.xml")):
        if f.stem == "VerseMap": continue
        for m in re.finditer(r'<verse osisID="([^".]+)\.(\d+)\.(\d+)"', f.read_text(encoding="utf-8")):
            b = books.code(m.group(1)); per_book[b] = per_book.get(b, 0) + 1
            per_ch[(b, int(m.group(2)))] = per_ch.get((b, int(m.group(2))), 0) + 1
    return per_book, per_ch

def run(path, personal=False, build_log=None, write_baseline=False, report_stem=None):
    con = sqlite3.connect(path); R = Report()
    versions = [r[0] for r in con.execute("SELECT code FROM version WHERE has_text=1 ORDER BY id")]
    allc = {v: counts(con, v) for v in versions}

    # 1. Reference invariants
    kjv = allc["eng-kjv2006"]
    tot = sum(n for n, _ in kjv.values()); chs = sum(c for _, c in kjv.values())
    R.add("KJV reference scheme totals", tot == 31102 and chs == 1189 and len(kjv) == 66, f"eng-kjv2006: {tot} verses, {chs} chapters, {len(kjv)} books (expected 31102, 1189, 66)")
    wb, wc = wlc_counts()
    tah = {}; tahc = {}
    for b, c, n in con.execute("SELECT b.code, v.chapter, COUNT(*) FROM verse v JOIN version x ON x.id=v.version_id JOIN book b ON b.id=v.book_id WHERE x.code='tahot' GROUP BY 1,2"):
        tah[b] = tah.get(b, 0) + n; tahc[(b, c)] = n
    bad = [f"{k}: TAHOT {tahc.get(k)} vs WLC {wc.get(k)}" for k in sorted(set(wc) | set(tahc)) if wc.get(k) != tahc.get(k)]
    R.add("Hebrew verse counts per chapter, TAHOT vs Westminster Leningrad Codex (OSHB)", not bad,
          f"{sum(wb.values())} WLC verses in {len(wc)} chapters; {sum(tah.values())} TAHOT verses; {len(bad)} chapters differ", bad)

    # 2. Verse counts per book against the reviewed baseline
    base_path = EXPECTED / ("verse_counts_personal.tsv" if personal else "verse_counts.tsv")
    if write_baseline:
        with open(base_path, "w") as f:
            f.write("version\tbook\tverses\tchapters\n")
            for v in versions:
                for b, (n, c) in sorted(allc[v].items(), key=lambda x: books.BY_CODE[x[0]]["order"]):
                    f.write(f"{v}\t{b}\t{n}\t{c}\n")
        write_reference_diff(con, versions, allc, wb)
    base = collections.defaultdict(dict)
    if base_path.exists():
        for line in open(base_path).read().splitlines()[1:]:
            v, b, n, c = line.split("\t"); base[v][b] = (int(n), int(c))
    bad = []; checked = 0
    for v in versions:
        exp = base.get(v)
        if not exp: bad.append(f"{v}: no expected counts in {base_path.name}"); continue
        for b in sorted(set(exp) | set(allc[v])):
            checked += 1
            if exp.get(b) != allc[v].get(b): bad.append(f"{v} {b}: expected {exp.get(b)} got {allc[v].get(b)} (verses, chapters)")
    for v in base:
        if v not in versions: bad.append(f"{v}: in baseline but not built")
    R.add("Verse counts per book for every version vs expected table", not bad, f"{len(versions)} versions, {checked} version and book pairs checked, {len(bad)} mismatches", bad)

    # 3. Hebrew vowel points, accents
    nolet = 0; missing = []; accents = collections.Counter(); per_book_words = collections.Counter(); total = 0
    for b, c, v, p, t in con.execute("SELECT w.book_id, w.chapter, w.verse, w.position, w.text_src FROM word w JOIN version x ON x.id=w.version_id WHERE x.code='tahot'"):
        total += 1
        if not HEB_LETTER.search(t): nolet += 1; continue
        per_book_words[CODE[b]] += 1
        if not HEB_POINT.search(t): missing.append(f"{CODE[b]} {c}:{v} #{p} {t}")
        if HEB_ACCENT.search(t): accents[CODE[b]] += 1
    R.add("Every Hebrew word with letters has vowel points", not missing and total > 0,
          f"{total} TAHOT words; {total-nolet} contain Hebrew letters; {len(missing)} lack vowel points; {nolet} entries have no Hebrew letters", missing)
    noacc = [b for b in per_book_words if accents[b] == 0]
    R.add("Cantillation accents present in every Hebrew book", not noacc, f"{len(per_book_words)} books; words with accents: {sum(accents.values())}", noacc)

    # 4. Hebrew byte identical to source
    db_words = {}; dupref = 0
    for r, t in con.execute("SELECT w.src_ref, w.text_src FROM word w JOIN version x ON x.id=w.version_id WHERE x.code='tahot'"):
        if r in db_words: dupref += 1
        db_words[r] = t
    mism = []; seen = 0; nfc_diff = 0; src_bytes = 0
    for m, p in importers.tahot_rows():
        seen += 1; src_bytes += len(p[1].encode())
        got = db_words.pop(p[0], None)
        if got is None or got.encode("utf-8") != p[1].encode("utf-8"): mism.append(p[0])
        if unicodedata.normalize("NFC", p[1]) != p[1]: nfc_diff += 1
    extra = len(db_words)
    if dupref: mism.append(f"{dupref} duplicate source references in database")
    R.add("Hebrew text byte identical to TAHOT source", not mism and not extra and seen > 0,
          f"{seen} source words ({src_bytes} bytes) compared; {len(mism)} differ; {extra} extra in database. {nfc_diff} words would have changed under NFC normalisation, which the pipeline never applies.", mism)

    # 5. Strong's ids resolve
    lex = collections.defaultdict(set); lexbase = collections.defaultdict(set)
    for s, k, base_ in con.execute("SELECT source_id, strong, base_strong FROM lexicon"):
        lex[s].add(k); lexbase[s].add(base_)
    rules = [("tahot", "step-tbesh"), ("tagnt", "step-tbesg"), ("byz-rp2018", "os-strongs-grk"), ("nestle1904", "os-strongs-grk")]
    for vcode, lsrc in rules:
        un = collections.Counter(); n = 0; via_base = collections.Counter()
        for (s,) in con.execute("SELECT ws.strong FROM word_strong ws JOIN word w ON w.id=ws.word_id JOIN version x ON x.id=w.version_id WHERE x.code=?", (vcode,)):
            n += 1
            if s in lex[lsrc] or (len(s) == 5 and s in lexbase[lsrc]): continue
            if s[:5] in lexbase[lsrc]: via_base[s] += 1; continue
            un[s] += 1
        nwords = con.execute("SELECT COUNT(*), SUM(strong_ids IS NULL OR strong_ids='') FROM word w JOIN version x ON x.id=w.version_id WHERE x.code=?", (vcode,)).fetchone()
        R.add(f"Strong's ids resolve: {vcode} in {lsrc}", not un and n > 0,
              f"{n} Strong's links on {nwords[0]} words ({nwords[1]} words carry no Strong's id); {sum(via_base.values())} links to {len(via_base)} extended ids resolve only to their base number ({', '.join(f'{k} x{c}' for k, c in via_base.most_common(6))}); {sum(un.values())} links do not resolve",
              [f"{k} x{v}" for k, v in un.most_common(15)])

    # 6. Cross references resolve to verses that exist (English KJV numbering)
    kv = verse_set(con, "eng-kjv2006"); wv = verse_set(con, "sblgnt"); bad = []; n = 0; web_only = 0
    for r in con.execute("SELECT from_book,from_chapter,from_verse,to_book,to_chapter,to_verse,to_end_book,to_end_chapter,to_end_verse FROM crossref"):
        n += 1; used_web = False
        for i in (0, 3, 6):
            if r[i] is None: continue
            k = (r[i], r[i+1], r[i+2])
            if k in kv: continue
            if k in wv: used_web = True; continue
            bad.append(f"{CODE[r[0]]} {r[1]}:{r[2]} -> {CODE[r[i]]} {r[i+1]}:{r[i+2]}"); break
        web_only += used_web
    R.add("Cross references resolve to existing verses (KJV scheme, or SBLGNT numbering where the KJV has no such verse)", not bad and n > 0,
          f"{n} cross references; {n-web_only-len(bad)} resolve in the KJV; {web_only} resolve only in the SBLGNT numbering (3 John 1:15, which the KJV joins to 1:14); {len(bad)} do not resolve", bad)

    # 7. Credits
    used = set(r[0] for r in con.execute("SELECT source_id FROM version_source UNION SELECT source_id FROM lexicon UNION SELECT source_id FROM crossref UNION SELECT source_id FROM versification_map UNION SELECT 'oshb-wlc'"))
    rows = {r[0]: r for r in con.execute("SELECT id, credit, licence_url, licence_class, url FROM source")}
    bad = [s for s in used if s not in rows or not all(rows[s][1:])]
    R.add("Every source has a credits row with licence", not bad, f"{len(used)} sources used, {len(rows)} source rows", bad)

    # 8. Licence gate
    allowed = PERSONAL_OK if personal else DEFAULT_OK
    bad = [f"{s}: {r[3]}" for s, r in rows.items() if r[3] not in allowed]
    R.add("Licence gate (" + ("personal" if personal else "default, App Store safe") + " build)", not bad,
          "allowed classes: " + ", ".join(sorted(allowed)) + "; classes present: " + ", ".join(f"{k} x{v}" for k, v in collections.Counter(r[3] for r in rows.values()).items()), bad)

    # 9. Non empty verse text (warning only)
    empty = [f"{a} {CODE[b]} {c}:{v}" for a, b, c, v in con.execute("SELECT x.code, v.book_id, v.chapter, v.verse FROM verse v JOIN version x ON x.id=v.version_id WHERE trim(v.text)=''")]
    R.add("Verses with empty text (warning only)", not empty, f"{len(empty)} empty verse rows", empty, warn=True)

    # 10. FTS integrity
    has_fts = con.execute("SELECT 1 FROM sqlite_master WHERE name='verse_fts'").fetchone()
    if has_fts:
        con.execute("INSERT INTO verse_fts(verse_fts, rank) VALUES('integrity-check', 1)")
        from build import fold
        tests = {q: con.execute("SELECT COUNT(*) FROM verse_fts WHERE verse_fts MATCH ?", ('"' + fold(q) + '"',)).fetchone()[0] for q in ("beginning", "θεος", "אלהים")}
        R.add("Full text search index integrity", all(tests.values()), "integrity check passed; test queries: " + ", ".join(f"{k} returns {n} verses" for k, n in tests.items()))

    # summary and size
    size = path.stat().st_size
    stats = dict(file=str(path), size_bytes=size, versions_with_text=len(versions),
                 verses=con.execute("SELECT COUNT(*) FROM verse").fetchone()[0], words=con.execute("SELECT COUNT(*) FROM word").fetchone()[0],
                 lexicon_entries=con.execute("SELECT COUNT(*) FROM lexicon").fetchone()[0], crossrefs=con.execute("SELECT COUNT(*) FROM crossref").fetchone()[0],
                 versification_rows=con.execute("SELECT COUNT(*) FROM versification_map").fetchone()[0])
    try:
        stats["table_mb"] = {r[0]: round(r[1] / 1e6, 1) for r in con.execute("SELECT name, SUM(pgsize) FROM dbstat GROUP BY name ORDER BY 2 DESC")}
    except sqlite3.Error:
        pass
    con.close()
    write_report(path, R, stats, build_log, personal, report_stem)
    fails = [c for c in R.checks if c["status"] == "FAIL"]
    for c in R.checks: print(f"  {c['status']}  {c['check']}: {c['detail']}")
    return not fails

def write_reference_diff(con, versions, allc, wlc):
    """For review: how each version differs from its reference scheme, verse by verse."""
    ref_for = {}
    for code, scheme in con.execute("SELECT code, scheme FROM version WHERE has_text=1"):
        ref_for[code] = {"KJV": "eng-kjv2006", "Vulgate": "eng-kjv2006", "Hebrew": "tahot", "LXX": "eng-Brenton"}[scheme]
    sets = {}
    lines = ["# Verse differences against each version's reference scheme", "",
             "Reference: KJV scheme is eng-kjv2006 (and eng-kjv for deuterocanon), Hebrew scheme is TAHOT (checked against WLC), Septuagint scheme is eng-Brenton.",
             "Generated by build.py --write-baseline for review. Counts exclude verse 0 (Psalm titles).", ""]
    for v in versions:
        r = ref_for[v]
        if v == r: continue
        for x in (v, r, "eng-kjv"):
            if x not in sets: sets[x] = verse_set(con, x)
        mine = sets[v]; ref = sets[r] | (sets["eng-kjv"] if r == "eng-kjv2006" else set())
        mb = {b for b, _, _ in mine}
        refb = {k for k in ref if k[0] in mb}
        miss = sorted(refb - mine); extra = sorted(mine - refb)
        if not miss and not extra: lines.append(f"## {v} (vs {r}): identical in the books it contains"); lines.append(""); continue
        lines.append(f"## {v} (vs {r}): {len(miss)} reference verses absent, {len(extra)} extra")
        fmt = lambda xs: ", ".join(f"{CODE[b]} {c}:{vv}" for b, c, vv in xs[:60]) + (" ..." if len(xs) > 60 else "")
        if miss: lines.append(f"* absent: {fmt(miss)}")
        if extra: lines.append(f"* extra: {fmt(extra)}")
        lines.append("")
    (EXPECTED / "reference_differences.md").write_text("\n".join(lines))

def write_report(path, R, stats, build_log, personal, report_stem=None):
    stem = report_stem or ("validation_report_personal" if personal else "validation_report")
    (BUILD / f"{stem}.json").write_text(json.dumps(dict(stats=stats, checks=R.checks, build_log=build_log), indent=1, ensure_ascii=False))
    n = collections.Counter(c["status"] for c in R.checks)
    L = [f"# Validation report ({'personal' if personal else 'default'} build)", "",
         f"Database: `{path.name}`, {stats['size_bytes']/1e6:.1f} MB. Result: {n['PASS']} passed, {n['FAIL']} failed, {n['WARN']} warnings.", "",
         "| Check | Status | Detail |", "|---|---|---|"]
    for c in R.checks: L.append(f"| {c['check']} | {c['status']} | {c['detail']} |")
    L.append("")
    for c in R.checks:
        if c["samples"] and c["status"] != "PASS":
            L.append(f"## {c['check']}"); L += [f"* {s}" for s in c["samples"]]; L.append("")
    L += ["## Contents", ""] + [f"* {k}: {v}" for k, v in stats.items() if k != "table_mb"]
    if "table_mb" in stats: L += ["", "## Size by table (MB)", ""] + [f"* {k}: {v}" for k, v in stats["table_mb"].items()]
    if build_log:
        L += ["", "## Build log", ""] + [f"* {json.dumps(x, ensure_ascii=False)}" for x in build_log]
    (BUILD / f"{stem}.md").write_text("\n".join(L) + "\n")
