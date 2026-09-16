#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

[[ "$(id -u)" == 0 ]] || fail "PHP fixture must run as root"
source_text="$(cat "$ROOT/bash/php-cli-setup.sh")"
for removed in COMPOSER_VERSION PHP_EXT_INSTALLER_VERSION PHP_EXT_INSTALLER_SHA256 SCRIPTOMATIC_PASSWORDLESS_SUDO SCRIPTOMATIC_OH_MY_BASH; do
  assert_not_contains "$source_text" "$removed" "unsolicited PHP policy knob: $removed"
done
assert_contains "$source_text" '"$installer" @composer' "Composer remains installed through @composer"
assert_contains "$source_text" 'OHMB_URL="https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh"' "historical Oh My Bash source"
pass "PHP public interface matches main"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/scriptomatic/main/bash" "$work/toolset/2.0"
for helper in banner.sh docknotify.sh php-entry.sh alias-maker.sh; do cp "$ROOT/bash/$helper" "$work/scriptomatic/main/bash/$helper"; done

cat > "$work/toolset/2.0/gitx" <<'EOF'
#!/usr/bin/env sh
printf 'TOOLSET-FAKE-2.0 gitx\n'
EOF
cat > "$work/toolset/2.0/chromacat" <<'EOF'
#!/usr/bin/env sh
cat
EOF
chmod +x "$work/toolset/2.0/gitx" "$work/toolset/2.0/chromacat"
(cd "$work/toolset/2.0" && sha256sum gitx chromacat > SHA256SUMS)

cat > "$work/ipe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${IPE_CALLS:?}"
if [[ " $* " == *' @composer '* ]]; then
  printf '#!/usr/bin/env sh\nexit 0\n' > /usr/local/bin/composer
  chmod +x /usr/local/bin/composer
fi
EOF
chmod +x "$work/ipe"
: > "$work/ipe-calls"
printf '#!/usr/bin/env bash\nexit 0\n' > "$work/ohmb"
chmod +x "$work/ohmb"

cat > "$work/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
dest=''; url=''
while (($#)); do
  case "$1" in
    --output|-o) dest="$2"; shift 2 ;;
    --connect-timeout|--max-time) shift 2 ;;
    --fail|--location|--silent|--show-error) shift ;;
    *) url="$1"; shift ;;
  esac
done
case "$url" in
  */Toolset/releases/download/2.0/SHA256SUMS) cp "$FIXTURE_ROOT/toolset/2.0/SHA256SUMS" "$dest" ;;
  */Toolset/releases/download/2.0/gitx) cp "$FIXTURE_ROOT/toolset/2.0/gitx" "$dest" ;;
  */Toolset/releases/download/2.0/chromacat) cp "$FIXTURE_ROOT/toolset/2.0/chromacat" "$dest" ;;
  */Scriptomatic/main/bash/*) cp "$FIXTURE_ROOT/scriptomatic/main/bash/${url##*/}" "$dest" ;;
  */docker-php-extension-installer/releases/latest/download/install-php-extensions) cp "$FIXTURE_ROOT/ipe" "$dest" ;;
  */ohmybash/oh-my-bash/master/tools/install.sh) cp "$FIXTURE_ROOT/ohmb" "$dest" ;;
  *) printf 'unexpected mock curl URL: %s\n' "$url" >&2; exit 65 ;;
esac
EOF
chmod +x "$work/bin/curl"

PATH="$work/bin:$PATH" FIXTURE_ROOT="$work" IPE_CALLS="$work/ipe-calls" \
SCRIPTOMATIC_REF=main TOOLSET_REF=2.0 LINUX_PKG='' LINUX_PKG_VERSIONED='' PHP_EXT='' PHP_EXT_VERSIONED='' \
env UID=12001 GID=12001 bash "$ROOT/bash/php-cli-setup.sh" developer 8.4

assert_eq 12001 "$(id -u developer)" "developer UID"
assert_eq 12001 "$(id -g developer)" "developer GID"
assert_file /etc/sudoers.d/developer
assert_contains "$(cat /etc/sudoers.d/developer)" 'NOPASSWD:ALL' "historical sudo behavior"
assert_contains "$(cat "$work/ipe-calls")" '@composer' "Composer request"
assert_file /usr/local/bin/composer
for helper in gitx chromacat show-banner docknotify php-entry alias-maker; do
  assert_file "/usr/local/bin/$helper"
  assert_eq 'root:root' "$(stat -c '%U:%G' "/usr/local/bin/$helper")" "$helper ownership"
done
assert_contains "$(/usr/local/bin/gitx)" 'TOOLSET-FAKE-2.0' "Toolset 2.0 helper"
php-fpm -t >/dev/null 2>&1
pass "PHP bootstrap preserves behavior with hardened helper acquisition"

PATH="$work/bin:$PATH" FIXTURE_ROOT="$work" IPE_CALLS="$work/ipe-calls" \
SCRIPTOMATIC_REF=main TOOLSET_REF=2.0 LINUX_PKG='' LINUX_PKG_VERSIONED='' PHP_EXT='' PHP_EXT_VERSIONED='' \
env UID=12001 GID=12001 bash "$ROOT/bash/php-cli-setup.sh" developer 8.4
assert_eq 1 "$(grep -c '^include=/usr/local/etc/php-fpm.domains/php84/\*\.conf$' /usr/local/etc/php-fpm.conf)" "FPM include count"
assert_eq 1 "$(grep -c 'show-banner \"PHP 8.4\"' /home/developer/.bashrc)" "banner snippet count"
pass "PHP bootstrap repeat path stays idempotent"
