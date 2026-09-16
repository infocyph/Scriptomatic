from pathlib import Path
import re

path = Path('.github/scripts/scope-preservation-final.py')
text = path.read_text()

old = 'out, count = re.subn(pattern, repl, text, count=1, flags=re.S)'
new = 'out, count = re.subn(pattern, lambda _match: repl, text, count=1, flags=re.S)'
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('expected sub1 implementation not found')

needle = 'node_entry = node_entry.replace(\'"$ROOTCA_DEST"\', \'"/usr/local/share/ca-certificates/rootCA.crt"\')\n'
insert = needle + 'node_entry = node_entry.replace("$ROOTCA_DEST", "/usr/local/share/ca-certificates/rootCA.crt")\n'
if needle in text and insert not in text:
    text = text.replace(needle, insert, 1)

needle = 'php_entry = php_entry.replace(\'"$ROOTCA_DEST"\', \'"/usr/local/share/ca-certificates/rootCA.crt"\')\n'
insert = needle + 'php_entry = php_entry.replace("$ROOTCA_DEST", "/usr/local/share/ca-certificates/rootCA.crt")\n'
if needle in text and insert not in text:
    text = text.replace(needle, insert, 1)

text = text.replace('        "MONGO_MEMBERS", "MONGO_SHELL=",\n', '        "MONGO_MEMBERS",\n')

# Do not bulk-edit permanent tests. Source is corrected first; tests are then
# adjusted explicitly from concrete failures so test intent is preserved.
text = re.sub(
    r'\n# Remove tests for opt-out/policy knobs introduced during hardening\..*?\n# Guard against accidental reintroduction',
    '\n# Guard against accidental reintroduction',
    text,
    flags=re.S,
)

path.write_text(text)
