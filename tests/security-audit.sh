#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

match_file="$(mktemp)"
trap 'rm -f -- "$match_file"' EXIT

assert_absent() {
  local pattern="$1" message="$2"
  shift 2
  if grep -En -- "$pattern" "$@" >"$match_file" 2>/dev/null; then
    cat "$match_file" >&2
    fail "$message"
  fi
  : > "$match_file"
}

bootstrap_files=(
  "$ROOT/bash/php-cli-setup.sh"
  "$ROOT/bash/php-entry.sh"
  "$ROOT/bash/node-cli-setup.sh"
  "$ROOT/bash/node-entry.sh"
)
utility_files=(
  "$ROOT/bash/alias-maker.sh"
  "$ROOT/bash/banner.sh"
  "$ROOT/bash/docknotify.sh"
  "$ROOT/bash/owners.sh"
)

assert_absent 'Toolset/(main|master)/' "bootstrap paths must not consume mutable Toolset branches" "${bootstrap_files[@]}"
assert_absent 'Scriptomatic/master/' "bootstrap paths must not hard-code Scriptomatic master" "${bootstrap_files[@]}"
assert_absent 'releases/latest' "bootstrap executable dependencies must not use releases/latest" "${bootstrap_files[@]}"
assert_absent 'curl[^|]*\|[[:space:]]*(ba)?sh' "bootstrap paths must not execute curl pipelines" "${bootstrap_files[@]}"
assert_absent 'rm[[:space:]]+-rf[[:space:]]+(/tmp/\*|/var/tmp/\*)' "bootstrap paths must not broadly delete temp trees" "${bootstrap_files[@]}"
assert_absent 'rm[[:space:]]+-f[[:space:]]+--[[:space:]]+"\$0"' "setup scripts must not self-delete" "${bootstrap_files[@]}"
assert_absent '\.rootca_installed' "entrypoints must not use predictable stale CA stamps" "${bootstrap_files[@]}"
assert_absent 'chown[^\n]*(\$USERNAME|\$\{USERNAME\})[^\n]*/usr/local/bin' "setup must not chown shared executables to ordinary users" "${bootstrap_files[@]}"
assert_absent 'npm@latest|npm@next' "Node setup must not float npm implicitly" "$ROOT/bash/node-cli-setup.sh"
assert_absent 'NODE_LOG_ENABLED:=1|NODE_KEEPALIVE_ON_FAIL:=1' "Node runtime unsafe convenience must not be the default" "$ROOT/bash/node-entry.sh"
assert_absent 'for[[:space:]].*\$\(git[[:space:]]+ls-files' "owners must not split Git paths through command substitution" "$ROOT/bash/owners.sh"
assert_absent 'payload=.*\$\(printf' "docknotify must not strip protocol newline in command substitution" "$ROOT/bash/docknotify.sh"

# Cross-cutting hard blockers that should never be introduced during any phase.
if grep -REn --include='*.sh' '(^|[;[:space:]])eval[[:space:]]' "$ROOT/bash" >"$match_file" 2>/dev/null; then
  cat "$match_file" >&2
  fail "shell eval requires explicit review and is not accepted by default"
fi
: > "$match_file"

# Shared utilities should not introduce network execution or writable config sourcing.
assert_absent 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "shared utilities must not execute remote pipelines" "${utility_files[@]}"

printf '%s\n' \
  'Reviewed Phase 5 backlog remains in certbot/mongo helpers and is tracked in docs/plans/scriptomatic-progress-tracker.md.' \
  'Phase 2-4 bootstrap/runtime/utility security boundary: clean.'
pass "security audit completed"
