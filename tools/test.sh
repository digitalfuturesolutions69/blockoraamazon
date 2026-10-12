#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
command -v rg >/dev/null || { echo "ripgrep is required for script discovery" >&2; exit 1; }
# Godot can emit script errors with exit 0; reject both failures and error logs.
validation_log=$(mktemp)
trap 'rm -f "$validation_log"' EXIT
run_godot() {
  if ! godot --headless --path . "$@" > "$validation_log" 2>&1; then cat "$validation_log"; return 1; fi
  cat "$validation_log"
  if rg -q 'SCRIPT ERROR|Parse Error|ERROR:' "$validation_log"; then return 1; fi
}
# The editor registers class_name types before checking all script resources.
run_godot --import
while IFS= read -r file; do
  run_godot --script "$file" --check-only
 done < <(rg --files scripts scenes tests addons -g '*.gd' | sort)
run_godot --script tests/smoke/run_tests.gd
run_godot --script tests/unit/run_gameplay_tests.gd
run_godot --script tests/unit/run_fair_play_tests.gd
run_godot --script tests/integration/run_input_tests.gd
run_godot --script tests/integration/run_input_lifecycle_tests.gd
run_godot --script tests/integration/run_audio_tests.gd
run_godot --script tests/integration/run_responsive_layout_tests.gd
run_godot --script tests/integration/run_drag_tests.gd
run_godot --script tests/integration/run_visual_tests.gd
run_godot --script tests/simulation/run_simulations.gd -- --sessions=100
run_godot --script tests/simulation/run_fairness.gd -- --sessions=100
run_godot --quit-after 2
