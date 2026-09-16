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
  : >"$match_file"
}

all_scripts=("$ROOT"/bash/*.sh)
bootstrap_files=(
  "$ROOT/bash/php-cli-setup.sh"
  "$ROOT/bash/php-entry.sh"
  "$ROOT/bash/node-cli-setup.sh"
  "$ROOT/bash/node-entry.sh"
)

# Repository-wide final-state blockers.
assert_absent 'Toolset/(main|master)/' "no Scriptomatic path may consume mutable Toolset branches" "${all_scripts[@]}"
assert_absent 'Scriptomatic/master/' "no Scriptomatic path may hard-code the retired master ref" "${all_scripts[@]}"
assert_absent 'releases/latest' "executable dependencies must not use releases/latest" "${all_scripts[@]}"
assert_absent 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "remote pipe-to-shell execution is forbidden" "${all_scripts[@]}"
assert_absent 'rm[[:space:]]+-rf[[:space:]]+(/tmp/\*|/var/tmp/\*)' "scripts must not broadly delete shared temp trees" "${all_scripts[@]}"
assert_absent 'rm[[:space:]]+-f[[:space:]]+--[[:space:]]+"\$0"' "setup scripts must not self-delete" "${all_scripts[@]}"
assert_absent '\.rootca_installed' "entrypoints must not use predictable stale CA stamps" "${all_scripts[@]}"
assert_absent 'chown[^\n]*(\$USERNAME|\$\{USERNAME\})[^\n]*/usr/local/bin' "shared executables must not become ordinary-user owned" "${all_scripts[@]}"

# `eval` as a shell command is forbidden. Command options such as Mongo's --eval are not shell eval.
if grep -REn --include='*.sh' '(^|[;[:space:]])eval[[:space:]]' "$ROOT/bash" >"$match_file" 2>/dev/null; then
  cat "$match_file" >&2
  fail "shell eval is not accepted"
fi
: >"$match_file"

# Runtime/bootstrap-specific invariants.
grep -qF ': "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}"' "$ROOT/bash/php-cli-setup.sh" || fail "PHP developer sudo default drifted"
grep -qF ': "${SCRIPTOMATIC_OH_MY_BASH:=1}"' "$ROOT/bash/php-cli-setup.sh" || fail "PHP Oh My Bash default drifted"
grep -qF ': "${COMPOSER_VERSION:=2.10.3}"' "$ROOT/bash/php-cli-setup.sh" || fail "PHP Composer default drifted"
grep -qF ': "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}"' "$ROOT/bash/node-cli-setup.sh" || fail "Node developer sudo default drifted"
grep -qF ': "${SCRIPTOMATIC_OH_MY_BASH:=1}"' "$ROOT/bash/node-cli-setup.sh" || fail "Node Oh My Bash default drifted"
for preserved in 'NODE_LOG_ENABLED:=1' 'NODE_KEEPALIVE_ON_FAIL:=1' 'NODE_AUTO_INSTALL:=1' 'NODE_ALLOW_LOCKFILE_FALLBACK:=1'; do
  grep -qF "$preserved" "$ROOT/bash/node-entry.sh" || fail "Node compatibility default drifted: $preserved"
done
assert_absent 'for[[:space:]].*\$\(git[[:space:]]+ls-files' "owners must keep Git path enumeration NUL-safe" "$ROOT/bash/owners.sh"
assert_absent 'payload=.*\$\(printf' "docknotify must stream its final newline-bearing protocol record" "$ROOT/bash/docknotify.sh"
assert_absent 'docker[[:space:]]+exec[[:space:]]+-[^[:space:]]*t' "non-interactive automation must not request a Docker TTY" "$ROOT/bash/certbot-hook.sh"
assert_absent 'docker[[:space:]]+ps[^\n]*name=' "Certbot hook must use exact container inspection" "$ROOT/bash/certbot-hook.sh"
assert_absent 'sleep[[:space:]]+10([[:space:]]|$)' "Mongo bootstrap must not depend on fixed startup sleep" "$ROOT/bash/mongo-replica.sh"

# Bootstrap downloads are allowed only through their hardened helper functions; mutable references remain prohibited.
assert_absent 'raw.githubusercontent.com/infocyph/Toolset/(main|master)' "Toolset executable acquisition must use stable release assets" "${bootstrap_files[@]}"

printf '%s\n' \
  'Repository-wide security boundary: clean.' \
  'Container automation is non-interactive; mutable executable refs and broad shared-temp mutation are rejected.'
pass "security audit completed"
