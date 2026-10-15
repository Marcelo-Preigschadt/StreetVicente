#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-$PWD/.tools/godot}"
mkdir -p build/web
"$godot_bin" --headless --editor --path . --import 2>&1 | tee /tmp/streetvicente-export-import.log
python3 tools/check_godot_log.py /tmp/streetvicente-export-import.log
"$godot_bin" --headless --path . --export-release Web "$PWD/build/web/index.html" 2>&1 | tee /tmp/streetvicente-export.log
python3 tools/check_godot_log.py /tmp/streetvicente-export.log
touch build/web/.nojekyll
python3 tools/check_web_export.py build/web
