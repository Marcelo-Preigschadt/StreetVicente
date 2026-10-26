"""Name the exported PCK by its actual bytes so returning players get new art."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

root = Path('build/web')
pack = root / 'index.pck'
digest = hashlib.file_digest(pack.open('rb'), 'sha256').hexdigest()
name = 'index-' + digest[:12] + '.pck'
for old in root.glob('index-*.pck'):
    old.unlink()
pack.rename(root / name)
html = (root / 'index.html').read_text()
match = re.search(r'const GODOT_CONFIG\s*=\s*(\{.*?\});', html)
assert match, 'Exported configuration missing'
config = json.loads(match.group(1))
config['mainPack'] = name
config['fileSizes'][name] = config['fileSizes'].pop('index.pck')
html = html[:match.start(1)] + json.dumps(config, separators=(',', ':')) + html[match.end(1):]
(root / 'index.html').write_text(html)
manifest = {'presentation_revision': 28, 'pack': name, 'pack_sha256': digest,
            'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()}
(root / 'build.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
print('WEB CONTENT FINGERPRINT:', name)
