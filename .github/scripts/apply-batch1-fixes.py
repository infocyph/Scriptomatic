#!/usr/bin/env python3
from pathlib import Path

# 1) Strict-mode local declaration ordering in php-cli-setup.
p = Path('bash/php-cli-setup.sh')
s = p.read_text()
old = '  local asset="$1" dest="$2" sums="$WORKDIR/toolset-SHA256SUMS" file="$WORKDIR/toolset-$asset" expected\n'
new = '  local asset="$1" dest="$2"\n  local sums="$WORKDIR/toolset-SHA256SUMS"\n  local file="$WORKDIR/toolset-$asset" expected\n'
if old not in s:
    raise SystemExit('php-cli local declaration anchor missing')
p.write_text(s.replace(old, new, 1))

# 2) Security audit should reject user-owned shared binaries, not root:root enforcement.
p = Path('tests/security-audit.sh')
s = p.read_text()
old = "assert_absent 'chown[^\\n]*/usr/local/bin' \"PHP setup must not chown shared executables to ordinary users\" \"${php_files[@]}\"\n"
new = "assert_absent 'chown[^\\n]*(\\$USERNAME|\\$\\{USERNAME\\})[^\\n]*/usr/local/bin' \"PHP setup must not chown shared executables to ordinary users\" \"${php_files[@]}\"\n"
if old not in s:
    raise SystemExit('security ownership anchor missing')
s = s.replace(old, new, 1)

# Match the shell builtin `eval` as a command token; do not flag command options such as mongo --eval.
old = "if grep -RFn --include='*.sh' 'eval ' \"$ROOT/bash\" >/tmp/scriptomatic-security-match 2>/dev/null; then\n"
new = "if grep -REn --include='*.sh' '(^|[;[:space:]])eval[[:space:]]' \"$ROOT/bash\" >/tmp/scriptomatic-security-match 2>/dev/null; then\n"
if old not in s:
    raise SystemExit('security eval anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)

# 3) Mock sudo in php-entry fixture so privilege transition preserves test PATH.
p = Path('tests/php-entry.sh')
s = p.read_text()
anchor = "chmod +x \"$work/bin/update-ca-certificates\"\n\nexport PATH=\"$work/bin:$PATH\"\n"
insert = """chmod +x \"$work/bin/update-ca-certificates\"\n\ncat > \"$work/bin/sudo\" <<'EOF_SUDO'\n#!/usr/bin/env sh\n[ \"${1:-}\" = \"--\" ] && shift\nexec \"$@\"\nEOF_SUDO\nchmod +x \"$work/bin/sudo\"\n: > \"$work/updates\"\n\nexport PATH=\"$work/bin:$PATH\"\n"""
if anchor not in s:
    raise SystemExit('php-entry sudo anchor missing')
p.write_text(s.replace(anchor, insert, 1))
