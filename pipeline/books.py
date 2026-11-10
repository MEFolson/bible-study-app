"""Canonical book list. Codes are USFM 3 letter ids; aliases map every source's own codes."""
OT = [("GEN","Gen","Genesis"),("EXO","Exod","Exodus"),("LEV","Lev","Leviticus"),("NUM","Num","Numbers"),
("DEU","Deut","Deuteronomy"),("JOS","Josh","Joshua"),("JDG","Judg","Judges"),("RUT","Ruth","Ruth"),
("1SA","1Sam","1 Samuel"),("2SA","2Sam","2 Samuel"),("1KI","1Kgs","1 Kings"),("2KI","2Kgs","2 Kings"),
("1CH","1Chr","1 Chronicles"),("2CH","2Chr","2 Chronicles"),("EZR","Ezra","Ezra"),("NEH","Neh","Nehemiah"),
("EST","Esth","Esther"),("JOB","Job","Job"),("PSA","Ps","Psalms"),("PRO","Prov","Proverbs"),
("ECC","Eccl","Ecclesiastes"),("SNG","Song","Song of Songs"),("ISA","Isa","Isaiah"),("JER","Jer","Jeremiah"),
("LAM","Lam","Lamentations"),("EZK","Ezek","Ezekiel"),("DAN","Dan","Daniel"),("HOS","Hos","Hosea"),
("JOL","Joel","Joel"),("AMO","Amos","Amos"),("OBA","Obad","Obadiah"),("JON","Jonah","Jonah"),
("MIC","Mic","Micah"),("NAM","Nah","Nahum"),("HAB","Hab","Habakkuk"),("ZEP","Zeph","Zephaniah"),
("HAG","Hag","Haggai"),("ZEC","Zech","Zechariah"),("MAL","Mal","Malachi")]
NT = [("MAT","Matt","Matthew"),("MRK","Mark","Mark"),("LUK","Luke","Luke"),("JHN","John","John"),
("ACT","Acts","Acts"),("ROM","Rom","Romans"),("1CO","1Cor","1 Corinthians"),("2CO","2Cor","2 Corinthians"),
("GAL","Gal","Galatians"),("EPH","Eph","Ephesians"),("PHP","Phil","Philippians"),("COL","Col","Colossians"),
("1TH","1Thess","1 Thessalonians"),("2TH","2Thess","2 Thessalonians"),("1TI","1Tim","1 Timothy"),
("2TI","2Tim","2 Timothy"),("TIT","Titus","Titus"),("PHM","Phlm","Philemon"),("HEB","Heb","Hebrews"),
("JAS","Jas","James"),("1PE","1Pet","1 Peter"),("2PE","2Pet","2 Peter"),("1JN","1John","1 John"),
("2JN","2John","2 John"),("3JN","3John","3 John"),("JUD","Jude","Jude"),("REV","Rev","Revelation")]
DC = [("TOB","Tob","Tobit"),("JDT","Jdt","Judith"),("ESG","AddEsth","Esther (Greek)"),("WIS","Wis","Wisdom of Solomon"),
("SIR","Sir","Sirach"),("BAR","Bar","Baruch"),("LJE","EpJer","Letter of Jeremiah"),("S3Y","PrAzar","Song of the Three"),
("SUS","Sus","Susanna"),("BEL","Bel","Bel and the Dragon"),("1MA","1Macc","1 Maccabees"),("2MA","2Macc","2 Maccabees"),
("3MA","3Macc","3 Maccabees"),("4MA","4Macc","4 Maccabees"),("1ES","1Esd","1 Esdras"),("2ES","2Esd","2 Esdras (Latin)"),
("MAN","PrMan","Prayer of Manasseh"),("PS2","AddPs","Psalm 151"),("ODA","Odes","Odes"),("PSS","PssSol","Psalms of Solomon"),
("DAG","DanGr","Daniel (Greek)"),("LAO","EpLao","Letter to the Laodiceans")]

BOOKS = []
for testament, lst in (("OT", OT), ("NT", NT), ("DC", DC)):
    for code, osis, name in lst:
        BOOKS.append(dict(code=code, osis=osis, name=name, testament=testament, order=len(BOOKS) + 1))
BY_CODE = {b["code"]: b for b in BOOKS}
PROTO = [b["code"] for b in BOOKS if b["testament"] in ("OT", "NT")]
OT_CODES = [c for c, _, _ in OT]
NT_CODES = [c for c, _, _ in NT]

ALIASES = {}
for b in BOOKS:
    for k in (b["code"], b["osis"], b["code"].title()):
        ALIASES[k.lower()] = b["code"]
# STEP Bible (TAHOT, TAGNT) and other source codes
for k, v in {"exo": "EXO", "deu": "DEU", "jdg": "JDG", "rut": "RUT", "1ki": "1KI", "2ki": "2KI", "1ch": "1CH", "2ch": "2CH",
             "ezr": "EZR", "est": "EST", "psa": "PSA", "pro": "PRO", "ecc": "ECC", "sng": "SNG", "ezk": "EZK", "jol": "JOL",
             "amo": "AMO", "oba": "OBA", "jon": "JON", "nam": "NAM", "zep": "ZEP", "zec": "ZEC",
             "mat": "MAT", "mrk": "MRK", "luk": "LUK", "jhn": "JHN", "act": "ACT", "php": "PHP", "phm": "PHM", "jas": "JAS",
             "jud": "JUD", "tit": "TIT", "1jn": "1JN", "2jn": "2JN", "3jn": "3JN",
             # Byzantine csv file names
             "mar": "MRK", "joh": "JHN", "jam": "JAS", "1jo": "1JN", "2jo": "2JN", "3jo": "3JN",
             }.items():
    ALIASES[k] = v

def code(src_code):
    c = ALIASES.get(src_code.strip().lower())
    if not c:
        raise KeyError(f"unknown book code {src_code!r}")
    return c
