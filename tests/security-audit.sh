#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

assert_absent() {
  local pattern="$1" message="$2"
  shift 2
  if grep -En -- "$pattern" "$@" >/tmp/scriptomatic-security-match 2>/dev/null; then
    cat /tmp/scriptomatic-security-match >&2
    rm -f /tmp/scriptomatic-security-match
    fail "$message"
  fi
  rm -f /tmp/scriptomatic-security-match
}

php_files=("$ROOT/bash/php-cli-setup.sh" "$ROOT/bash/php-entry.sh")

assert_absent 'Toolset/(main|master)/' "PHP path must not consume mutable Toolset branches" "${php_files[@]}"
assert_absent 'Scriptomatic/master/' "PHP path must not hard-code Scriptomatic master" "${php_files[@]}"
assert_absent 'releases/latest' "PHP executable dependencies must not use releases/latest" "${php_files[@]}"
assert_absent 'curl[^|]*\|[[:space:]]*(ba)?sh' "PHP path must not execute curl pipelines" "${php_files[@]}"
assert_absent 'rm[[:space:]]+-rf[[:space:]]+(/tmp/\*|/var/tmp/\*)' "PHP path must not broadly delete temp trees" "${php_files[@]}"
assert_absent 'rm[[:space:]]+-f[[:space:]]+--[[:space:]]+"\$0"' "PHP setup must not self-delete" "${php_files[@]}"
assert_absent '\.rootca_installed' "PHP entrypoint must not use predictable stale CA stamp" "${php_files[@]}"
assert_absent 'chown[^\n]*(\$USERNAME|\$\{USERNAME\})[^\n]*/usr/local/bin' "PHP setup must not chown shared executables to ordinary users" "${php_files[@]}"

# Cross-cutting hard blockers that should never be introduced during any phase.
if grep -REn --include='*.sh' '(^|[;[:space:]])eval[[:space:]]' "$ROOT/bash" >/tmp/scriptomatic-security-match 2>/dev/null; then
  cat /tmp/scriptomatic-security-match >&2
  rm -f /tmp/scriptomatic-security-match
  fail "eval requires explicit review and is not accepted by default"
fi
rm -f /tmp/scriptomatic-security-match

printf '%s\n' \
  'Reviewed phase backlog remains in Node/server/shared-utility scripts and is tracked in docs/plans/scriptomatic-progress-tracker.md.' \
  'Phase 2 PHP security boundary: clean.'
pass "security audit completed"
