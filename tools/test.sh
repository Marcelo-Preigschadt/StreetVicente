#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-$PWD/.tools/godot}"
timeout 180 "$godot_bin" --headless --editor --path . --import 2>&1 | tee /tmp/streetvicente-import.log
python3 tools/check_godot_log.py /tmp/streetvicente-import.log
timeout 180 "$godot_bin" --headless --path . --script tests/run_tests.gd 2>&1 | tee /tmp/streetvicente-tests.log
python3 tools/check_godot_log.py /tmp/streetvicente-tests.log --tests
# Exercita também a cena completa, que os testes puros não instanciam.
timeout 180 "$godot_bin" --headless --path . --quit-after 20 2>&1 | tee /tmp/streetvicente-scene.log
python3 tools/check_godot_log.py /tmp/streetvicente-scene.log

# Fluxos do shell: resultado do circuito/Continue e entrada/retomada do História.
timeout 180 "$godot_bin" --headless --path . --script tests/shell_v6.gd 2>&1 | tee /tmp/streetvicente-shell.log
python3 tools/check_godot_log.py /tmp/streetvicente-shell.log

# Adaptador de teclado original e controle USB configurável.
timeout 180 "$godot_bin" --headless --path . --script tests/input_settings_v9.gd 2>&1 | tee /tmp/streetvicente-input-v9.log
python3 tools/check_godot_log.py /tmp/streetvicente-input-v9.log
