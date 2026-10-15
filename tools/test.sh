#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-$PWD/.tools/godot}"
"$godot_bin" --headless --editor --path . --import 2>&1 | tee /tmp/streetvicente-import.log
python3 tools/check_godot_log.py /tmp/streetvicente-import.log
"$godot_bin" --headless --path . --script tests/run_tests.gd 2>&1 | tee /tmp/streetvicente-tests.log
python3 tools/check_godot_log.py /tmp/streetvicente-tests.log --tests
# Exercita também a cena completa, que os testes puros não instanciam.
"$godot_bin" --headless --path . --quit-after 20 2>&1 | tee /tmp/streetvicente-scene.log
python3 tools/check_godot_log.py /tmp/streetvicente-scene.log
