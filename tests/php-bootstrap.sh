#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

(
  set -- dev 8.4
  # shellcheck source=/dev/null
  source "$ROOT/bash/php-cli-setup.sh"
  validate_username dev_user
  validate_version 8.4
  validate_id UID 1000
  validate_id GID 1000
  parse_csv 'curl-dev,icu-dev' LINUX_PKG parsed
  assert_eq 2 "${#parsed[@]}" 'PHP CSV parser count'
  assert_eq 'curl-dev' "${parsed[0]}" 'PHP CSV parser first token'
  if validate_token LINUX_PKG '--repository=http://evil' >/dev/null 2>&1; then
    fail 'PHP package option injection was accepted'
  fi
  if validate_token PHP_EXT 'xdebug;touch/tmp/pwn' >/dev/null 2>&1; then
    fail 'PHP extension shell syntax was accepted'
  fi
  assert_eq main "$SCRIPTOMATIC_REF" 'PHP Scriptomatic ref default'
  assert_eq 'https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash' "$SCRIPTOMATIC_BASE_URL" 'PHP sibling source default'
  assert_eq 'https://github.com/infocyph/Toolset/releases/latest/download/install.sh' "$TOOLSET_INSTALLER_URL" 'PHP Toolset installer source'
)

(
  export SCRIPTOMATIC_REF=0123456789abcdef0123456789abcdef01234567
  set -- dev 8.4
  # shellcheck source=/dev/null
  source "$ROOT/bash/php-cli-setup.sh"
  validate_scriptomatic_ref
  assert_eq 'https://raw.githubusercontent.com/infocyph/Scriptomatic/0123456789abcdef0123456789abcdef01234567/bash' \
    "$SCRIPTOMATIC_BASE_URL" 'PHP pinned sibling source'
)

(
  export SCRIPTOMATIC_REF=feature-branch
  set -- dev 8.4
  # shellcheck source=/dev/null
  source "$ROOT/bash/php-cli-setup.sh"
  if validate_scriptomatic_ref >/dev/null 2>&1; then
    fail 'PHP accepted a non-main non-SHA Scriptomatic ref'
  fi
)

if [[ "${SCRIPTOMATIC_FULL_INTEGRATION:-0}" == 1 ]]; then
  command -v docker >/dev/null 2>&1 || fail 'Docker required for full PHP integration'
  docker run --rm -v "$ROOT:/repo:ro" php:8.4-fpm-alpine sh -ceu '
    apk add --no-cache bash >/dev/null
    cp /repo/bash/php-cli-setup.sh /tmp/cli-setup.sh
    chmod +x /tmp/cli-setup.sh
    env UID=1000 GID=1000 SCRIPTOMATIC_REF=main /tmp/cli-setup.sh dev 8.4
    test "$(id -u dev)" = 1000
    test "$(id -g dev)" = 1000
    sudo -n -u dev true
    test -x /usr/local/bin/gitx
    test -x /usr/local/bin/chromacat
    test -x /usr/local/bin/show-banner
    test -x /usr/local/bin/docknotify
    test -x /usr/local/bin/php-entry
    test -x /usr/local/bin/alias-maker
    test "$(stat -c %U /usr/local/bin/gitx)" = root
    php --ini >/dev/null
    php-fpm -t >/dev/null 2>&1
    test -f /etc/msmtprc
    test ! -e /tmp/cli-setup.sh
  '
fi

pass 'PHP bootstrap hardening and latest-stable dependency contract'
