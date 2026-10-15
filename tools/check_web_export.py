"""Valida o pacote servido, inclusive subdiretório /StreetVicente/."""
from pathlib import Path
import json
import re
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/web')
for name in ('index.html', 'index.js', 'index.wasm', 'index.pck', '.nojekyll'):
    if not (root / name).is_file():
        raise SystemExit(f'Arquivo ausente: {name}')
html = (root / 'index.html').read_text()
config = re.search(r'const GODOT_CONFIG\s*=\s*(\{.*?\});', html)
if not config:
    raise SystemExit('GODOT_CONFIG não encontrado no HTML exportado')
data = json.loads(config.group(1))
if data.get('ensureCrossOriginIsolationHeaders'):
    raise SystemExit('Export exige isolamento de origem; desative threads/PWA')
if data.get('gdextensionLibs'):
    raise SystemExit('GDExtension não pertence a esta base Web')
if re.search(r'(?:src|href)=[\"\']/[^/]', html):
    raise SystemExit('Caminho absoluto quebra o subdiretório do GitHub Pages')
if (root / 'index.wasm').read_bytes()[:4] != b'\x00asm':
    raise SystemExit('WASM inválido')
print('WEB PACKAGE OK: index.html + JS + WASM + PCK; caminhos relativos')
