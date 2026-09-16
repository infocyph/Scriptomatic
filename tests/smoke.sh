#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

HOME="$work/home" bash "$ROOT/bash/alias-maker.sh" >/dev/null
assert_file "$work/home/.bashrc"
assert_contains "$(cat "$work/home/.bashrc")" '# >>> scriptomatic-utils >>>' "alias-maker managed block"
pass "alias-maker basic disposable-HOME smoke"

set +e
bash "$ROOT/bash/docknotify.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 2 "$rc" "docknotify usage exit code"
pass "docknotify usage contract"

set +e
bash "$ROOT/bash/php-cli-setup.sh" bad 8.4 >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "php bootstrap unexpectedly succeeded outside supported root image context"
pass "php bootstrap fails outside supported capability context"

printf 'smoke validation passed\n'
