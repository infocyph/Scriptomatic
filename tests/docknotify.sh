#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'jobs -p | xargs -r kill 2>/dev/null || true; rm -rf -- "$work"' EXIT

start_listener() {
  local port_file="$1" payload_file="$2"
  python3 - "$port_file" "$payload_file" <<'PY' &
import socket, sys
port_file, payload_file = sys.argv[1:]
s = socket.socket()
s.bind(('127.0.0.1', 0))
s.listen(1)
with open(port_file, 'w') as f:
    f.write(str(s.getsockname()[1]))
conn, _ = s.accept()
data = b''
while True:
    chunk = conn.recv(4096)
    if not chunk:
        break
    data += chunk
conn.close(); s.close()
with open(payload_file, 'wb') as f:
    f.write(data)
PY
  listener=$!
  for _ in $(seq 1 50); do [[ -s "$port_file" ]] && break; sleep 0.05; done
  assert_file "$port_file"
}

start_listener "$work/port" "$work/payload"
port="$(cat "$work/port")"
NOTIFY_TOKEN='secret-token' DOCKNOTIFY_STRICT=1 \
  bash "$ROOT/bash/docknotify.sh" -H 127.0.0.1 -p "$port" -s $'source\tname' \
  $'Title\nline' $'Body\tvalue\nnext' ignored-extra-arg
wait "$listener"

python3 - "$work/payload" <<'PY'
import sys
p=open(sys.argv[1],'rb').read()
assert p.endswith(b'\n'), p
parts=p[:-1].split(b'\t')
assert len(parts)==6, parts
assert parts[0]==b'secret-token', parts
assert parts[3]==b'source name', parts
assert parts[4]==b'Title line', parts
assert parts[5]==b'Body value next', parts
PY
pass "docknotify preserves first-two-args behavior and sends one sanitized newline-terminated record"

set +e
NOTIFY_TOKEN=$'secret-token\tbad' bash "$ROOT/bash/docknotify.sh" -H 127.0.0.1 -p "$port" title body 2>"$work/error"
rc=$?
set -e
assert_eq 2 "$rc" "invalid token separator exit"
assert_not_contains "$(cat "$work/error")" 'secret-token' "token must not leak in diagnostics"
pass "protocol-separator token is rejected without secret leakage"

# Historical optional tuning values were permissive: malformed values fall back.
rm -f "$work/port2" "$work/payload2"
start_listener "$work/port2" "$work/payload2"
port2="$(cat "$work/port2")"
NOTIFY_TITLE_MAX=bad NOTIFY_BODY_MAX=bad DOCKNOTIFY_STRICT=bad \
  bash "$ROOT/bash/docknotify.sh" -H 127.0.0.1 -p "$port2" -t nope -u weird title body
wait "$listener"
python3 - "$work/payload2" <<'PY'
import sys
parts=open(sys.argv[1],'rb').read().rstrip(b'\n').split(b'\t')
assert parts[1] == b'2500', parts
assert parts[2] == b'normal', parts
PY
pass "docknotify keeps permissive fallback semantics for optional tuning values"

# Listener is gone, so the first port is now closed.
bash "$ROOT/bash/docknotify.sh" -H 127.0.0.1 -p "$port" title body
pass "unavailable notifier remains best-effort by default"
set +e
DOCKNOTIFY_STRICT=1 bash "$ROOT/bash/docknotify.sh" -H 127.0.0.1 -p "$port" title body >/dev/null 2>&1
rc=$?
set -e
assert_eq 1 "$rc" "strict absent-listener exit"
pass "strict notification mode reports transport failure"
