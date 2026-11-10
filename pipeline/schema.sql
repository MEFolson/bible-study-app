PRAGMA foreign_keys = ON;
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE source (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, licence_class TEXT NOT NULL, licence_url TEXT NOT NULL,
  licence_quote TEXT, credit TEXT NOT NULL, url TEXT NOT NULL, retrieved TEXT, checksum TEXT);
CREATE TABLE book (
  id INTEGER PRIMARY KEY, code TEXT UNIQUE NOT NULL, osis TEXT NOT NULL, name TEXT NOT NULL,
  testament TEXT NOT NULL, canon_order INTEGER NOT NULL);
CREATE TABLE version (
  id INTEGER PRIMARY KEY, code TEXT UNIQUE NOT NULL, name TEXT NOT NULL, language TEXT NOT NULL,
  direction TEXT NOT NULL DEFAULT 'ltr', scheme TEXT NOT NULL, has_text INTEGER NOT NULL, has_words INTEGER NOT NULL,
  source_id TEXT NOT NULL REFERENCES source(id), notes TEXT);
CREATE TABLE verse (
  id INTEGER PRIMARY KEY, version_id INTEGER NOT NULL REFERENCES version(id), book_id INTEGER NOT NULL REFERENCES book(id),
  chapter INTEGER NOT NULL, verse INTEGER NOT NULL, verse_end INTEGER, alt_ref TEXT, text TEXT NOT NULL);
CREATE UNIQUE INDEX verse_ref ON verse(version_id, book_id, chapter, verse);
CREATE TABLE word (
  id INTEGER PRIMARY KEY, version_id INTEGER NOT NULL REFERENCES version(id), book_id INTEGER NOT NULL REFERENCES book(id),
  chapter INTEGER NOT NULL, verse INTEGER NOT NULL, position INTEGER NOT NULL, src_ref TEXT, alt_ref TEXT, word_type TEXT,
  text_src TEXT NOT NULL,      -- exactly as published, byte for byte
  text TEXT NOT NULL,          -- display form: only morpheme separators removed, never normalised
  translit TEXT, gloss TEXT, strong TEXT, strong_ids TEXT, lemma TEXT, morph TEXT, editions TEXT);
CREATE INDEX word_ref ON word(version_id, book_id, chapter, verse, position);
CREATE TABLE word_strong (word_id INTEGER NOT NULL REFERENCES word(id), strong TEXT NOT NULL);
CREATE INDEX word_strong_s ON word_strong(strong);
CREATE TABLE lexicon (
  id INTEGER PRIMARY KEY, source_id TEXT NOT NULL REFERENCES source(id), strong TEXT NOT NULL, base_strong TEXT NOT NULL,
  lemma TEXT, translit TEXT, morph TEXT, gloss TEXT, definition TEXT);
CREATE UNIQUE INDEX lexicon_key ON lexicon(source_id, strong);
CREATE INDEX lexicon_base ON lexicon(base_strong);
CREATE TABLE crossref (
  id INTEGER PRIMARY KEY, from_book INTEGER NOT NULL, from_chapter INTEGER NOT NULL, from_verse INTEGER NOT NULL,
  to_book INTEGER NOT NULL, to_chapter INTEGER NOT NULL, to_verse INTEGER NOT NULL,
  to_end_book INTEGER, to_end_chapter INTEGER, to_end_verse INTEGER, votes INTEGER NOT NULL, source_id TEXT NOT NULL REFERENCES source(id));
CREATE INDEX crossref_from ON crossref(from_book, from_chapter, from_verse);
CREATE TABLE versification_map (
  id INTEGER PRIMARY KEY, tradition TEXT NOT NULL, source_ref TEXT NOT NULL, standard_ref TEXT NOT NULL,
  action TEXT, note TEXT, source_id TEXT NOT NULL REFERENCES source(id));
CREATE TABLE version_source (version_id INTEGER NOT NULL REFERENCES version(id), source_id TEXT NOT NULL REFERENCES source(id));
