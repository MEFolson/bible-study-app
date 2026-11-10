"""All importers. Each returns a small stats dict for the build log. No text is Unicode normalised anywhere."""
import csv, re, zipfile
from lxml import etree
import books
from db import BOOK_ID, add_version, add_source
from paths import *

def bid(src_code): return BOOK_ID[books.code(src_code)]

# ---------------- USFM (eBible.org) ----------------
DROP_LINE = re.compile(r"^\\(s\d?|ms\d?|mr|r|sr|sp|cl|cd|qa|toc\d|toca\d|h|mt\d?|mte\d?|imt\d?|ip|ipi|is\d?|io\d?|iot|ie|rem|sts|id|ide|usfm|restore|periph|ili\d?|im|imq|ipq|iq\d?|ib|iex|mte)\b")
TITLE_LINE = re.compile(r"^\\d\b\s*(.*)")
def clean_usfm(s):
    s = re.sub(r"\\f\s.*?\\f\*", "", s, flags=re.S)
    s = re.sub(r"\\fe\s.*?\\fe\*", "", s, flags=re.S)
    s = re.sub(r"\\x\s.*?\\x\*", "", s, flags=re.S)
    s = re.sub(r"\\(va|vp|ca|cp)\s.*?\\\1\*", "", s, flags=re.S)
    s = re.sub(r"\\\+?w\s([^\\|]*?)(\|[^\\]*?)?\\\+?w\*", r"\1", s, flags=re.S)
    s = re.sub(r"\|[a-z\-]+=\"[^\"]*\"", "", s)
    s = re.sub(r"\\\+?[a-z]+\d*\*?", " ", s)
    return re.sub(r"\s+", " ", s).strip()

def parse_usfm(text):
    """yield (book, chapter, verse, verse_end, text). Psalm titles (\\d) become verse 0."""
    book = None; ch = 0; out = []; cur = None; buf = []
    def flush():
        if cur is not None:
            out.append((*cur, clean_usfm(" ".join(buf))))
    for line in text.splitlines():
        line = line.strip()
        if not line: continue
        m = re.match(r"^\\id\s+(\S+)", line)
        if m: book = m.group(1); continue
        m = TITLE_LINE.match(line)
        if m and book:
            flush(); buf = [m.group(1)]; cur = (book, ch, 0, None); continue
        if DROP_LINE.match(line): continue
        for part in re.split(r"(?=\\c\s+\d+)|(?=\\v\s+\S+)", line):
            mc = re.match(r"^\\c\s+(\d+)\s*(.*)", part, re.S)
            mv = re.match(r"^\\v\s+(\d+)[a-z]?(?:[-\u2010\u2011,](\d+)[a-z]?)?\S*\s*(.*)", part, re.S)
            if mc:
                flush(); cur = None; buf = []; ch = int(mc.group(1)); rest = mc.group(2)
            elif mv:
                flush(); buf = [mv.group(3)]; cur = (book, ch, int(mv.group(1)), int(mv.group(2)) if mv.group(2) else None)
            else:
                if cur is not None: buf.append(part)
    flush()
    return out

SKIP_USFM = {"FRT", "BAK", "GLO", "OTH", "INT", "CNC", "TDX", "NDX", "XXA", "XXB", "XXC", "XXD", "XXE", "XXF", "XXG"}
def import_usfm(con, zpath, code, name, language, scheme, source_id):
    vid = add_version(con, code, name, language, scheme, source_id, True, False)
    rows = {}; dups = 0; unknown = set()
    with zipfile.ZipFile(zpath) as z:
        for nm in sorted(z.namelist()):
            if not nm.lower().endswith(".usfm"): continue
            for bk, ch, vs, ve, txt in parse_usfm(z.read(nm).decode("utf-8-sig")):
                if bk in SKIP_USFM: continue
                if bk not in BOOK_ID: unknown.add(bk); continue
                if vs == 0 and not txt: continue
                key = (BOOK_ID[bk], ch, vs)
                if key in rows:
                    dups += 1; rows[key][1] = (rows[key][1] + " " + txt).strip()
                else:
                    rows[key] = [ve, txt]
    con.executemany("INSERT INTO verse(version_id,book_id,chapter,verse,verse_end,text) VALUES (?,?,?,?,?,?)",
        [(vid, b, c, v, ve, t) for (b, c, v), (ve, t) in rows.items()])
    if unknown: raise SystemExit(f"{code}: unknown USFM books {unknown}")
    return dict(version=code, verses=len(rows), merged_duplicates=dups)

# ---------------- STEP Bible TAHOT ----------------
TAHOT_REF = re.compile(r"^(\w+)\.(\d+)\.(\d+)(?:\((\d+)\.(\d+)\))?#(\d+)=(\S+)$")
HSTRONG = re.compile(r"H\d{4}[A-Za-z]?")
def tahot_rows():
    for f in TAHOT:
        with open(f, encoding="utf-8", newline="") as fh:
            for line in fh:
                p = line.rstrip("\r\n").split("\t")
                m = TAHOT_REF.match(p[0])
                if not m or len(p) < 6: continue
                yield m, p

def import_tahot(con):
    vid = add_version(con, "tahot", "Hebrew OT (STEP Bible TAHOT, Leningrad Codex)", "hbo", "Hebrew", "step-tahot", True, True, direction="rtl",
        notes="Words exactly as published in TAHOT; verse numbering is Hebrew, alt_ref holds the English reference where it differs. Rows of type X (LXX additions from the BHS apparatus) are kept as words but left out of the verse text.")
    words = []; verses = {}; seq = {}
    for m, p in tahot_rows():
        bk, ec, ev, hc, hv, pos, typ = m.groups()
        b = bid(bk); ch, vs = (int(hc), int(hv)) if hc else (int(ec), int(ev))
        alt = f"{books.code(bk)} {ec}:{ev}" if hc else None
        src = p[1]; disp = src.replace("/", "").replace("\\", "")
        strong = p[4]; ids = " ".join(dict.fromkeys(HSTRONG.findall(strong)))
        lem = None
        if len(p) > 11:
            lm = re.search(r"\{H\d{4}[A-Za-z]?=([^=}]+)=", p[11]); lem = lm.group(1) if lm else None
        k = (b, ch, vs); seq[k] = seq.get(k, 0) + 1
        words.append((vid, b, ch, vs, seq[k], p[0], alt, typ, src, disp, p[2], p[3], strong, ids, lem, p[5]))
        if not typ.startswith("X"):
            verses.setdefault((b, ch, vs), [alt, []])[1].append(disp)
    con.executemany("INSERT INTO word(version_id,book_id,chapter,verse,position,src_ref,alt_ref,word_type,text_src,text,translit,gloss,strong,strong_ids,lemma,morph) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", words)
    def join(ws):
        out = ""
        for w in ws:
            out += w if (not out or out.endswith("\u05be")) else " " + w
        return out
    con.executemany("INSERT INTO verse(version_id,book_id,chapter,verse,alt_ref,text) VALUES (?,?,?,?,?,?)",
        [(vid, b, c, v, a, join(ws)) for (b, c, v), (a, ws) in verses.items()])
    return dict(version="tahot", words=len(words), verses=len(verses))

# ---------------- STEP Bible TAGNT ----------------
TAGNT_REF = re.compile(r"^(\w+)\.(\d+)\.(\d+)(?:\((\d+)\.(\d+)\))?#(\d+)=(\S+)$")
GSTRONG = re.compile(r"G\d{4}[A-Za-z]?")
def import_tagnt(con):
    vid = add_version(con, "tagnt", "Greek NT (STEP Bible TAGNT, all editions tagged)", "grc", "KJV", "step-tagnt", False, True,
        notes="Word level only. The editions column lists which printed editions contain each word.")
    words = []
    for f in TAGNT:
        for line in open(f, encoding="utf-8"):
            p = line.rstrip("\r\n").split("\t")
            m = TAGNT_REF.match(p[0])
            if not m or len(p) < 6: continue
            bk, c, v, ac, av, pos, typ = m.groups()
            gk = p[1]; mt = re.match(r"^(.*?)\s*\(([^)]*)\)\s*$", gk)
            text, tr = (mt.group(1), mt.group(2)) if mt else (gk, None)
            st, _, mo = p[3].partition("=")
            lem = p[4].split("=")[0] if p[4] else None
            alt = f"{books.code(bk)} {ac}:{av}" if ac else None
            words.append((vid, bid(bk), int(c), int(v), int(pos), p[0], alt, typ, text, text, tr, p[2], p[3], " ".join(dict.fromkeys(GSTRONG.findall(st))), lem, mo, p[5]))
    con.executemany("INSERT INTO word(version_id,book_id,chapter,verse,position,src_ref,alt_ref,word_type,text_src,text,translit,gloss,strong,strong_ids,lemma,morph,editions) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", words)
    return dict(version="tagnt", words=len(words))

# ---------------- Greek NT plain columns ----------------
def import_sblgnt(con):
    vid = add_version(con, "sblgnt", "SBL Greek New Testament", "grc", "KJV", "sblgnt", True, False)
    rows = []
    for f in sorted(SBLGNT.glob("*.txt")):
        for line in open(f, encoding="utf-8-sig"):
            m = re.match(r"^(\S+) (\d+):(\d+)\t(.*)$", line.rstrip("\r\n"))
            if m: rows.append((vid, bid(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4).strip()))
    con.executemany("INSERT INTO verse(version_id,book_id,chapter,verse,text) VALUES (?,?,?,?,?)", rows)
    return dict(version="sblgnt", verses=len(rows))

def import_byz(con):
    vid = add_version(con, "byz-rp2018", "Robinson Pierpont Byzantine Text 2018", "grc", "KJV", "byz-rp2018", True, True,
        notes="Verse text is the accented Unicode edition. Words come from the unaccented Strong's and parsing files, as published.")
    rows = []; words = []
    for f in sorted(BYZ_TEXT.glob("*.csv")):
        if f.stem in ("PA", "ACT24"): continue  # alternate passages; the main files already hold these verses
        b = bid(f.stem)
        for r in csv.DictReader(open(f, encoding="utf-8-sig")):
            rows.append((vid, b, int(r["chapter"]), int(r["verse"]), r["text"].strip()))
        wf = BYZ_WORDS / f.name
        for r in csv.DictReader(open(wf, encoding="utf-8-sig")):
            toks = re.findall(r"\{[^}]*\}|\S+", r["text"]); pos = 0; cur = None
            for t in toks:
                if t.startswith("{"):
                    if cur: cur[2] = t.strip("{}")
                elif t.isdigit():
                    if cur: cur[1].append("G" + str(int(t)).zfill(4))
                else:
                    if cur: words.append(cur)
                    pos += 1; cur = [t, [], None, int(r["chapter"]), int(r["verse"]), pos, b]
            if cur: words.append(cur)
    con.executemany("INSERT INTO verse(version_id,book_id,chapter,verse,text) VALUES (?,?,?,?,?)", rows)
    con.executemany("INSERT INTO word(version_id,book_id,chapter,verse,position,text_src,text,strong,strong_ids,morph) VALUES (?,?,?,?,?,?,?,?,?,?)",
        [(vid, w[6], w[3], w[4], w[5], w[0], w[0], " ".join(w[1]), " ".join(w[1]), w[2]) for w in words])
    return dict(version="byz-rp2018", verses=len(rows), words=len(words))

def import_n1904(con):
    vid = add_version(con, "nestle1904", "Nestle 1904 Greek New Testament", "grc", "KJV", "nestle1904", True, True,
        notes="Verse text is built by joining the published words of the morphology file, with their punctuation.")
    words = []; verses = {}; pos = {}
    with open(N1904, encoding="utf-8-sig") as fh:
        for r in csv.DictReader(fh, delimiter="\t"):
            m = re.match(r"^(\S+) (\d+):(\d+)$", r["BCV"].strip())
            if not m: continue
            b, c, v = bid(m.group(1)), int(m.group(2)), int(m.group(3))
            k = (b, c, v); pos[k] = pos.get(k, 0) + 1
            ids = " ".join("G" + str(int(x)).zfill(4) for x in re.findall(r"\d+", (r["strongs"] or "").split("&")[0]))  # after & is a tense voice mood code
            words.append((vid, b, c, v, pos[k], r["text"], r["text"], r["strongs"], ids, r["lemma"], r["func_morph"]))
            verses.setdefault(k, []).append(r["text"])
    con.executemany("INSERT INTO word(version_id,book_id,chapter,verse,position,text_src,text,strong,strong_ids,lemma,morph) VALUES (?,?,?,?,?,?,?,?,?,?,?)", words)
    con.executemany("INSERT INTO verse(version_id,book_id,chapter,verse,text) VALUES (?,?,?,?,?)", [(vid, *k, " ".join(w)) for k, w in verses.items()])
    return dict(version="nestle1904", verses=len(verses), words=len(words))

# ---------------- Septuagint: Swete (First1KGreek, CC BY SA) ----------------
TLG = {1:"GEN",2:"EXO",3:"LEV",4:"NUM",5:"DEU",6:"JOS",8:"JDG",10:"RUT",11:"1SA",12:"2SA",13:"1KI",14:"2KI",15:"1CH",16:"2CH",
       17:"1ES",18:"EZR",19:"ESG",20:"JDT",21:"TOB",23:"1MA",24:"2MA",25:"3MA",26:"4MA",27:"PSA",28:"ODA",29:"PRO",30:"ECC",31:"SNG",
       32:"JOB",33:"WIS",34:"SIR",35:"PSS",36:"HOS",37:"AMO",38:"MIC",39:"JOL",40:"OBA",41:"JON",42:"NAM",43:"HAB",44:"ZEP",45:"HAG",
       46:"ZEC",47:"MAL",48:"ISA",49:"JER",50:"BAR",51:"LAM",52:"LJE",53:"EZK",54:"SUS",55:"SUS",56:"DAN",57:"DAN",58:"BEL",59:"BEL"}
OG = {54, 56, 58}          # Old Greek forms of Susanna, Daniel, Bel go to their own column
TH = {55, 57, 59}          # Theodotion forms go to the main column, as in most editions
TEI = "{http://www.tei-c.org/ns/1.0}"
def f1k_book(path):
    tree = etree.parse(str(path))
    body = tree.find(f".//{TEI}body")
    etree.strip_elements(body, f"{TEI}note", f"{TEI}head", f"{TEI}fw", f"{TEI}bibl", with_tail=False)
    out = {}; anomalies = []
    for chd in body.iter(f"{TEI}div"):
        if chd.get("subtype") != "chapter": continue
        cn = chd.get("n", "")
        c = int(cn) if cn.isdigit() else 0
        if not cn.isdigit(): anomalies.append(f"chapter n={cn!r} stored as chapter 0")
        for vd in chd.iter(f"{TEI}div"):
            if vd.get("subtype") != "verse": continue
            vn = vd.get("n", ""); mv = re.match(r"^(\d+)", vn)
            if not mv: anomalies.append(f"verse n={vn!r} in chapter {cn} skipped"); continue
            v = int(mv.group(1))
            if vn != mv.group(1): anomalies.append(f"verse n={vn!r} merged into {c}:{v}")
            txt = re.sub(r"\s+", " ", "".join(vd.itertext())).strip()
            txt = re.sub(r"(\w)- (\w)", r"\1\2", txt)  # rejoin words hyphenated at printed line breaks
            out[(c, v)] = (out[(c, v)] + " " + txt).strip() if (c, v) in out else txt
    return out, anomalies

def import_swete(con):
    main = add_version(con, "swete", "Septuagint, Swete (First1KGreek)", "grc", "LXX", "f1k-swete", True, False, extra_sources=("swete-corrected",),
        notes="Daniel, Susanna and Bel in the Theodotion form. Marginal notes and running heads removed. Books from the LXX-Swete corrected set replace the raw First1KGreek text where available.")
    og = add_version(con, "swete-og", "Septuagint, Swete, Old Greek Daniel, Susanna and Bel", "grc", "LXX", "f1k-swete", True, False, extra_sources=("swete-corrected",))
    corrected = {}
    for f in sorted(SWETE_CORR.glob("*.txt")):
        n = int(f.name.split(".")[0]); d = {}
        for line in open(f, encoding="utf-8"):
            m = re.match(r"^(\d+)\.(\d+)\.(\d+)\s+(.*)$", line.strip())
            if m: d[(int(m.group(2)), int(m.group(3)))] = m.group(4).strip()
        corrected[n] = d
    rows = []; anomalies = []; used_corr = []; missing = []
    for n, bk in sorted(TLG.items()):
        d = F1K / f"tlg{n:03d}"
        files = sorted(d.glob("*1st1K-grc1.xml")) if d.exists() else []
        if n in corrected:
            data = corrected[n]; used_corr.append(bk + (" OG" if n in OG else ""))
        elif files:
            data, an = f1k_book(files[0]); anomalies += [f"{bk} tlg{n:03d}: {a}" for a in an]
        else:
            missing.append(f"{bk} (tlg{n:03d})"); continue
        vid = og if n in OG else main
        rows += [(vid, BOOK_ID[bk], c, v, t) for (c, v), t in data.items()]
    con.executemany("INSERT INTO verse(version_id,book_id,chapter,verse,text) VALUES (?,?,?,?,?)", rows)
    return dict(version="swete", verses=len(rows), corrected_books=used_corr, missing_books=missing, anomalies=anomalies)

def import_swete_gpl(con):
    """Personal build only: the GPL eliranwong Swete words."""
    vid = add_version(con, "swete-gpl", "Septuagint, Swete (eliranwong, GPL, personal build only)", "grc", "LXX", "eliranwong-swete", True, True)
    starts = []
    for line in open(ELIRAN_VERS, encoding="utf-8"):
        a, ref = line.rstrip("\n").split("\t"); starts.append((int(a), ref))
    MAP = {"Gen":"GEN","Exo":"EXO","Lev":"LEV","Num":"NUM","Deu":"DEU"}
    words = []; verses = {}; i = 0
    for line in open(ELIRAN_WORDS, encoding="utf-8"):
        a, _, w = line.rstrip("\n").partition("\t"); a = int(a)
        while i + 1 < len(starts) and starts[i + 1][0] <= a: i += 1
        bk, cv = starts[i][1].split(".", 1); c, v = cv.split(":")
        try: b = bid(bk)
        except KeyError: continue
        words.append((vid, b, int(c), int(v), a, w, w)); verses.setdefault((b, int(c), int(v)), []).append(w)
    con.executemany("INSERT INTO word(version_id,book_id,chapter,verse,position,text_src,text) VALUES (?,?,?,?,?,?,?)", words)
    con.executemany("INSERT OR IGNORE INTO verse(version_id,book_id,chapter,verse,text) VALUES (?,?,?,?,?)", [(vid, *k, " ".join(w)) for k, w in verses.items()])
    return dict(version="swete-gpl", words=len(words), verses=len(verses))

# ---------------- Lexicons ----------------
def import_tbes(con, path, source_id, prefix):
    rows = {}; dups = 0
    for line in open(path, encoding="utf-8"):
        p = line.rstrip("\r\n").split("\t")
        if len(p) < 8 or not re.match(rf"^{prefix}\d{{4}}", p[0]): continue
        key = p[1].split(" ")[0].strip() or p[0].strip()
        if not re.match(rf"^{prefix}\d{{4}}[A-Za-z]?$", key): key = p[0].strip()
        if key in rows: dups += 1; continue
        rows[key] = (source_id, key, p[0].strip()[:5], p[3], p[4], p[5], p[6], p[7])
    con.executemany("INSERT INTO lexicon(source_id,strong,base_strong,lemma,translit,morph,gloss,definition) VALUES (?,?,?,?,?,?,?,?)", rows.values())
    return dict(lexicon=source_id, entries=len(rows), duplicate_keys_skipped=dups)

def import_strongs_heb(con):
    t = etree.parse(str(STRONGS_HEB)); ns = "{http://www.bibletechnologies.net/2003/OSIS/namespace}"
    rows = []
    for e in t.iter(f"{ns}div"):
        if e.get("type") != "entry": continue
        w = e.find(f"{ns}w")
        if w is None or not w.get("ID"): continue
        sid = "H" + w.get("ID")[1:].zfill(4)
        items = [ "".join(i.itertext()).strip() for i in e.iter(f"{ns}item") ]
        notes = {n.get("type"): "".join(n.itertext()).strip() for n in e.iter(f"{ns}note")}
        definition = "\n".join(items + [v for k, v in notes.items() if k in ("exegesis", "explanation", "translation")])
        rows.append(("os-strongs-heb", sid, sid, w.get("lemma"), w.get("xlit"), w.get("morph"), notes.get("explanation"), definition))  # TWOT (w/@gloss) dropped
    con.executemany("INSERT INTO lexicon(source_id,strong,base_strong,lemma,translit,morph,gloss,definition) VALUES (?,?,?,?,?,?,?,?)", rows)
    return dict(lexicon="os-strongs-heb", entries=len(rows))

def import_strongs_grk(con):
    t = etree.parse(str(STRONGS_GRK)); rows = []
    for e in t.iter("entry"):
        sid = "G" + e.get("strongs").lstrip("0").zfill(4)
        g = e.find("greek")
        d = e.find("strongs_def"); k = e.find("kjv_def"); dv = e.find("strongs_derivation")
        txt = lambda x: re.sub(r"\s+", " ", "".join(x.itertext())).strip() if x is not None else ""
        rows.append(("os-strongs-grk", sid, sid, g.get("unicode") if g is not None else None, g.get("translit") if g is not None else None, None,
                     txt(k).lstrip(":-").strip() or None, "\n".join(x for x in (txt(dv), txt(d), txt(k)) if x)))
    con.executemany("INSERT INTO lexicon(source_id,strong,base_strong,lemma,translit,morph,gloss,definition) VALUES (?,?,?,?,?,?,?,?)", rows)
    return dict(lexicon="os-strongs-grk", entries=len(rows))

# ---------------- Cross references and versification ----------------
def osis_ref(r):
    bk, c, v = r.split(".")
    return bid(bk), int(c), int(v)
def import_xref(con):
    rows = []
    for line in open(XREF, encoding="utf-8"):
        p = line.rstrip("\r\n").split("\t")
        if len(p) != 3 or not re.match(r"^-?\d+$", p[2]): continue
        f = osis_ref(p[0]); to = p[1].split("-")
        a = osis_ref(to[0]); e = osis_ref(to[1]) if len(to) > 1 else (None, None, None)
        rows.append((*f, *a, *e, int(p[2]), "openbible-xref"))
    con.executemany("INSERT INTO crossref(from_book,from_chapter,from_verse,to_book,to_chapter,to_verse,to_end_book,to_end_chapter,to_end_verse,votes,source_id) VALUES (?,?,?,?,?,?,?,?,?,?,?)", rows)
    return dict(crossrefs=len(rows))

def import_tvtms(con):
    rows = []; on = False
    for line in open(TVTMS, encoding="utf-8-sig"):
        if line.startswith("#DataStart(Expanded)"): on = True; continue
        if line.startswith("#DataEnd(Expanded)"): break
        if not on: continue
        p = line.rstrip("\r\n").split("\t")
        if len(p) < 4 or not p[0] or p[0].startswith(("SourceType", "'=", "$", "#")) or not p[1]: continue
        rows.append((p[0].strip(), p[1].strip(), p[2].strip(), p[3].strip(), (p[5] if len(p) > 5 else "").strip(), "step-tvtms"))
    con.executemany("INSERT INTO versification_map(tradition,source_ref,standard_ref,action,note,source_id) VALUES (?,?,?,?,?,?)", rows)
    return dict(versification_rows=len(rows))
