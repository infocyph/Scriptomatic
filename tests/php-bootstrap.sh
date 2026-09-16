#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

[[ "$(id -u)" == 0 ]] || fail "php-bootstrap fixture must run as root inside a disposable PHP image"
command -v php >/dev/null 2>&1 || fail "php missing"
command -v apk >/dev/null 2>&1 || fail "apk missing"
grep -qF '${COMPOSER_VERSION:=2.10.3}' "$ROOT/bash/php-cli-setup.sh" || fail "Composer compatibility default"
grep -qF '${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}' "$ROOT/bash/php-cli-setup.sh" || fail "PHP sudo compatibility default"
grep -qF '${SCRIPTOMATIC_OH_MY_BASH:=1}' "$ROOT/bash/php-cli-setup.sh" || fail "PHP Oh My Bash compatibility default"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/scriptomatic/main/bash" "$work/toolset/2.0"

for helper in banner.sh docknotify.sh php-entry.sh alias-maker.sh; do
  cp "$ROOT/bash/$helper" "$work/scriptomatic/main/bash/$helper"
done

cat > "$work/toolset/2.0/gitx" <<'EOF_GITX'
#!/usr/bin/env bash
printf 'TOOLSET-FAKE-2.0 gitx\n'
EOF_GITX
cat > "$work/toolset/2.0/chromacat" <<'EOF_CHROMA'
#!/usr/bin/env bash
cat
EOF_CHROMA
chmod +x "$work/toolset/2.0/gitx" "$work/toolset/2.0/chromacat"
(
  cd "$work/toolset/2.0"
  sha256sum gitx chromacat > SHA256SUMS
)

export SCRIPTOMATIC_UID=12001
export SCRIPTOMATIC_GID=12001
export SCRIPTOMATIC_REF=main
export SCRIPTOMATIC_BASE_URL="file://$work/scriptomatic"
export TOOLSET_REF=2.0
export TOOLSET_RELEASE_BASE_URL="file://$work/toolset"
export SCRIPTOMATIC_PASSWORDLESS_SUDO=0
export SCRIPTOMATIC_OH_MY_BASH=0
export LINUX_PKG=''
export LINUX_PKG_VERSIONED=''
export PHP_EXT=''
export PHP_EXT_VERSIONED=''
export COMPOSER_VERSION=''

bash "$ROOT/bash/php-cli-setup.sh" developer 8.4

assert_eq 12001 "$(id -u developer)" "developer UID"
assert_eq 12001 "$(id -g developer)" "developer GID"
assert_eq /home/developer "$(getent passwd developer | cut -d: -f6)" "developer home"
assert_eq /bin/bash "$(getent passwd developer | cut -d: -f7)" "developer shell"
assert_not_file /etc/sudoers.d/developer
pass "developer identity and opt-in sudo policy"

for helper in gitx chromacat show-banner docknotify php-entry alias-maker; do
  assert_file "/usr/local/bin/$helper"
  assert_eq 'root:root' "$(stat -c '%U:%G' "/usr/local/bin/$helper")" "$helper ownership"
  assert_eq 755 "$(stat -c '%a' "/usr/local/bin/$helper")" "$helper mode"
done
assert_contains "$(/usr/local/bin/gitx)" 'TOOLSET-FAKE-2.0' "exact Toolset fixture installed"
assert_eq "$(sha256sum "$ROOT/bash/php-entry.sh" | awk '{print $1}')" "$(sha256sum /usr/local/bin/php-entry | awk '{print $1}')" "same-ref Scriptomatic helper"
pass "Toolset and Scriptomatic helper acquisition contract"

assert_file /usr/local/etc/php/conf.d/99-script-bundle.ini
assert_file /etc/msmtprc
assert_file /etc/profile.d/banner-hook.sh
assert_file /etc/profile.d/git-config-global.sh
assert_file /etc/profile.d/composer-home.sh
php --ini >/dev/null
php-fpm -t >/dev/null 2>&1
pass "generated PHP/FPM configuration validates"

# Whole bootstrap should remain safe to rerun for build retries.
bash "$ROOT/bash/php-cli-setup.sh" developer 8.4
assert_eq 1 "$(grep -c '^include=/usr/local/etc/php-fpm.domains/php84/\*\.conf$' /usr/local/etc/php-fpm.conf)" "FPM domain include duplication"
assert_eq 1 "$(grep -c 'show-banner \"PHP 8.4\"' /home/developer/.bashrc)" "banner snippet duplication"
pass "PHP bootstrap repeat path is idempotent"
