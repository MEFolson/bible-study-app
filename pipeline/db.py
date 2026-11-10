import sqlite3
from pathlib import Path
from books import BOOKS, BY_CODE
from sources import SOURCES
BOOK_ID = {b["code"]: b["order"] for b in BOOKS}

def create(path):
    path = Path(path)
    if path.exists(): path.unlink()
    con = sqlite3.connect(path)
    con.executescript((Path(__file__).parent / "schema.sql").read_text())
    con.executemany("INSERT INTO book VALUES (?,?,?,?,?,?)",
        [(b["order"], b["code"], b["osis"], b["name"], b["testament"], b["order"]) for b in BOOKS])
    return con

def add_source(con, sid, checksum=None, retrieved=None):
    s = SOURCES[sid]
    con.execute("INSERT OR IGNORE INTO source VALUES (?,?,?,?,?,?,?,?,?)",
        (sid, s["name"], s["licence_class"], s["licence_url"], s.get("licence_quote"), s["credit"], s["url"], retrieved, checksum))

def add_version(con, code, name, language, scheme, source_id, has_text, has_words, direction="ltr", notes=None, extra_sources=()):
    cur = con.execute("INSERT INTO version(code,name,language,direction,scheme,has_text,has_words,source_id,notes) VALUES (?,?,?,?,?,?,?,?,?)",
        (code, name, language, direction, scheme, int(has_text), int(has_words), source_id, notes))
    vid = cur.lastrowid
    for s in (source_id, *extra_sources):
        con.execute("INSERT INTO version_source VALUES (?,?)", (vid, s))
    return vid
