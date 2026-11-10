#!/usr/bin/env bash
# Real input test on the Linux build: clicks a Hebrew word, then a cross reference, and captures the
# whole X screen with ImageMagick (not the app's own capture). Coordinates assume the 1600x1000 window.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(cd .. && pwd)/docs/screenshots"
BIN=build/linux/x64/release/bundle/bible_study
pgrep -f "Xvfb :91" >/dev/null || { Xvfb :91 -screen 0 1600x1000x24 >/dev/null 2>&1 & sleep 2; }
run() { DISPLAY=:91 "$BIN" --user-db="$(mktemp -d)/user.sqlite" --goto=GEN.1.1 --english=engbsb --original=tahot >/dev/null 2>&1 & sleep 6; }
run; DISPLAY=:91 xdotool mousemove 398 176 click 1; sleep 1.5
DISPLAY=:91 import -window root "$OUT/14_real_window_click_xvfb.png"; pkill -f "$BIN" || true; sleep 1
run; DISPLAY=:91 xdotool mousemove 684 205 click 1; sleep 1.5; DISPLAY=:91 xdotool mousemove 1250 222 click 1; sleep 2
DISPLAY=:91 import -window root "$OUT/15_crossref_jump_to_john_1_xvfb.png"; pkill -f "$BIN" || true
echo "written 14 and 15 in $OUT"
