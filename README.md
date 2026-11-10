# Offline Bible study data pipeline (Milestone 1)

The Windows reader app that opens this database is in `app/`; see `app/README.md` for how to run it. Android and iPhone versions: see `MOBILE.md`.

This folder turns the raw downloads in `src/dl` into one SQLite file, `data/build/bible.sqlite`, and validates it. Building needs no network access. Only `fetch.py` goes online, and only to download sources that are missing.

## Rebuild

Requirements: Python 3.11 or newer, the `lxml` package, and SQLite with FTS5 (included in the standard Python build).

```
cd /workspace/bible-study/app
python3 pipeline/fetch.py          # only if src/dl is missing files; writes src/dl/MANIFEST.json with sha256 hashes and git commits
python3 pipeline/build.py          # default build: data/build/bible.sqlite plus validation_report.md and .json
```

Options for `build.py`:

* `--personal` writes `bible_personal.sqlite` and adds personal use extras: Basic English Bible (public domain in the US only) and the GPL Swete Septuagint. Never ship this file.
* `--no-fts` skips the full text search index.
* `--out NAME` writes to another file name in `data/build`, with its own report.
* `--write-baseline` rewrites `pipeline/expected/verse_counts.tsv` (or `verse_counts_personal.tsv`) and `pipeline/expected/reference_differences.md` from the build. Use it only after reviewing a deliberate change.

If any check fails, the build exits with code 1 and the database is renamed `*.failed.sqlite`, so a bad file is never left under the normal name.

## Files

* `pipeline/fetch.py` downloads sources and records hashes.
* `pipeline/sources.py` lists every source with its licence class, licence link, licence wording and credit line.
* `pipeline/books.py` holds book codes and name aliases.
* `pipeline/schema.sql` is the database schema.
* `pipeline/importers.py` holds one importer per source format (USFM, STEP TAHOT and TAGNT, SBLGNT, Byzantine, Nestle 1904, First1KGreek TEI, STEP lexicons, Open Scriptures Strong's, OpenBible cross references, TVTMS).
* `pipeline/build.py` runs the build. `pipeline/validate.py` runs the checks and writes the report.
* `pipeline/expected/verse_counts.tsv` is the frozen verse count baseline per version and book.
* `pipeline/expected/reference_differences.md` lists, per version, verses missing or extra compared with its reference version, for human review.
* `data/build/validation_report.md` and `.json` hold the latest results.

## What the database contains

Tables: `source` (credits and licences), `version`, `book`, `verse`, `word` (tagged words), `word_strong`, `lexicon`, `crossref`, `versification_map`, `version_source`, `meta`, and `verse_fts` (search index).

* 34 public domain or openly licensed English editions from eBible.org. A 35th download, Basic English, is public domain in the US only and goes into the personal build alone.
* TAHOT Hebrew: every word with pointed and accented text exactly as published in `text_src`, a display form in `text` (only the morpheme dividers `/` and `\` removed), lemma, Strong's ids and morphology. Verse text is built from those words. No Unicode normalisation is ever applied.
* Greek New Testament: TAGNT tagged words, SBLGNT text, Robinson Pierpont Byzantine 2018 (text and tagged words) and Nestle 1904 (text and tagged words).
* Septuagint: Brenton Greek (public domain) and Swete from First1KGreek (CC BY SA 4.0), with the corrected books from the sleeptillseven repository used where available. Old Greek forms of Daniel, Susanna and Bel are a separate version, `swete-og`.
* Lexicons: STEP TBESH and TBESG, and Open Scriptures Strong's Hebrew and Greek.
* OpenBible.info cross references and the STEP TVTMS versification table.

## Search

`verse_fts` is a contentless FTS5 index over a folded copy of each verse: accents, vowel points and capitals are removed for searching only. The stored and displayed text is never changed. The app must fold queries with the same `fold()` function in `build.py` and join results to `verse` by rowid.

## Checks (any failure stops the build)

1. KJV totals of verses, chapters and books.
2. TAHOT verse counts per chapter against the Westminster Leningrad Codex from Open Scriptures.
3. Verse counts per book for every version against the frozen baseline.
4. Every Hebrew word containing letters has vowel points.
5. Cantillation accents are present in every Hebrew book.
6. Every Hebrew word is byte identical to the TAHOT source.
7. Strong's ids on tagged words resolve in the matching lexicon.
8. Cross references resolve to existing verses.
9. Every source used has a credits row with its licence.
10. Licence gate: the default build allows only public domain, CC0, Unlicense, CC BY 4.0 and CC BY SA 4.0.
11. Search index integrity, with test queries in English, Greek and Hebrew.

Empty verse rows are reported as a warning only.

## Known limitations

* The verse count baseline was generated from this pipeline's own build and then reviewed through `reference_differences.md`. It catches regressions; it is not an independent outside count. Check 2 (against WLC) and check 1 (KJV totals) are independent.
* The First1KGreek Swete files leave many verse numbers inline in the running text, so several verses often sit in one row. The Swete column has 2250 Brenton reference verses absent and 1367 extra. Swete Ecclesiastes has no Greek file in First1KGreek, so that book is missing from the Swete column. Brenton Greek is the main Septuagint column for this reason.
* Brenton Greek lacks 1 Samuel 17:12 to 31 and some other verses compared with Brenton English (21 in total; see the differences file).
* Some extended Strong's ids in TAHOT and TAGNT are not in TBESH or TBESG and resolve only to their base number. The report lists them.
* Some editions have empty verse rows where the translation omits a verse but keeps its number.
* Non commercial sources (such as the Peshitta) are not implemented in any build.

## Licence

The app and pipeline code written for this project is licensed under the Apache License, Version 2.0: see `LICENSE` and `NOTICE`. Copyright 2026 Matthew Folson.

That licence covers the code only. The Bible texts, lexicons, cross references and other data, and the fonts, keep their own licences as listed in `SOURCES_AND_LICENCES.md` and `LICENSES/`. The cleaned Swete Septuagint text stays under CC BY SA 4.0.
