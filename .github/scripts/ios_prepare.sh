#!/usr/bin/env bash
# Shared by both iOS workflows: fetch the published database, check it, pack it for the app.
set -euo pipefail
DB_SHA256=bc65b8a8c1639e87c3eedecb1feeded48607afcc77a4f023a3d1d4f6358494a5
mkdir -p data/build
curl -fsSL https://github.com/MEFolson/bible-study-app/releases/download/v1.0.0/bible.sqlite.gz | gunzip > data/build/bible.sqlite
echo "$DB_SHA256  data/build/bible.sqlite" | shasum -a 256 -c -
cd app
flutter pub get
python3 tool/pack_db.py
