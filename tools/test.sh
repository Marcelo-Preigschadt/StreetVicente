#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-$PWD/.tools/godot}"
"$godot_bin" --headless --editor --path . --import 2>&1 | tee /tmp/streetvicente-import.log
if rg -q 'SCRIPT ERROR|Parse Error|Failed to load script' /tmp/streetvicente-import.log; then
  exit 1
fi
"$godot_bin" --headless --path . --script tests/run_tests.gd 2>&1 | tee /tmp/streetvicente-tests.log
if rg -q 'SCRIPT ERROR|Parse Error|FAIL:' /tmp/streetvicente-tests.log; then
  exit 1
fi
