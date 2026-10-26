#!/usr/bin/env bash
# Run every tests/test_*.gd headless. Exits nonzero on any failure.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-godot}"
command -v "$GODOT" >/dev/null || { echo "godot: command not found (set GODOT_BIN)"; exit 1; }
"$GODOT" --headless --path . -s res://tests/run.gd
