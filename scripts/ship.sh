#!/usr/bin/env bash
# Export the Web preset and deploy to GitHub Pages (the gh-pages branch of origin).
# Usage: scripts/ship.sh [--skip-tests]
# Env:   GODOT_BIN (default: godot)  PAGES_BRANCH (default: gh-pages)
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-godot}"
BRANCH="${PAGES_BRANCH:-gh-pages}"
OUT="build/web"

if [[ "${1:-}" != "--skip-tests" ]]; then
  scripts/test.sh
fi

command -v "$GODOT" >/dev/null || { echo "godot: command not found (set GODOT_BIN)"; exit 1; }
REMOTE="$(git remote get-url origin)" || { echo "no origin remote"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"
# GitHub Pages ignores _headers; threads are off, so the build needs no COOP/COEP.
touch "$OUT/.nojekyll"

COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "uncommitted")"
echo "Built from $COMMIT"

# Publish the build as a single fresh commit; the branch keeps no history.
git -C "$OUT" init -q -b "$BRANCH"
git -C "$OUT" add -A
git -C "$OUT" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" \
  commit -q -m "Deploy $COMMIT"
git -C "$OUT" push -q --force "$REMOTE" "$BRANCH"

SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
# GitHub may enable Pages on its own when gh-pages first appears (409 here), so ignore that.
if ! gh api "repos/$SLUG/pages" >/dev/null 2>&1; then
  gh api -X POST "repos/$SLUG/pages" -f "source[branch]=$BRANCH" -f "source[path]=/" >/dev/null 2>&1 || true
fi
echo "Deployed: $(gh api "repos/$SLUG/pages" -q .html_url)"
