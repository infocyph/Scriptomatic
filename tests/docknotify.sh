#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'jobs -p | xargs -r kill 2>/dev/null || true; rm -rf -- "$work"' EXIT

python3 - "$work/port" "$work/payload" <<'PY' &
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
for _ in $(seq 1 50); do [[ -s "$work/port" ]] && break; sleep 0.05; done
assert_file "$work/port"
port="$(cat "$work/port")"

NOTIFY_TOKEN='secret-token' DOCKNOTIFY_STRICT=1 \
  bash "$ROOT/bash/docknotify.sh" -H 127.0.0.1 -p "$port" -s $'source\tname' \
  $'Title\nline' $'Body\tvalue\nnext'
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
pass "docknotify sends one sanitized six-field newline-terminated record"

set +e
NOTIFY_TOKEN=$'secret-token\tbad' bash "$ROOT/bash/docknotify.sh" -H 127.0.0.1 -p "$port" title body 2>"$work/error"
rc=$?
set -e
assert_eq 2 "$rc" "invalid token separator exit"
assert_not_contains "$(cat "$work/error")" 'secret-token' "token must not leak in diagnostics"
pass "protocol-separator token is rejected without secret leakage"

# Listener is gone, so the same port is now closed.
bash "$ROOT/bash/docknotify.sh" -H 127.0.0.1 -p "$port" title body
pass "unavailable notifier remains best-effort by default"
set +e
DOCKNOTIFY_STRICT=1 bash "$ROOT/bash/docknotify.sh" -H 127.0.0.1 -p "$port" title body >/dev/null 2>&1
rc=$?
set -e
assert_eq 1 "$rc" "strict absent-listener exit"
pass "strict notification mode reports transport failure"
