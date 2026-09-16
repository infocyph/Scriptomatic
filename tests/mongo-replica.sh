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
  printf '%s\n' "$script" >"$MONGO_INIT_SCRIPT"
  exit 0
fi
exit 3
EOF
chmod +x "$tmp/fake/mongosh"

MONGO_INIT_LOG="$tmp/init.log" MONGO_INIT_SCRIPT="$tmp/init.js" MONGO_TEST_STATE=UNINITIALIZED \
  MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" "$ROOT/bash/mongo-replica.sh" >/dev/null
assert_eq 1 "$(wc -l <"$tmp/init.log" | tr -d ' ')" 'uninitialized replica set was not initiated exactly once'
assert_contains "$tmp/init.js" '_id: "rs0"'
assert_contains "$tmp/init.js" 'mongo-primary:27017'

rm -f "$tmp/init.log" "$tmp/init.js"
MONGO_INIT_LOG="$tmp/init.log" MONGO_INIT_SCRIPT="$tmp/init.js" MONGO_TEST_STATE=MATCH \
  MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" "$ROOT/bash/mongo-replica.sh" >/dev/null
[[ ! -e "$tmp/init.log" ]] || fail 'matching replica set was reinitialized'

set +e
MONGO_INIT_LOG="$tmp/init.log" MONGO_INIT_SCRIPT="$tmp/init.js" MONGO_TEST_STATE=CONFLICT \
  MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" "$ROOT/bash/mongo-replica.sh" >/dev/null 2>&1
status=$?
set -e
assert_eq 1 "$status" 'conflicting replica topology must fail'

rm -f "$tmp/init.log" "$tmp/init.js"
set +e
MONGO_INIT_LOG="$tmp/init.log" MONGO_INIT_SCRIPT="$tmp/init.js" MONGO_TEST_STATE='ERROR:Unauthorized' \
  MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$tmp/error-state.err"
status=$?
set -e
assert_eq 1 "$status" 'non-initialization Mongo errors must fail instead of initiating'
[[ ! -e "$tmp/init.log" ]] || fail 'Mongo error path attempted replica initialization'
assert_contains "$tmp/error-state.err" 'Unauthorized'

set +e
MONGO_REPLICA_SET_NAME='bad";quit(0);//' MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" \
  "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$tmp/bad-name.err"
status=$?
set -e
assert_eq 2 "$status" 'unsafe replica-set name must be rejected before Mongo evaluation'
assert_contains "$tmp/bad-name.err" 'invalid MONGO_REPLICA_SET_NAME'

set +e
MONGO_PRIMARY_HOST='mongo-primary:27017";quit(0);//' MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" \
  "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$tmp/bad-host.err"
status=$?
set -e
assert_eq 2 "$status" 'unsafe Mongo member host must be rejected before Mongo evaluation'
assert_contains "$tmp/bad-host.err" 'invalid MONGO_PRIMARY_HOST'

rm -f "$tmp/init.log" "$tmp/init.js"
MONGO_INIT_LOG="$tmp/init.log" MONGO_INIT_SCRIPT="$tmp/init.js" MONGO_TEST_STATE=UNINITIALIZED \
  MONGO_REPLICA_SET_NAME='dev_rs' MONGO_PRIMARY_HOST='db-primary:27018' \
  MONGO_SECONDARY1_HOST='db-secondary-1:27018' MONGO_SECONDARY2_HOST='db-secondary-2:27018' \
  MONGO_READY_DELAY=0 PATH="$tmp/fake:$PATH" "$ROOT/bash/mongo-replica.sh" >/dev/null
assert_contains "$tmp/init.js" '_id: "dev_rs"'
assert_contains "$tmp/init.js" 'db-primary:27018'

pass 'Mongo replica readiness, topology, and override contracts'
