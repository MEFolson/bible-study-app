"""Download every raw source into src/dl if missing, then write src/dl/MANIFEST.json with sha256 and git commits.
Run: python3 pipeline/fetch.py   (network needed only here; the build itself is offline)"""
import hashlib, json, subprocess, sys, urllib.request, zipfile
from paths import *
from sources import EBIBLE_EN
RAW = "https://raw.githubusercontent.com"
STEPD = RAW + "/STEPBible/STEPBible-Data/master/"
FILES = {
 "TAHOT_Gen-Deu.txt": STEPD + "Translators%20Amalgamated%20OT%2BNT/TAHOT%20Gen-Deu%20-%20Translators%20Amalgamated%20Hebrew%20OT%20-%20STEPBible.org%20CC%20BY.txt",
 "TAHOT_Jos-Est.txt": STEPD + "Translators%20Amalgamated%20OT%2BNT/TAHOT%20Jos-Est%20-%20Translators%20Amalgamated%20Hebrew%20OT%20-%20STEPBible.org%20CC%20BY.txt",
 "TAHOT_Job-Sng.txt": STEPD + "Translators%20Amalgamated%20OT%2BNT/TAHOT%20Job-Sng%20-%20Translators%20Amalgamated%20Hebrew%20OT%20-%20STEPBible.org%20CC%20BY.txt",
 "TAHOT_Isa-Mal.txt": STEPD + "Translators%20Amalgamated%20OT%2BNT/TAHOT%20Isa-Mal%20-%20Translators%20Amalgamated%20Hebrew%20OT%20-%20STEPBible.org%20CC%20BY.txt",
 "TAGNT_Mat-Jhn.txt": STEPD + "Translators%20Amalgamated%20OT%2BNT/TAGNT%20Mat-Jhn%20-%20Translators%20Amalgamated%20Greek%20NT%20-%20STEPBible.org%20CC-BY.txt",
 "TAGNT_Act-Rev.txt": STEPD + "Translators%20Amalgamated%20OT%2BNT/TAGNT%20Act-Rev%20-%20Translators%20Amalgamated%20Greek%20NT%20-%20STEPBible.org%20CC-BY.txt",
 "tbesh.txt": STEPD + "Lexicons/TBESH%20-%20Translators%20Brief%20lexicon%20of%20Extended%20Strongs%20for%20Hebrew%20-%20STEPBible.org%20CC%20BY.txt",
 "tbesg.txt": STEPD + "Lexicons/TBESG%20-%20Translators%20Brief%20lexicon%20of%20Extended%20Strongs%20for%20Greek%20-%20STEPBible.org%20CC%20BY.txt",
 "tvtms/TVTMS.txt": STEPD + "Versification/TVTMS%20-%20Translators%20Versification%20Traditions%20with%20Methodology%20for%20Standardisation%20for%20Eng%2BHeb%2BLat%2BGrk%2BOthers%20-%20STEPBible.org%20CC%20BY.txt",
 "strongs/StrongHebrewG.xml": RAW + "/openscriptures/strongs/master/hebrew/StrongHebrewG.xml",
 "sg.zip": RAW + "/openscriptures/strongs/master/greek/StrongsGreekDictionaryXML_1.4.zip",
 "cross-references.zip": "https://a.openbible.info/data/cross-references.zip",
 "grc/grcbrent_usfm.zip": "https://ebible.org/Scriptures/grcbrent_usfm.zip",
 "swete_words.csv": RAW + "/eliranwong/LXX-Swete-1930/master/01-Swete_word_with_punctuations.csv",
 "swete_vers.csv": RAW + "/eliranwong/LXX-Swete-1930/master/00-Swete_versification.csv",
}
for vid, _ in EBIBLE_EN:
    FILES[f"ebible/{vid}_usfm.zip"] = f"https://ebible.org/Scriptures/{vid}_usfm.zip"
REPOS = {  # dir: (url, sparse path or None)
 "sblgnt_repo": ("https://github.com/Faithlife/SBLGNT", None),
 "byz_repo": ("https://github.com/byztxt/byzantine-majority-text", None),
 "n1904_repo": ("https://github.com/biblicalhumanities/Nestle1904", None),
 "f1k_repo": ("https://github.com/OpenGreekAndLatin/First1KGreek", "data/tlg0527"),
 "morphhb_repo": ("https://github.com/openscriptures/morphhb", "wlc"),
 "swete_corr_repo": ("https://github.com/sleeptillseven/LXX-Swete", None),
}
def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""): h.update(b)
    return h.hexdigest()
def main():
    for rel, url in FILES.items():
        p = DL / rel
        if not p.exists():
            p.parent.mkdir(parents=True, exist_ok=True); print("download", rel)
            urllib.request.urlretrieve(url, p)
    if not STRONGS_GRK.exists():
        with zipfile.ZipFile(DL / "sg.zip") as z: STRONGS_GRK.write_bytes(z.read("strongsgreek.xml"))
    if not XREF.exists():
        with zipfile.ZipFile(DL / "cross-references.zip") as z: XREF.write_bytes(z.read("cross_references.txt"))
    for d, (url, sparse) in REPOS.items():
        p = DL / d
        if not p.exists():
            print("clone", url)
            if sparse:
                subprocess.run(["git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse", url, str(p)], check=True)
                subprocess.run(["git", "-C", str(p), "sparse-checkout", "set", sparse], check=True)
            else:
                subprocess.run(["git", "clone", "-q", "--depth", "1", url, str(p)], check=True)
    man = {"files": {}, "repos": {}}
    for rel, url in FILES.items():
        man["files"][rel] = {"url": url, "sha256": sha(DL / rel)}
    for d, (url, _) in REPOS.items():
        man["repos"][d] = {"url": url, "commit": subprocess.run(["git", "-C", str(DL / d), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()}
    (DL / "MANIFEST.json").write_text(json.dumps(man, indent=1))
    print("manifest written:", len(man["files"]), "files,", len(man["repos"]), "repos")
if __name__ == "__main__":
    main()
