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
  "$ROOT/bash/node-cli-setup.sh"
)

# Concrete repository-wide hazards only. Do not turn implementation hardening
# into product/version/default policy.
assert_absent 'raw.githubusercontent.com/infocyph/Toolset/(main|master)' "Toolset helpers must use the agreed stable 2.0 release" "${bootstrap_files[@]}"
assert_absent 'raw.githubusercontent.com/infocyph/Scriptomatic/master/' "Scriptomatic sibling helpers must use the canonical main/ref contract" "${bootstrap_files[@]}"
assert_absent 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "remote pipe-to-shell execution is forbidden" "${all_scripts[@]}"
assert_absent 'rm[[:space:]]+-rf[[:space:]]+(/tmp/\*|/var/tmp/\*)' "scripts must not broadly delete shared temp trees" "${all_scripts[@]}"
assert_absent 'rm[[:space:]]+-f[[:space:]]+--[[:space:]]+"\$0"' "setup scripts must not self-delete" "${all_scripts[@]}"
assert_absent '\.rootca_installed' "entrypoints must not use stale predictable CA stamp state" "${all_scripts[@]}"
assert_absent 'chown[^\n]*(\$USERNAME|\$\{USERNAME\})[^\n]*/usr/local/bin' "shared executables must not become ordinary-user owned" "${all_scripts[@]}"

if grep -REn --include='*.sh' '(^|[;[:space:]])eval[[:space:]]' "$ROOT/bash" >"$match_file" 2>/dev/null; then
  cat "$match_file" >&2
  fail "shell eval is not accepted"
fi
: >"$match_file"

# Do not reintroduce policy/configuration interfaces that were never in main.
for removed in \
  COMPOSER_VERSION PHP_EXT_INSTALLER_VERSION PHP_EXT_INSTALLER_SHA256 \
  SCRIPTOMATIC_PASSWORDLESS_SUDO SCRIPTOMATIC_OH_MY_BASH; do
  assert_absent "$removed" "unsolicited PHP bootstrap policy knob: $removed" "$ROOT/bash/php-cli-setup.sh"
done
for removed in NPM_VERSION SCRIPTOMATIC_REPRODUCIBLE SCRIPTOMATIC_PASSWORDLESS_SUDO SCRIPTOMATIC_OH_MY_BASH; do
  assert_absent "$removed" "unsolicited Node bootstrap policy knob: $removed" "$ROOT/bash/node-cli-setup.sh"
done
for removed in NODE_AUTO_INSTALL NODE_ALLOW_LOCKFILE_FALLBACK ROOTCA_REQUIRED; do
  assert_absent "$removed" "unsolicited Node entrypoint policy knob: $removed" "$ROOT/bash/node-entry.sh"
done
assert_absent 'ROOTCA_DEST=' "root CA destination must remain internal" "$ROOT/bash/php-entry.sh" "$ROOT/bash/node-entry.sh"
assert_absent 'CERTBOT_(NGINX|APACHE)_CONTAINER|CERTBOT_RENEW_' "Certbot behavior must not gain a new configuration policy" "$ROOT/bash/certbot-hook.sh" "$ROOT/bash/certbot-renew.sh"
assert_absent '\$\{MONGO_(RS_NAME|MEMBERS|READY|INIT|SHELL)' "Mongo fixed topology must not become a public environment interface" "$ROOT/bash/mongo-replica.sh"

# Concrete correctness/safety invariants retained from hardening.
assert_absent 'for[[:space:]].*\$\(git[[:space:]]+ls-files' "owners must keep Git path enumeration NUL-safe" "$ROOT/bash/owners.sh"
assert_absent 'payload=.*\$\(printf' "docknotify must stream its final newline-bearing protocol record" "$ROOT/bash/docknotify.sh"
assert_absent 'docker[[:space:]]+exec[[:space:]]+-[^[:space:]]*t' "Certbot automation must not request a Docker TTY" "$ROOT/bash/certbot-hook.sh"
assert_absent 'docker[[:space:]]+ps[^\n]*name=' "Certbot hook must use exact container inspection" "$ROOT/bash/certbot-hook.sh"
assert_absent 'sleep[[:space:]]+10([[:space:]]|$)' "Mongo bootstrap must not depend on fixed startup sleep" "$ROOT/bash/mongo-replica.sh"

printf '%s\n' \
  'Repository security boundary: clean.' \
  'Audit is limited to concrete hazards and explicitly agreed dependency refs.'
pass "security audit completed"
