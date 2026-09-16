#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/fake"
cat >"$tmp/fake/nc" <<'EOF'
#!/usr/bin/env bash
cat >"$DOCKNOTIFY_CAPTURE"
EOF
chmod +x "$tmp/fake/nc"
DOCKNOTIFY_CAPTURE="$tmp/frame" PATH="$tmp/fake:$PATH" NOTIFY_TOKEN=$'tok\ten\n' NOTIFY_SOURCE=$'src\rname' \
  "$ROOT/bash/docknotify.sh" -H localhost -p 9901 -t 2500 -u critical $'ti\tle' $'bo\ndy'
python3 - "$tmp/frame" <<'PY'
from pathlib import Path
import sys
b=Path(sys.argv[1]).read_bytes()
assert b.endswith(b'\n')
assert b.count(b'\n') == 1
assert b == b'tok en \t2500\tcritical\tsrc name\tti le\tbo dy\n'
PY
cat >"$tmp/fake/nc" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
exit 1
EOF
chmod +x "$tmp/fake/nc"
set +e
PATH="$tmp/fake:$PATH" DOCKNOTIFY_STRICT=1 NOTIFY_TOKEN='super-secret-token' \
  "$ROOT/bash/docknotify.sh" -H localhost title body 2>"$tmp/err"
status=$?
set -e
assert_eq 1 "$status" 'strict docknotify send failure must be non-zero'
assert_not_contains "$tmp/err" 'super-secret-token'
PATH="$tmp/fake:$PATH" DOCKNOTIFY_STRICT=0 "$ROOT/bash/docknotify.sh" -H localhost title body >/dev/null 2>&1
pass 'docknotify framing and strict-mode contract'
