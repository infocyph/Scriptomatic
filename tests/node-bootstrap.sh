#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

(
  set -- dev 24
  # shellcheck source=/dev/null
  source "$ROOT/bash/node-cli-setup.sh"
  validate_username dev_user
  validate_version 24.1.0
  validate_id UID 1000
  validate_id GID 1000
  parse_csv 'typescript@5.9,@nestjs/cli@11' NODE_GLOBAL parsed
  assert_eq 2 "${#parsed[@]}" 'Node CSV parser count'
  assert_eq 'typescript@5.9' "${parsed[0]}" 'Node CSV parser first token'
  if validate_token NODE_GLOBAL 'pkg;id' >/dev/null 2>&1; then
    fail 'Node package shell syntax was accepted'
  fi
  NODE_LOG_DIR=/var/log/node-app
  validate_inputs
  assert_eq 'https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash' "$SCRIPTOMATIC_BASE_URL" 'Node sibling source must use main'
)

if [[ "${SCRIPTOMATIC_FULL_INTEGRATION:-0}" == 1 ]]; then
  command -v docker >/dev/null 2>&1 || fail 'Docker required for full Node integration'
  docker run --rm -v "$ROOT:/repo:ro" node:24-alpine sh -ceu '
    apk add --no-cache bash >/dev/null
    cp /repo/bash/node-cli-setup.sh /tmp/cli-setup.sh
    chmod +x /tmp/cli-setup.sh
    env UID=1000 GID=1000 /tmp/cli-setup.sh dev 24
    test "$(id -u dev)" = 1000
    test "$(id -g dev)" = 1000
    sudo -n -u dev true
    test -x /usr/local/bin/gitx
    test -x /usr/local/bin/chromacat
    test -x /usr/local/bin/show-banner
    test -x /usr/local/bin/docknotify
    test -x /usr/local/bin/node-entry
    test -x /usr/local/bin/alias-maker
    test "$(stat -c %U /usr/local/bin/gitx)" = root
    grep -Fq "NPM_CONFIG_PREFIX" /home/dev/.bashrc
    grep -Fq "GIT_CONFIG_GLOBAL" /home/dev/.bashrc
    test ! -e /tmp/cli-setup.sh
  '
fi

pass 'Node bootstrap hardening contract'
