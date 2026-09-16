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
  parsed=()
  parse_csv 'typescript@5.9,@nestjs/cli@11' NODE_GLOBAL parsed
  assert_eq 2 "${#parsed[@]}" 'Node CSV parser count'
  assert_eq 'typescript@5.9' "${parsed[0]}" 'Node CSV parser first token'
  if validate_token NODE_GLOBAL 'pkg;id' >/dev/null 2>&1; then
    fail 'Node package shell syntax was accepted'
  fi
  validate_inputs
  assert_eq main "$SCRIPTOMATIC_REF" 'Node Scriptomatic ref default'
  assert_eq 2.0 "$TOOLSET_REF" 'Node Toolset ref default'
  assert_eq 'https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash' "$SCRIPTOMATIC_BASE_URL" 'Node sibling source default'
  assert_eq 'https://github.com/infocyph/Toolset/releases/download/2.0' "$TOOLSET_RELEASE_BASE_URL" 'Node Toolset release source'
)

(
  export SCRIPTOMATIC_REF=0123456789abcdef0123456789abcdef01234567
  export TOOLSET_REF=2.0
  set -- dev 24
  # shellcheck source=/dev/null
  source "$ROOT/bash/node-cli-setup.sh"
  validate_dependency_refs
  assert_eq 'https://raw.githubusercontent.com/infocyph/Scriptomatic/0123456789abcdef0123456789abcdef01234567/bash' \
    "$SCRIPTOMATIC_BASE_URL" 'Node pinned sibling source'
)

(
  export SCRIPTOMATIC_REF=feature-branch
  set -- dev 24
  # shellcheck source=/dev/null
  source "$ROOT/bash/node-cli-setup.sh"
  if validate_dependency_refs >/dev/null 2>&1; then
    fail 'Node accepted a non-main non-SHA Scriptomatic ref'
  fi
)

if [[ "${SCRIPTOMATIC_FULL_INTEGRATION:-0}" == 1 ]]; then
  command -v docker >/dev/null 2>&1 || fail 'Docker required for full Node integration'
  docker run --rm -v "$ROOT:/repo:ro" node:24-alpine sh -ceu '
    apk add --no-cache bash >/dev/null
    cp /repo/bash/node-cli-setup.sh /tmp/cli-setup.sh
    chmod +x /tmp/cli-setup.sh
    env UID=1000 GID=1000 SCRIPTOMATIC_REF=main TOOLSET_REF=2.0 /tmp/cli-setup.sh dev 24
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

    # Exercise the separate fresh-account branch without repeating package and
    # network bootstrap. The first full setup already installed its required
    # user-management tools and helper destinations.
    env UID=1001 GID=1001 bash -ceu '\''
      set -- freshdev 24
      source /repo/bash/node-cli-setup.sh
      create_user
      test "$(id -u freshdev)" = 1001
      test "$(id -g freshdev)" = 1001
      test "$(getent passwd freshdev | cut -d: -f6)" = /home/freshdev
      test "$(getent passwd freshdev | cut -d: -f7)" = /bin/bash
      sudo -n -u freshdev true
    '\''
  '
fi

pass 'Node bootstrap hardening and dependency contract'
