#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

[[ "$(id -u)" == 0 ]] || fail "node-bootstrap fixture must run as root inside a disposable Node image"
command -v node >/dev/null 2>&1 || fail "node fixture missing node"
command -v npm >/dev/null 2>&1 || fail "node fixture missing npm"
[[ -f /etc/alpine-release ]] || fail "node bootstrap integration expects Alpine fixture"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/scriptomatic/main/bash" "$work/toolset/2.0"

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

initial_npm="$(npm --version)"
export SCRIPTOMATIC_UID=1000
export SCRIPTOMATIC_GID=1000
export SCRIPTOMATIC_REF=main
export SCRIPTOMATIC_BASE_URL="file://$work/scriptomatic"
export TOOLSET_REF=2.0
export TOOLSET_RELEASE_BASE_URL="file://$work/toolset"
export SCRIPTOMATIC_PASSWORDLESS_SUDO=0
export SCRIPTOMATIC_OH_MY_BASH=0
export SCRIPTOMATIC_REPRODUCIBLE=1
export LINUX_PKG=''
export LINUX_PKG_VERSIONED=''
export NODE_GLOBAL=''
export NODE_GLOBAL_VERSIONED=''
export NPM_VERSION=''
export NODE_LOG_DIR=/var/log/node-developer

bash "$ROOT/bash/node-cli-setup.sh" developer 24

assert_eq 1000 "$(id -u developer)" "reused developer UID"
assert_eq 1000 "$(id -g developer)" "reused developer GID"
assert_eq /home/developer "$(getent passwd developer | cut -d: -f6)" "reused developer home"
assert_eq /bin/bash "$(getent passwd developer | cut -d: -f7)" "reused developer shell"
assert_not_file /etc/sudoers.d/developer
pass "upstream UID 1000 reuse/rename path is verified"

for helper in gitx chromacat show-banner docknotify node-entry alias-maker; do
  assert_file "/usr/local/bin/$helper"
  assert_eq 'root:root' "$(stat -c '%U:%G' "/usr/local/bin/$helper")" "$helper ownership"
  assert_eq 755 "$(stat -c '%a' "/usr/local/bin/$helper")" "$helper mode"
done
assert_contains "$(/usr/local/bin/gitx)" 'TOOLSET-FAKE-2.0' "exact Toolset fixture installed"
assert_eq "$(sha256sum "$ROOT/bash/node-entry.sh" | awk '{print $1}')" "$(sha256sum /usr/local/bin/node-entry | awk '{print $1}')" "same-ref Scriptomatic node entry"
assert_eq "$initial_npm" "$(npm --version)" "npm remains upstream version when NPM_VERSION unset"
pass "immutable helper and npm-preservation contracts"

assert_contains "$(cat /home/developer/.bashrc)" 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"' "npm prefix persisted"
assert_eq 'developer:developer' "$(stat -c '%U:%G' /home/developer/.npm-global)" "npm global prefix ownership"
pass "non-root npm prefix/cache ownership"

bash "$ROOT/bash/node-cli-setup.sh" developer 24
assert_eq 1 "$(grep -c 'show-banner \"Node 24\"' /home/developer/.bashrc)" "banner snippet duplication"
pass "Node reused-user setup is repeatable"

export SCRIPTOMATIC_UID=12002
export SCRIPTOMATIC_GID=12002
export NODE_LOG_DIR=/var/log/node-fresh
bash "$ROOT/bash/node-cli-setup.sh" freshdev 24
assert_eq 12002 "$(id -u freshdev)" "fresh user UID"
assert_eq 12002 "$(id -g freshdev)" "fresh user GID"
assert_eq /home/freshdev "$(getent passwd freshdev | cut -d: -f6)" "fresh user home"
assert_eq /bin/bash "$(getent passwd freshdev | cut -d: -f7)" "fresh user shell"
pass "fresh-user path is verified"
