#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/app" "$work/bin" "$work/app/node_modules"

source_text="$(cat "$ROOT/bash/node-entry.sh")"
for expected in 'NODE_LOG_ENABLED:=1' 'NODE_KEEPALIVE_ON_FAIL:=1' 'NODE_LOG_DIR:=/var/log/node-app'; do
  assert_contains "$source_text" "$expected" "historical Node entrypoint default"
done
for removed in NODE_AUTO_INSTALL NODE_ALLOW_LOCKFILE_FALLBACK ROOTCA_REQUIRED; do
  assert_not_contains "$source_text" "$removed" "unsolicited Node entrypoint knob: $removed"
done
assert_not_contains "$source_text" '.rootca_installed' "stale CA stamp must stay removed"
assert_contains "$source_text" 'NODE_EXTRA_CA_CERTS="$ROOTCA"' "mounted CA remains trusted by Node"
pass "Node entrypoint public contract remains aligned with main"

set +e
APP_DIR="$work/app" ROOTCA_PATH="$work/missing.pem" NODE_LOG_ENABLED=0 \
  sh "$ROOT/bash/node-entry.sh" sh -c 'exit 17'
rc=$?
set -e
assert_eq 17 "$rc" "node-entry direct command exit propagation"
pass "direct command forwarding preserves exit semantics"

rm -rf "$work/app/node_modules"
cat > "$work/bin/npm" <<'EOF_NPM'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "${NPM_CALLS:?}"
case " $* " in
  *' ci '*) exit 9 ;;
  *) exit 0 ;;
esac
EOF_NPM
chmod +x "$work/bin/npm"
cat > "$work/app/package.json" <<'EOF_PACKAGE'
{"name":"fixture","scripts":{}}
EOF_PACKAGE
: > "$work/app/package-lock.json"
: > "$work/npm-calls"

set +e
PATH="$work/bin:$PATH" NPM_CALLS="$work/npm-calls" APP_DIR="$work/app" ROOTCA_PATH="$work/missing.pem" \
  NODE_LOG_ENABLED=0 NODE_KEEPALIVE_ON_FAIL=0 \
  sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 1 "$rc" "fixture remains unrunnable after dependency fallback"
assert_eq 2 "$(wc -l < "$work/npm-calls" | tr -d ' ')" "historical npm fallback call count"
assert_contains "$(cat "$work/npm-calls")" 'ci' "npm ci call"
assert_contains "$(cat "$work/npm-calls")" 'install' "npm install fallback"
pass "automatic dependency install and lockfile fallback remain unchanged"

mkdir -p "$work/app/node_modules"
cat > "$work/app/package.json" <<'EOF_DEV'
{"name":"fixture","scripts":{"dev":"fixture-dev"}}
EOF_DEV
: > "$work/npm-calls"
set +e
PATH="$work/bin:$PATH" NPM_CALLS="$work/npm-calls" APP_DIR="$work/app" ROOTCA_PATH="$work/missing.pem" \
  NODE_LOG_ENABLED=0 NODE_KEEPALIVE_ON_FAIL=0 \
  sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 0 "$rc" "mock dev command exit"
assert_eq 1 "$(wc -l < "$work/npm-calls" | tr -d ' ')" "successful generic dev command must not run twice"
assert_contains "$(cat "$work/npm-calls")" 'run dev -- --host' "generic dev compatibility form"
pass "generic dev double-execution bug is fixed without changing command choice"

APP_DIR="$work/app" ROOTCA_PATH="$work/missing.pem" NODE_LOG_ENABLED=0 \
HOST=127.0.0.1 PORT=4321 \
NODE_CMD='test "$HOSTNAME" = 127.0.0.1 && test "$NUXT_HOST" = 127.0.0.1 && test "$NUXT_PORT" = 4321' \
  sh "$ROOT/bash/node-entry.sh"
pass "NODE_CMD retains HOSTNAME/NUXT environment compatibility"
