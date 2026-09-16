#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/fake"
cat >"$tmp/fake/mongosh" <<'EOF'
#!/usr/bin/env bash
script="${@: -1}"
if [[ "$script" == *'adminCommand({ping:1})'* ]]; then
  exit 0
fi
if [[ "$script" == *'const cfg = rs.conf()'* ]]; then
  printf '%s\n' "${MONGO_TEST_STATE:-UNINITIALIZED}"
  exit 0
fi
if [[ "$script" == *'rs.initiate('* ]]; then
  printf 'init\n' >>"$MONGO_INIT_LOG"
  exit 0
fi
exit 3
EOF
chmod +x "$tmp/fake/mongosh"

MONGO_INIT_LOG="$tmp/init.log" MONGO_TEST_STATE=UNINITIALIZED MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" "$ROOT/bash/mongo-replica.sh" >/dev/null
assert_eq 1 "$(wc -l <"$tmp/init.log" | tr -d ' ')" 'uninitialized replica set was not initiated exactly once'
rm -f "$tmp/init.log"
MONGO_INIT_LOG="$tmp/init.log" MONGO_TEST_STATE=MATCH MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" "$ROOT/bash/mongo-replica.sh" >/dev/null
[[ ! -e "$tmp/init.log" ]] || fail 'matching replica set was reinitialized'
set +e
MONGO_INIT_LOG="$tmp/init.log" MONGO_TEST_STATE=CONFLICT MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" "$ROOT/bash/mongo-replica.sh" >/dev/null 2>&1
status=$?
set -e
assert_eq 1 "$status" 'conflicting replica topology must fail'
pass 'Mongo replica readiness and topology contracts'
