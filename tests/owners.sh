#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/repo" "$tmp/fake"; cd "$tmp/repo"
/usr/bin/git init -q; /usr/bin/git config user.email test@example.com; /usr/bin/git config user.name test
printf 'x\n' >'file with space.txt'; printf 'y\n' >'semi;colon.txt'; /usr/bin/git add .; /usr/bin/git commit -qm initial
cat >"$tmp/fake/git" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == fame ]]; then
  if [[ "${2:-}" == --help ]]; then exit 0; fi
  printf 'h\nh\nh\nh\nh\nh\nrow|owner@example.com|x|x|x|40\n'
  printf '%s\n' "${@: -1}" >>"$OWNERS_ARGS_LOG"
  exit 0
fi
exec /usr/bin/git "$@"
EOF
chmod +x "$tmp/fake/git"
output="$(OWNERS_ARGS_LOG="$tmp/args" PATH="$tmp/fake:$PATH" "$ROOT/bash/owners.sh")"
[[ "$output" == *'file with space.txt owner@example.com'* ]] || fail 'owners lost filename with spaces'
[[ "$output" == *'semi;colon.txt owner@example.com'* ]] || fail 'owners lost shell-sensitive filename'
assert_contains "$tmp/args" 'file with space.txt'
assert_contains "$tmp/args" 'semi;colon.txt'
pass 'owners NUL-safe path handling'
