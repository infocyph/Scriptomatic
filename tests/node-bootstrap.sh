#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

[[ "$(id -u)" == 0 ]] || fail "node-bootstrap fixture must run as root inside a disposable Node image"
command -v node >/dev/null 2>&1 || fail "node fixture missing node"
[[ -f /etc/alpine-release ]] || fail "node bootstrap integration expects Alpine fixture"

source_text="$(cat "$ROOT/bash/node-cli-setup.sh")"
for removed in NPM_VERSION SCRIPTOMATIC_REPRODUCIBLE SCRIPTOMATIC_PASSWORDLESS_SUDO SCRIPTOMATIC_OH_MY_BASH; do
  assert_not_contains "$source_text" "$removed" "unsolicited Node policy knob: $removed"
done
assert_contains "$source_text" 'npm install -g npm@latest || npm install -g npm@next || true' "historical npm update behavior"
pass "Node public contract matches main behavior"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/scriptomatic/main/bash" "$work/toolset/2.0"

for helper in banner.sh docknotify.sh node-entry.sh alias-maker.sh; do
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
  https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)
    cp "$FIXTURE_ROOT/ohmb-install" "$dest" ;;
  *) printf 'mock curl: unexpected URL %s\n' "$url" >&2; exit 65 ;;
esac
EOF_CURL
chmod +x "$work/bin/curl"

cat > "$work/bin/npm" <<'EOF_NPM'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "${NPM_CALLS:?}"
exit 0
EOF_NPM
chmod +x "$work/bin/npm"
: > "$work/npm-calls"

export PATH="$work/bin:$PATH"
export FIXTURE_ROOT="$work"
export NPM_CALLS="$work/npm-calls"

run_setup() {
  local uid="$1" gid="$2" user="$3" log_dir="$4"
  env UID="$uid" GID="$gid" PATH="$PATH" FIXTURE_ROOT="$FIXTURE_ROOT" NPM_CALLS="$NPM_CALLS" \
    SCRIPTOMATIC_REF=main TOOLSET_REF=2.0 \
    LINUX_PKG='' LINUX_PKG_VERSIONED='' NODE_GLOBAL='' NODE_GLOBAL_VERSIONED='' NODE_LOG_DIR="$log_dir" \
    bash "$ROOT/bash/node-cli-setup.sh" "$user" 24
}

run_setup 1000 1000 developer /var/log/node-developer

assert_eq 1000 "$(id -u developer)" "reused developer UID"
assert_eq 1000 "$(id -g developer)" "reused developer GID"
assert_eq /home/developer "$(getent passwd developer | cut -d: -f6)" "reused developer home"
assert_eq /bin/bash "$(getent passwd developer | cut -d: -f7)" "reused developer shell"
assert_file /etc/sudoers.d/developer
assert_contains "$(cat /etc/sudoers.d/developer)" 'NOPASSWD:ALL' "passwordless sudo remains enabled"
assert_file /home/developer/.oh-my-bash
assert_contains "$(cat /home/developer/.bashrc)" 'OSH_THEME="lambda"' "Oh My Bash theme remains lambda"
assert_contains "$(cat "$work/npm-calls")" 'install -g npm@latest' "npm latest update remains attempted"
pass "upstream UID 1000 reuse and developer defaults are preserved"

for helper in gitx chromacat show-banner docknotify node-entry alias-maker; do
  assert_file "/usr/local/bin/$helper"
  assert_eq 'root:root' "$(stat -c '%U:%G' "/usr/local/bin/$helper")" "$helper ownership"
  assert_eq 755 "$(stat -c '%a' "/usr/local/bin/$helper")" "$helper mode"
done
assert_contains "$(/usr/local/bin/gitx)" 'TOOLSET-FAKE-2.0' "Toolset 2.0 fixture installed"
assert_eq "$(sha256sum "$ROOT/bash/node-entry.sh" | awk '{print $1}')" "$(sha256sum /usr/local/bin/node-entry | awk '{print $1}')" "same-ref Scriptomatic node entry"
pass "helper acquisition is hardened without changing Node bootstrap behavior"

assert_contains "$(cat /home/developer/.bashrc)" 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"' "npm prefix persisted"
assert_eq 'developer:developer' "$(stat -c '%U:%G' /home/developer/.npm-global)" "npm global prefix ownership"
pass "non-root npm prefix/cache ownership"

run_setup 1000 1000 developer /var/log/node-developer
assert_eq 1 "$(grep -c 'show-banner \"Node 24\"' /home/developer/.bashrc)" "banner snippet duplication"
pass "Node reused-user setup is repeatable"

run_setup 12002 12002 freshdev /var/log/node-fresh
assert_eq 12002 "$(id -u freshdev)" "fresh user UID"
assert_eq 12002 "$(id -g freshdev)" "fresh user GID"
assert_eq /home/freshdev "$(getent passwd freshdev | cut -d: -f6)" "fresh user home"
assert_eq /bin/bash "$(getent passwd freshdev | cut -d: -f7)" "fresh user shell"
assert_file /etc/sudoers.d/freshdev
pass "fresh-user path preserves the historical UID/GID interface"
