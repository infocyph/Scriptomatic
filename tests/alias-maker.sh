#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home"
: >"$tmp/home/.bashrc"; chmod 0640 "$tmp/home/.bashrc"
HOME="$tmp/home" "$ROOT/bash/alias-maker.sh" >/dev/null
HOME="$tmp/home" "$ROOT/bash/alias-maker.sh" >/dev/null
assert_eq 1 "$(grep -Fc '# >>> scriptomatic-utils >>>' "$tmp/home/.bashrc")" 'managed block duplicated'
assert_eq 1 "$(grep -Fc 'alias g="git"' "$tmp/home/.bashrc")" 'alias duplicated'
assert_eq 640 "$(stat -c %a "$tmp/home/.bashrc")" '.bashrc mode changed'
mkdir -p "$tmp/repo" "$tmp/fakebin"; cd "$tmp/repo"
git init -q; git config user.email test@example.com; git config user.name test
file='space ; file.php'; printf 'one\n' >"$file"; git add -- "$file"; git commit -qm initial; printf 'two\n' >>"$file"
cat >"$tmp/fakebin/dos2unix" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${@: -1}" >>"$DOS2UNIX_LOG"
EOF
chmod +x "$tmp/fakebin/dos2unix"
DOS2UNIX_LOG="$tmp/dos2unix.log" PATH="$tmp/fakebin:$PATH" HOME="$tmp/home" bash -c 'source "$HOME/.bashrc"; git_fix_eol' >/dev/null
assert_contains "$tmp/dos2unix.log" "$file"
pass 'alias maker idempotency and path safety'
