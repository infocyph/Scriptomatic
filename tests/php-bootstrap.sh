#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

[[ "$(id -u)" == 0 ]] || fail "php-bootstrap fixture must run as root inside a disposable PHP image"
command -v php >/dev/null 2>&1 || fail "php missing"
command -v apk >/dev/null 2>&1 || fail "apk missing"

source_text="$(cat "$ROOT/bash/php-cli-setup.sh")"
assert_not_contains "$source_text" 'COMPOSER_VERSION' "Composer version policy must not be introduced"
assert_not_contains "$source_text" 'PHP_EXT_INSTALLER_VERSION' "PHP extension installer version policy must not be introduced"
assert_not_contains "$source_text" 'SCRIPTOMATIC_PASSWORDLESS_SUDO' "sudo policy knob must not be introduced"
assert_not_contains "$source_text" 'SCRIPTOMATIC_OH_MY_BASH' "Oh My Bash policy knob must not be introduced"
assert_contains "$source_text" '"$installer" @composer' "Composer remains installed through install-php-extensions"
pass "PHP public contract matches main behavior"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/scriptomatic/main/bash" "$work/toolset/2.0"

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

cat > "$work/ipe" <<'EOF_IPE'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "${IPE_CALLS:?}"
for item in "$@"; do
  if [[ "$item" == @composer ]]; then
    cat > /usr/local/bin/composer <<'EOF_COMPOSER'
#!/usr/bin/env sh
printf 'Composer fixture\n'
EOF_COMPOSER
    chmod +x /usr/local/bin/composer
  fi
done
EOF_IPE
chmod +x "$work/ipe"
: > "$work/ipe-calls"

cat > "$work/ohmb-install" <<'EOF_OHMB'
#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p "$HOME/.oh-my-bash"
touch "$HOME/.bashrc"
printf 'OSH_THEME="font"\nDISABLE_AUTO_UPDATE="false"\nplugins=(git)\n' >> "$HOME/.bashrc"
EOF_OHMB
chmod +x "$work/ohmb-install"

cat > "$work/bin/curl" <<'EOF_CURL'
#!/usr/bin/env bash
set -Eeuo pipefail
dest=''
url=''
while (($#)); do
  case "$1" in
    --output|-o) dest="$2"; shift 2 ;;
    --connect-timeout|--max-time) shift 2 ;;
    --fail|--location|--silent|--show-error) shift ;;
    *) url="$1"; shift ;;
  esac
done
[[ -n "$dest" && -n "$url" ]] || { printf 'mock curl: missing url/dest\n' >&2; exit 64; }
case "$url" in
  https://github.com/infocyph/Toolset/releases/download/2.0/SHA256SUMS)
    cp "$FIXTURE_ROOT/toolset/2.0/SHA256SUMS" "$dest" ;;
  https://github.com/infocyph/Toolset/releases/download/2.0/gitx)
    cp "$FIXTURE_ROOT/toolset/2.0/gitx" "$dest" ;;
  https://github.com/infocyph/Toolset/releases/download/2.0/chromacat)
    cp "$FIXTURE_ROOT/toolset/2.0/chromacat" "$dest" ;;
  https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/*)
    cp "$FIXTURE_ROOT/scriptomatic/main/bash/${url##*/}" "$dest" ;;
  https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions)
    cp "$FIXTURE_ROOT/ipe" "$dest" ;;
  https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)
    cp "$FIXTURE_ROOT/ohmb-install" "$dest" ;;
  *) printf 'mock curl: unexpected URL %s\n' "$url" >&2; exit 65 ;;
esac
EOF_CURL
chmod +x "$work/bin/curl"

export PATH="$work/bin:$PATH"
export FIXTURE_ROOT="$work"
export IPE_CALLS="$work/ipe-calls"
export SCRIPTOMATIC_REF=main
export TOOLSET_REF=2.0
export LINUX_PKG=''
export LINUX_PKG_VERSIONED=''
export PHP_EXT=''
export PHP_EXT_VERSIONED=''

# Preserve the original Docker build ARG names; the script must consume UID/GID.
env UID=12001 GID=12001 PATH="$PATH" FIXTURE_ROOT="$FIXTURE_ROOT" IPE_CALLS="$IPE_CALLS" \
  SCRIPTOMATIC_REF=main TOOLSET_REF=2.0 \
  LINUX_PKG='' LINUX_PKG_VERSIONED='' PHP_EXT='' PHP_EXT_VERSIONED='' \
  bash "$ROOT/bash/php-cli-setup.sh" developer 8.4

assert_eq 12001 "$(id -u developer)" "developer UID"
assert_eq 12001 "$(id -g developer)" "developer GID"
assert_eq /home/developer "$(getent passwd developer | cut -d: -f6)" "developer home"
assert_eq /bin/bash "$(getent passwd developer | cut -d: -f7)" "developer shell"
assert_file /etc/sudoers.d/developer
assert_contains "$(cat /etc/sudoers.d/developer)" 'NOPASSWD:ALL' "passwordless sudo remains enabled"
assert_file /home/developer/.oh-my-bash
assert_contains "$(cat /home/developer/.bashrc)" 'OSH_THEME="lambda"' "Oh My Bash theme remains lambda"
assert_contains "$(cat "$work/ipe-calls")" '@composer' "Composer install request"
assert_file /usr/local/bin/composer
pass "developer bootstrap defaults from main are preserved"

for helper in gitx chromacat show-banner docknotify php-entry alias-maker; do
  assert_file "/usr/local/bin/$helper"
  assert_eq 'root:root' "$(stat -c '%U:%G' "/usr/local/bin/$helper")" "$helper ownership"
  assert_eq 755 "$(stat -c '%a' "/usr/local/bin/$helper")" "$helper mode"
done
assert_contains "$(/usr/local/bin/gitx)" 'TOOLSET-FAKE-2.0' "Toolset 2.0 fixture installed"
assert_eq "$(sha256sum "$ROOT/bash/php-entry.sh" | awk '{print $1}')" "$(sha256sum /usr/local/bin/php-entry | awk '{print $1}')" "same-ref Scriptomatic helper"
pass "helper acquisition is hardened without changing runtime UX"

assert_file /usr/local/etc/php/conf.d/99-script-bundle.ini
assert_file /etc/msmtprc
assert_file /etc/profile.d/banner-hook.sh
assert_file /etc/profile.d/git-config-global.sh
assert_file /etc/profile.d/composer-home.sh
php --ini >/dev/null
php-fpm -t >/dev/null 2>&1
pass "generated PHP/FPM configuration validates"

env UID=12001 GID=12001 PATH="$PATH" FIXTURE_ROOT="$FIXTURE_ROOT" IPE_CALLS="$IPE_CALLS" \
  SCRIPTOMATIC_REF=main TOOLSET_REF=2.0 \
  LINUX_PKG='' LINUX_PKG_VERSIONED='' PHP_EXT='' PHP_EXT_VERSIONED='' \
  bash "$ROOT/bash/php-cli-setup.sh" developer 8.4
assert_eq 1 "$(grep -c '^include=/usr/local/etc/php-fpm.domains/php84/\*\.conf$' /usr/local/etc/php-fpm.conf)" "FPM domain include duplication"
assert_eq 1 "$(grep -c 'show-banner \"PHP 8.4\"' /home/developer/.bashrc)" "banner snippet duplication"
pass "PHP bootstrap repeat path is idempotent"
