#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/app"

output="$(APP_DIR="$tmp/app" NODE_LOG_ENABLED=0 ROOTCA_PATH="$tmp/missing.pem" \
  "$ROOT/bash/node-entry.sh" sh -c 'printf "%s" "$1"' sh 'forwarded value')"
assert_eq 'forwarded value' "$output" 'node-entry direct command forwarding changed'

set +e
APP_DIR="$tmp/app" NODE_LOG_ENABLED=0 ROOTCA_PATH="$tmp/missing.pem" \
  "$ROOT/bash/node-entry.sh" sh -c 'exit 7'
status=$?
set -e
assert_eq 7 "$status" 'node-entry direct command exit status changed'

log_dir="$tmp/logs"
APP_DIR="$tmp/app" NODE_LOG_ENABLED=1 NODE_LOG_DIR="$log_dir" ROOTCA_PATH="$tmp/missing.pem" \
  "$ROOT/bash/node-entry.sh" sh -c 'printf out; printf err >&2'
assert_contains "$log_dir/access.log" 'out'
assert_contains "$log_dir/error.log" 'err'

mkdir -p "$tmp/fakebin" "$tmp/generic/node_modules"
printf '{"scripts":{"dev":"fake-dev"}}\n' >"$tmp/generic/package.json"
cat >"$tmp/fakebin/node" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"scripts&&"*) exit 0 ;;
  *) printf 'generic\n' ;;
esac
EOF
cat >"$tmp/fakebin/npm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NODE_TEST_CALLS"
if [[ "$*" == *"--host"* && "${NODE_TEST_HOST_FAIL:-0}" == 1 ]]; then
  exit 9
fi
exit 0
EOF
chmod +x "$tmp/fakebin/node" "$tmp/fakebin/npm"

calls="$tmp/calls"
PATH="$tmp/fakebin:$PATH" NODE_TEST_CALLS="$calls" APP_DIR="$tmp/generic" NODE_LOG_ENABLED=0 \
  ROOTCA_PATH="$tmp/missing.pem" NODE_KEEPALIVE_ON_FAIL=0 "$ROOT/bash/node-entry.sh"
assert_eq 1 "$(wc -l <"$calls" | tr -d ' ')" 'generic dev command ran more than once after success'

: >"$calls"
PATH="$tmp/fakebin:$PATH" NODE_TEST_CALLS="$calls" NODE_TEST_HOST_FAIL=1 APP_DIR="$tmp/generic" NODE_LOG_ENABLED=0 \
  ROOTCA_PATH="$tmp/missing.pem" NODE_KEEPALIVE_ON_FAIL=0 "$ROOT/bash/node-entry.sh"
assert_eq 2 "$(wc -l <"$calls" | tr -d ' ')" 'generic dev fallback order changed'

signal_marker="$tmp/signal"
APP_DIR="$tmp/app" NODE_LOG_ENABLED=0 ROOTCA_PATH="$tmp/missing.pem" \
  "$ROOT/bash/node-entry.sh" sh -c 'trap "printf term >\"$1\"; exit 0" TERM; while :; do sleep 1; done' sh "$signal_marker" &
pid=$!
sleep 0.2
kill -TERM "$pid"
wait "$pid"
assert_contains "$signal_marker" 'term'

set +e
APP_DIR="$tmp/app" NODE_LOG_ENABLED=0 NODE_KEEPALIVE_ON_FAIL=0 ROOTCA_PATH="$tmp/missing.pem" \
  "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
status=$?
set -e
assert_eq 1 "$status" 'no-runnable-app exit status changed when keepalive disabled'

pass 'node entrypoint regression and signal contract'
