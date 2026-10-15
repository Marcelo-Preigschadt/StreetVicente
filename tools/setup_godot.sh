#!/usr/bin/env bash
# Linux x86_64 (Codespaces/Actions). Instala editor e somente templates Web.
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(cat tools/godot_version.txt)"
tool_dir="$PWD/.tools"
template_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${version}.stable"
mkdir -p "$tool_dir" "$template_dir"
if [[ -x "$tool_dir/godot" && -f "$template_dir/web_nothreads_release.zip" ]]; then
  "$tool_dir/godot" --version
  exit 0
fi
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
base="https://github.com/godotengine/godot-builds/releases/download/${version}-stable"
editor="Godot_v${version}-stable_linux.x86_64.zip"
templates="Godot_v${version}-stable_export_templates.tpz"
curl --fail --location --retry 3 "$base/SHA512-SUMS.txt" -o "$temp_dir/SHA512-SUMS.txt"
curl --fail --location --retry 3 "$base/$editor" -o "$temp_dir/$editor"
curl --fail --location --retry 3 "$base/$templates" -o "$temp_dir/$templates"
python3 - "$temp_dir" "$editor" "$templates" "$tool_dir" "$template_dir" <<'PY'
import hashlib, pathlib, sys, zipfile
temp, editor, templates, tools, target = sys.argv[1:]
temp = pathlib.Path(temp)
manifest = {}
for line in (temp / 'SHA512-SUMS.txt').read_text().splitlines():
    parts = line.split()
    if len(parts) >= 2:
        manifest[parts[-1].lstrip('*')] = parts[0]
for name in (editor, templates):
    digest = hashlib.file_digest((temp / name).open('rb'), 'sha512').hexdigest()
    if manifest.get(name) != digest:
        raise SystemExit('SHA512 inválido: ' + name)
with zipfile.ZipFile(temp / editor) as archive:
    binary = next(n for n in archive.namelist() if n.endswith('linux.x86_64'))
    dest = pathlib.Path(tools) / 'godot'
    dest.write_bytes(archive.read(binary))
    dest.chmod(0o755)
with zipfile.ZipFile(temp / templates) as archive:
    for name in ('web_nothreads_debug.zip', 'web_nothreads_release.zip', 'version.txt'):
        (pathlib.Path(target) / name).write_bytes(archive.read('templates/' + name))
PY
"$tool_dir/godot" --version
