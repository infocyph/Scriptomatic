#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/home"
bashrc="$work/home/.bashrc"
printf '# existing user content\n' > "$bashrc"

HOME="$work/home" bash "$ROOT/bash/alias-maker.sh" >/dev/null
HOME="$work/home" bash "$ROOT/bash/alias-maker.sh" >/dev/null

assert_eq 1 "$(grep -c '^alias g=\"git\"$' "$bashrc")" "git alias duplication"
assert_eq 1 "$(grep -c '^alias l=\"lsd -l\"$' "$bashrc")" "listing alias duplication"
assert_eq 1 "$(grep -c '^# >>> scriptomatic-utils >>>$' "$bashrc")" "utility block count"
assert_eq 1 "$(grep -c '^# <<< scriptomatic-utils <<<$' "$bashrc")" "utility block end count"
assert_contains "$(cat "$bashrc")" '# existing user content' "existing bashrc content retained"
assert_contains "$(cat "$bashrc")" 'git_fix_eol()' "original utility functions retained"
assert_contains "$(cat "$bashrc")" 'git_clean_merged_branches()' "original git cleanup helper retained"
pass "alias-maker preserves main aliases/functions and remains repeatable"
