#!/usr/bin/env python3
"""Packs ../data/build/bible.sqlite into gzip parts under assets/db for the Android and iOS builds.

A 445 MB file cannot be opened from inside a compressed app package, so the mobile apps copy these
parts to their own storage on first launch (lib/data/bundled_db.dart) and open that copy read only.
The source database is only read here, never changed. Run again after every pipeline rebuild."""
import gzip, hashlib, json, os, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent.parent
SRC = HERE.parent / "data" / "build" / "bible.sqlite"
OUT = HERE / "assets" / "db"
PART = 16 * 1024 * 1024

def main():
    if not SRC.exists():
        sys.exit(f"missing {SRC}; run pipeline/build.py first")
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("bible.sqlite.part*.gz"):
        old.unlink()
    h = hashlib.sha256(); parts = []
    with open(SRC, "rb") as f:
        i = 0
        while True:
            raw = f.read(PART)
            if not raw:
                break
            h.update(raw)
            name = f"bible.sqlite.part{i:03d}.gz"
            gz = gzip.compress(raw, compresslevel=9, mtime=0)
            (OUT / name).write_bytes(gz)
            parts.append({"name": name, "raw_bytes": len(raw), "gz_bytes": len(gz),
                          "raw_sha256": hashlib.sha256(raw).hexdigest()})
            i += 1
    manifest = {"file": "bible.sqlite", "bytes": SRC.stat().st_size, "sha256": h.hexdigest(), "parts": parts}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))
    gzt = sum(p["gz_bytes"] for p in parts)
    print(f"{len(parts)} parts, {manifest['bytes']} bytes raw, {gzt} bytes compressed, sha256 {manifest['sha256']}")

if __name__ == "__main__":
    main()
