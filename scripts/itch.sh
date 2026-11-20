#!/usr/bin/env bash
# Export the Web preset and push it to itch.io with butler.
# Usage: scripts/itch.sh [--skip-tests]
# Env:   ITCH_TARGET (default: contents of web/ITCH_TARGET, e.g. yourname/jaisalmer)
#        ITCH_CHANNEL (default: html5)
#        GODOT_BIN (default: godot)
# One-time setup: create the game page on itch.io (Kind of project: HTML), then `butler login`.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-godot}"
TARGET="${ITCH_TARGET:-$(tr -d '[:space:]' < web/ITCH_TARGET 2>/dev/null || true)}"
[[ -n "$TARGET" ]] || { echo "no itch target: put user/game in web/ITCH_TARGET or set ITCH_TARGET"; exit 1; }
CHANNEL="${ITCH_CHANNEL:-html5}"
OUT="build/itch"

command -v "$GODOT" >/dev/null || { echo "godot: command not found (set GODOT_BIN)"; exit 1; }
command -v butler >/dev/null || { echo "butler: command not found (https://itch.io/docs/butler/)"; exit 1; }

# A stale main ships an old game; refuse unless main has everything origin/main has.
git fetch -q origin
BEHIND="$(git rev-list --count HEAD..origin/main)"
if [[ "$BEHIND" != "0" ]]; then
  echo "HEAD is $BEHIND commit(s) behind origin/main; merge it first."; exit 1
fi

if [[ "${1:-}" != "--skip-tests" ]]; then
  scripts/test.sh
fi

rm -rf "$OUT"
mkdir -p "$OUT"
# itch serves the HTML5 upload from index.html at the zip root. Threads are off,
# so the build needs no SharedArrayBuffer support on the itch page.
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"

VERSION="$(git describe --always --dirty 2>/dev/null || echo "uncommitted")"
echo "Built from $VERSION"
butler push "$OUT" "$TARGET:$CHANNEL" --userversion "$VERSION"
butler status "$TARGET:$CHANNEL"
