#!/usr/bin/env bash
# Run tests/test_*.gd headless, split across several Godot processes (each with
# its own save), then list any failures and the slowest tests. Exits nonzero on
# any failure, or if a process dies before finishing its files.
# Env: ONLY=test_foo,test_song_*  just those files, in one process (`*` is a wildcard)
#      JOBS=n                     processes for a full run (default: 12, at most the CPU count)
#      GODOT_BIN                  the Godot binary (default: godot)
#      DRONE_TEST_SAVE            base name for the test saves (default: unique to this run)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-godot}"
command -v "$GODOT" >/dev/null || { echo "godot: command not found (set GODOT_BIN)"; exit 1; }
# Import first so class_name globals resolve on a fresh checkout.
"$GODOT" --headless --path . --import >/dev/null 2>&1

logs="$(mktemp -d)"
pids=()
stop() {
  [[ ${#pids[@]} -gt 0 ]] && kill "${pids[@]}" 2>/dev/null || true
  rm -rf "$logs"
}
trap stop EXIT
save="${DRONE_TEST_SAVE:-user://test_run_$$.json}"

# Fixed fps: each frame is one 1/60 s physics tick, run as fast as the CPU allows.
run_tests() { # <process number> <files>
  DRONE_TEST_SAVE="$save.$1" ONLY="$2" "$GODOT" --headless --fixed-fps 60 --path . -s res://tests/run.gd
}

started=$SECONDS
if [[ -n "${ONLY:-}" ]]; then
  jobs=1
  # One process: its output can stream as it goes.
  run_tests 0 "$ONLY" 2>&1 | tee "$logs/0.log" || true
else
  cpus="$(nproc 2>/dev/null || echo 8)"
  jobs="${JOBS:-$(( cpus < 12 ? cpus : 12 ))}"
  (( jobs >= 1 )) || { echo "JOBS must be at least 1"; exit 1; }
  # Too slow to share: on a full run each gets a process of its own, so it does
  # not hold up the files dealt alongside it.
  alone=(test_parts_freestyle test_parts_heavy_hauler test_parts_light_racer
         test_flight_style test_song_profile test_fleet_path)
  # Dealt out by a fixed order, so a run can be repeated exactly.
  groups=()
  n=0
  first=0
  for name in "${alone[@]}"; do
    # At most half the processes: the rest carry all the other files.
    if (( first < jobs / 2 )); then
      groups[first]="$name"
      first=$(( first + 1 ))
    fi
  done
  for f in tests/test_*.gd; do
    name="$(basename "$f" .gd)"
    if (( first > 0 )) && [[ " ${groups[*]:0:first} " == *" $name "* ]]; then
      continue
    fi
    i=$(( first + n % (jobs - first) ))
    n=$(( n + 1 ))
    groups[i]="${groups[i]:-}${groups[i]:+,}$name"
  done
  jobs=${#groups[@]}
  echo "Running $(( n + first )) test files in $jobs processes..."
  for (( i = 0; i < jobs; i++ )); do
    run_tests "$i" "${groups[i]}" > "$logs/$i.log" 2>&1 &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || true
  done
  pids=()
  for (( i = 0; i < jobs; i++ )); do
    echo "=== process $i ==="
    cat "$logs/$i.log"
  done
fi

# Totals. run.gd prints "N passed, M failed" last, so a process that lacks the
# line did not finish.
passed=0
failed=0
died=0
for (( i = 0; i < jobs; i++ )); do
  line="$(grep -E '^[0-9]+ passed, [0-9]+ failed$' "$logs/$i.log" || true)"
  if [[ -z "$line" ]]; then
    died=$(( died + 1 ))
    echo "PROCESS $i DID NOT FINISH. The last lines it logged:"
    tail -n 15 "$logs/$i.log"
    continue
  fi
  read -r p _ f _ <<< "$line"
  passed=$(( passed + p ))
  failed=$(( failed + f ))
done

ranked() { # <line prefix>: the prefixed lines' names, slowest first
  sed -nE "s/^($1) +(.*) \[([0-9]+) ms\]\$/\3 \2/p" "$logs"/*.log | sort -rn
}
echo
echo "Slowest tests:"
ranked 'ok|FAIL' | sed -n 1,20p | awk '{ printf "%8.1f s  %s\n", $1 / 1000, $2 }'
echo "Slowest files:"
ranked 'file' | sed -n 1,10p | awk '{ printf "%8.1f s  %s\n", $1 / 1000, $2 }'

if (( failed > 0 )); then
  echo
  echo "Failures:"
  # Each FAIL line and the indented error lines under it.
  awk '/^FAIL/ { on = 1; print; next } on && /^ / { print; next } { on = 0 }' "$logs"/*.log
fi
echo
echo "$passed passed, $failed failed in $(( SECONDS - started )) s ($jobs processes)"
(( failed == 0 && died == 0 ))
