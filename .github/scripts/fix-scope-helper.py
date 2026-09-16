from pathlib import Path

path = Path('.github/scripts/scope-preservation-final.py')
text = path.read_text()
old = 'out, count = re.subn(pattern, repl, text, count=1, flags=re.S)'
new = 'out, count = re.subn(pattern, lambda _match: repl, text, count=1, flags=re.S)'
if old not in text:
    raise SystemExit('expected sub1 implementation not found')
path.write_text(text.replace(old, new, 1))
