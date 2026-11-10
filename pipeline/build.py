"""Build data/build/bible.sqlite from the raw downloads in src/dl, fully offline, then validate it.
Usage:
  python3 pipeline/build.py                 default build (App Store safe licences only)
  python3 pipeline/build.py --personal      also adds personal use extras (US only and GPL texts) into bible_personal.sqlite
  python3 pipeline/build.py --no-fts        skip the full text search index
  python3 pipeline/build.py --write-baseline   rewrite pipeline/expected/verse_counts.tsv from this build (review the diff first)
Exit code is 1 if any validation check fails; the database is then renamed *.failed.sqlite."""
import argparse, datetime, json, sys, time, unicodedata
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import db, importers, validate
from paths import *
from sources import SOURCES, EBIBLE_EN, US_ONLY

LANG_SCHEME = {"engjps": "Hebrew", "englee": "Hebrew", "engmet": "Hebrew", "engoke": "Hebrew", "eng-Brenton": "LXX", "englxxup": "LXX",
               "eng-lxx2012": "LXX", "eng-uk-lxx2012": "LXX", "engDRA": "Vulgate", "engWycliffe": "Vulgate"}

def fold(s):
    """Search key only. Same function must be used on queries in the app."""
    s = "".join(ch for ch in unicodedata.normalize("NFD", s) if unicodedata.category(ch) != "Mn")
    return s.lower().replace("\u03c2", "\u03c3")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--personal", action="store_true"); ap.add_argument("--no-fts", action="store_true"); ap.add_argument("--out", help="output file name inside data/build (reports then use the same stem)")
    ap.add_argument("--write-baseline", action="store_true")
    a = ap.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    out = BUILD / (a.out or ("bible_personal.sqlite" if a.personal else "bible.sqlite"))
    for old in (out, out.with_suffix(".failed.sqlite")):
        if old.exists(): old.unlink()
    t0 = time.time(); con = db.create(out); log = []
    man = json.loads((DL / "MANIFEST.json").read_text())
    def src(sid, key=None):
        chk = None
        if key and key in man["files"]: chk = "sha256:" + man["files"][key]["sha256"]
        if key and key in man["repos"]: chk = "git:" + man["repos"][key]["commit"]
        db.add_source(con, sid, chk, datetime.date.today().isoformat())
    # sources
    for sid, key in [("step-tahot", "TAHOT_Gen-Deu.txt"), ("step-tagnt", "TAGNT_Mat-Jhn.txt"), ("step-tbesh", "tbesh.txt"), ("step-tbesg", "tbesg.txt"),
                     ("step-tvtms", "tvtms/TVTMS.txt"), ("oshb-wlc", "morphhb_repo"), ("os-strongs-heb", "strongs/StrongHebrewG.xml"), ("os-strongs-grk", "sg.zip"),
                     ("openbible-xref", "cross-references.zip"), ("sblgnt", "sblgnt_repo"), ("byz-rp2018", "byz_repo"), ("nestle1904", "n1904_repo"),
                     ("f1k-swete", "f1k_repo"), ("swete-corrected", "swete_corr_repo"), ("ebible-grcbrent", "grc/grcbrent_usfm.zip")]:
        src(sid, key)
    # English
    for vid, name in EBIBLE_EN:
        if vid in US_ONLY and not a.personal: continue
        src("ebible-" + vid, f"ebible/{vid}_usfm.zip")
        log.append(importers.import_usfm(con, EBIBLE / f"{vid}_usfm.zip", vid, name, "eng", LANG_SCHEME.get(vid, "KJV"), "ebible-" + vid))
    # Original languages
    log.append(importers.import_tahot(con))
    log.append(importers.import_tagnt(con))
    log.append(importers.import_sblgnt(con))
    log.append(importers.import_byz(con))
    log.append(importers.import_n1904(con))
    log.append(importers.import_usfm(con, GRCBRENT, "grcbrent", "Septuagint, Brenton Greek (1851)", "grc", "LXX", "ebible-grcbrent"))
    log.append(importers.import_swete(con))
    if a.personal:
        src("eliranwong-swete", "swete_words.csv"); log.append(importers.import_swete_gpl(con))
    # Lexicons, cross references, versification
    log.append(importers.import_tbes(con, TBESH, "step-tbesh", "H"))
    log.append(importers.import_tbes(con, TBESG, "step-tbesg", "G"))
    log.append(importers.import_strongs_heb(con))
    log.append(importers.import_strongs_grk(con))
    log.append(importers.import_xref(con))
    log.append(importers.import_tvtms(con))
    # word_strong link table
    rows = [(wid, s) for wid, ids in con.execute("SELECT id, strong_ids FROM word WHERE strong_ids IS NOT NULL AND strong_ids != ''") for s in ids.split()]
    con.executemany("INSERT INTO word_strong VALUES (?,?)", rows)
    if not a.no_fts:
        # Search index only: a folded copy (accents, vowel points and case removed) is indexed; displayed text is never changed.
        con.execute("CREATE VIRTUAL TABLE verse_fts USING fts5(text, content='', contentless_delete=1, tokenize='unicode61 remove_diacritics 2')")
        con.executemany("INSERT INTO verse_fts(rowid, text) VALUES (?,?)", ((i, fold(t)) for i, t in con.execute("SELECT id, text FROM verse").fetchall()))
    meta = {"built": datetime.datetime.now().isoformat(timespec="seconds"), "build": "personal" if a.personal else "default",
            "fts": str(not a.no_fts), "schema_version": "1"}
    con.executemany("INSERT INTO meta VALUES (?,?)", meta.items())
    con.commit()
    con.execute("ANALYZE"); con.commit(); con.execute("VACUUM"); con.close()
    print(f"built {out.name} in {time.time()-t0:.0f}s, {out.stat().st_size/1e6:.1f} MB")
    ok = validate.run(out, personal=a.personal, build_log=log, write_baseline=a.write_baseline, report_stem=(out.stem + "_validation_report") if a.out else None)
    if not ok:
        out.rename(out.with_suffix(".failed.sqlite")); print("VALIDATION FAILED"); sys.exit(1)
    print("VALIDATION PASSED")

if __name__ == "__main__":
    main()
