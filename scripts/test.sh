#!/usr/bin/env bash
# Run every tests/test_*.gd headless. Exits nonzero on any failure.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-godot}"
command -v "$GODOT" >/dev/null || { echo "godot: command not found (set GODOT_BIN)"; exit 1; }
# Import first so class_name globals resolve on a fresh checkout.
"$GODOT" --headless --path . --import >/dev/null 2>&1
# Fixed fps: each frame is one 1/60 s physics tick, run as fast as the CPU allows.
"$GODOT" --headless --fixed-fps 60 --path . -s res://tests/run.gd
