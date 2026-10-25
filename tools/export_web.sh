#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-$PWD/.tools/godot}"
mkdir -p build/web
touch build/.gdignore
mkdir -p test-results
touch test-results/.gdignore
"$godot_bin" --headless --editor --path . --import 2>&1 | tee /tmp/streetvicente-export-import.log
python3 tools/check_godot_log.py /tmp/streetvicente-export-import.log
"$godot_bin" --headless --path . --export-release Web "$PWD/build/web/index.html" 2>&1 | tee /tmp/streetvicente-export.log
python3 tools/check_godot_log.py /tmp/streetvicente-export.log
python3 tools/fingerprint_web.py
cp third_party/fists_of_fury/LICENSE build/web/LICENSE-Fists-of-Fury.txt
cp third_party/openbor/LICENSE build/web/LICENSE-OpenBOR.txt
touch build/web/.nojekyll
python3 tools/check_web_export.py build/web
