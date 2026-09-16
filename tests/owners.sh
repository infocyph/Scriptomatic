#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
repo="$work/repo"
mkdir -p "$repo" "$work/bin"
git -C "$work" init -q repo
git -C "$repo" config user.name tester
git -C "$repo" config user.email tester@example.com
printf x > "$repo/normal.txt"
printf x > "$repo/space file.txt"
printf x > "$repo/"$'line\nbreak.txt'
printf x > "$repo/"$'tab\tfile.txt'
git -C "$repo" add -A
git -C "$repo" commit -qm init

cat > "$work/bin/git-fame" <<'EOF_FAME'
#!/usr/bin/env sh
printf '%s\n' h1 h2 h3 h4 h5 h6
printf 'x/owner@example.com/c/d/e/50/g\n'
EOF_FAME
chmod +x "$work/bin/git-fame"

(
  cd "$repo"
  PATH="$work/bin:$PATH" bash "$ROOT/bash/owners.sh" > "$work/out"
)

assert_eq $'path\towners' "$(head -n1 "$work/out")" "owners TSV header"
assert_eq 5 "$(wc -l < "$work/out" | tr -d ' ')" "owners row count"
assert_contains "$(cat "$work/out")" $'normal.txt\towner@example.com' "normal path row"
assert_contains "$(cat "$work/out")" $'space file.txt\towner@example.com' "space path row"
assert_contains "$(cat "$work/out")" 'line\nbreak.txt' "newline path escaping"
assert_contains "$(cat "$work/out")" 'tab\tfile.txt' "tab path escaping"
pass "owners enumerates Git paths NUL-safely and emits escaped TSV"

set +e
PATH="/usr/bin:/bin" bash "$ROOT/bash/owners.sh" >/dev/null 2>"$work/missing" 
rc=$?
set -e
assert_eq 127 "$rc" "missing git-fame exit"
assert_contains "$(cat "$work/missing")" 'git-fame not found' "missing dependency diagnostic"
pass "owners reports missing git-fame explicitly"
