#!/usr/bin/env bash
# Export the Web preset and deploy to Cloudflare Pages.
# Usage: scripts/ship.sh [--skip-tests]
# Env:   GODOT_BIN (default: godot)  CF_PAGES_PROJECT (default: drone-sports)
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-godot}"
PROJECT="${CF_PAGES_PROJECT:-drone-sports}"
OUT="build/web"

if [[ "${1:-}" != "--skip-tests" ]]; then
  scripts/test.sh
fi

command -v "$GODOT" >/dev/null || { echo "godot: command not found (set GODOT_BIN)"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"
cp web/_headers "$OUT/_headers"

COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "uncommitted")"
echo "Built from $COMMIT"

npx --yes wrangler pages deploy "$OUT" --project-name "$PROJECT" --commit-dirty=true
