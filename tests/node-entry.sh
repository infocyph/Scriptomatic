#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/app" "$work/bin" "$work/ca"

source_text="$(cat "$ROOT/bash/node-entry.sh")"
for expected in 'NODE_LOG_ENABLED:=1' 'NODE_KEEPALIVE_ON_FAIL:=1' 'NODE_AUTO_INSTALL:=1' 'NODE_ALLOW_LOCKFILE_FALLBACK:=1'; do
  assert_contains "$source_text" "$expected" "Node compatibility default"
done
pass "Node entrypoint compatibility defaults are preserved"

set +e
APP_DIR="$work/app" NODE_LOG_ENABLED=0 sh "$ROOT/bash/node-entry.sh" sh -c 'exit 17'
rc=$?
set -e
assert_eq 17 "$rc" "node-entry direct command exit propagation"
pass "direct command forwarding preserves exit semantics"

set +e
APP_DIR="$work/app" NODE_LOG_ENABLED=0 NODE_AUTO_INSTALL=0 NODE_KEEPALIVE_ON_FAIL=0 \
  sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 1 "$rc" "strict no-app opt-out should fail"
pass "keepalive can be explicitly disabled for strict images"

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

# Historical default: auto-install and fallback remain on.
set +e
PATH="$work/bin:$PATH" NPM_CALLS="$work/npm-calls" APP_DIR="$work/app" \
  NODE_LOG_ENABLED=0 NODE_KEEPALIVE_ON_FAIL=0 \
  sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 1 "$rc" "fixture remains unrunnable after dependency fallback"
assert_eq 2 "$(wc -l < "$work/npm-calls" | tr -d ' ')" "default fallback call count"
assert_contains "$(cat "$work/npm-calls")" 'ci' "default npm ci call"
assert_contains "$(cat "$work/npm-calls")" 'install' "default npm install fallback"
pass "automatic dependency install and lockfile fallback remain enabled by default"

: > "$work/npm-calls"
set +e
PATH="$work/bin:$PATH" NPM_CALLS="$work/npm-calls" APP_DIR="$work/app" \
  NODE_LOG_ENABLED=0 NODE_KEEPALIVE_ON_FAIL=0 NODE_ALLOW_LOCKFILE_FALLBACK=0 \
  sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 1 "$rc" "strict fallback opt-out remains unrunnable"
assert_eq 1 "$(wc -l < "$work/npm-calls" | tr -d ' ')" "strict install call count"
assert_contains "$(cat "$work/npm-calls")" 'ci' "strict npm ci call"
assert_not_contains "$(cat "$work/npm-calls")" 'install' "strict mode must not use mutable fallback"
pass "lockfile fallback can be explicitly disabled"

# Ensure the generic dev compatibility probe does not execute a successful dev command twice.
cat > "$work/app/package.json" <<'EOF_DEV'
{"name":"fixture","scripts":{"dev":"fixture-dev"}}
EOF_DEV
rm -f "$work/app/package-lock.json"
: > "$work/npm-calls"
set +e
PATH="$work/bin:$PATH" NPM_CALLS="$work/npm-calls" APP_DIR="$work/app" \
  NODE_LOG_ENABLED=0 NODE_AUTO_INSTALL=0 NODE_KEEPALIVE_ON_FAIL=0 \
  sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 0 "$rc" "mock dev command exit"
assert_eq 1 "$(wc -l < "$work/npm-calls" | tr -d ' ')" "successful dev command must run once"
assert_contains "$(cat "$work/npm-calls")" 'run dev -- --host' "generic dev compatibility form"
pass "generic dev keeps original host/port attempt without duplicate execution"

# NODE_CMD retains the original framework-oriented environment injection.
APP_DIR="$work/app" NODE_LOG_ENABLED=0 NODE_AUTO_INSTALL=0 \
HOST=127.0.0.1 PORT=4321 \
NODE_CMD='test "$HOSTNAME" = 127.0.0.1 && test "$NUXT_HOST" = 127.0.0.1 && test "$NUXT_PORT" = 4321' \
  sh "$ROOT/bash/node-entry.sh"
pass "NODE_CMD retains HOSTNAME/NUXT environment compatibility"

# Content-aware root CA handling using a fake sudo/update-ca-certificates boundary.
cat > "$work/bin/sudo" <<'EOF_SUDO'
#!/usr/bin/env sh
[ "${1:-}" = '--' ] && shift
exec "$@"
EOF_SUDO
cat > "$work/bin/update-ca-certificates" <<'EOF_CA'
#!/usr/bin/env sh
printf 'updated\n' >> "${CA_UPDATE_LOG:?}"
EOF_CA
chmod +x "$work/bin/sudo" "$work/bin/update-ca-certificates"
printf 'ca-v1\n' > "$work/source.pem"
: > "$work/updates"

PATH="$work/bin:$PATH" APP_DIR="$work/app" NODE_LOG_ENABLED=0 NODE_AUTO_INSTALL=0 \
ROOTCA_PATH="$work/source.pem" ROOTCA_DEST="$work/ca/rootCA.crt" \
ROOTCA_REQUIRED=1 CA_UPDATE_LOG="$work/updates" sh "$ROOT/bash/node-entry.sh" true
assert_eq 1 "$(wc -l < "$work/updates" | tr -d ' ')" "initial CA refresh"
PATH="$work/bin:$PATH" APP_DIR="$work/app" NODE_LOG_ENABLED=0 NODE_AUTO_INSTALL=0 \
ROOTCA_PATH="$work/source.pem" ROOTCA_DEST="$work/ca/rootCA.crt" \
ROOTCA_REQUIRED=1 CA_UPDATE_LOG="$work/updates" sh "$ROOT/bash/node-entry.sh" true
assert_eq 1 "$(wc -l < "$work/updates" | tr -d ' ')" "unchanged CA refresh"
printf 'ca-v2\n' > "$work/source.pem"
PATH="$work/bin:$PATH" APP_DIR="$work/app" NODE_LOG_ENABLED=0 NODE_AUTO_INSTALL=0 \
ROOTCA_PATH="$work/source.pem" ROOTCA_DEST="$work/ca/rootCA.crt" \
ROOTCA_REQUIRED=1 CA_UPDATE_LOG="$work/updates" sh "$ROOT/bash/node-entry.sh" true
assert_eq 2 "$(wc -l < "$work/updates" | tr -d ' ')" "changed CA refresh"
pass "Node root CA bootstrap is content-aware without removing mounted-CA trust"
