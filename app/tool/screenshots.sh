#!/usr/bin/env bash
# Renders the Linux build under a virtual X display and saves screenshots to ../docs/screenshots.
# Linux is used only to check Hebrew and Greek rendering on the build box; the target is Windows.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(cd .. && pwd)/docs/screenshots"; mkdir -p "$OUT"
BIN=build/linux/x64/release/bundle/bible_study
UDB=$(mktemp -d)/user.sqlite
pgrep -f "Xvfb :91" >/dev/null || { Xvfb :91 -screen 0 1600x1000x24 >/dev/null 2>&1 & sleep 2; }
shot() { name=$1; shift; DISPLAY=:91 timeout 90 "$BIN" --user-db="$UDB" "$@" --screenshot="$OUT/$name.png" 2>&1 | grep screenshot; }
shot 01_genesis_1_hebrew_word   --goto=GEN.1.1 --word=1 --english=engbsb --original=tahot
shot 02_genesis_1_1_closeup     --goto=GEN.1.1 --word=2 --english=engbsb --original=tahot --pixel-ratio=2
shot 03_psalm_1_poetry_lxx      --goto=PSA.1.1 --word=1 --english=engbsb --original=tahot --lxx --pixel-ratio=2
shot 04_psalm_3_title_mapping   --goto=PSA.3.0 --english=eng-kjv2006 --original=tahot --lxx
shot 05_esther_8_9_accents      --goto=EST.8.9 --word=5 --english=engbsb --original=tahot --pixel-ratio=2
shot 06_daniel_2_aramaic        --goto=DAN.2.4 --word=6 --english=engbsb --original=tahot
shot 07_malachi_4_hebrew_3_19   --goto=MAL.4.1 --english=engmet --original=tahot
shot 08_john_1_greek_tagnt      --goto=JHN.1.1 --word=3 --english=engbsb --original=tagnt --pixel-ratio=2
shot 09_genesis_1_crossrefs     --goto=GEN.1.1 --panel=xref --english=engbsb --original=tahot
shot 10_notes_panel             --goto=GEN.1.1 --panel=notes --english=engbsb --original=tahot
shot 11_book_list               --goto=GEN.1.1 --dialog=books --english=engbsb
shot 12_credits                 --goto=GEN.1.1 --dialog=credits --english=engbsb
shot 13_psalm_119_hebrew        --goto=PSA.119.1 --word=1 --english=eng-kjv2006 --original=tahot
echo "user database used for the run: $UDB"
