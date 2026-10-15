"""Godot pode retornar exit 0 mesmo com erro GDScript; logs são parte do gate."""
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(errors='replace')
if re.search(r'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|FAIL:', text):
    raise SystemExit('Godot apresentou erro de script/compilação; veja o log acima.')
if '--tests' in sys.argv and not re.search(r'COMBAT TESTS: \d+ checks, 0 failures', text):
    raise SystemExit('O runner não concluiu os testes de combate.')
