#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"

cat >"$work/bin/mongosh" <<'EOF_MONGOSH'
#!/usr/bin/env bash
set -euo pipefail
script=''
while (($#)); do
  if [[ "$1" == --eval ]]; then
    shift
    script="${1:-}"
    break
  fi
  shift
done
printf 'mongosh\t%s\n' "$script" >>"${MOCK_MONGO_CALLS:?}"

if [[ "$script" == *'adminCommand({ping:1})'* ]]; then
  exit "${MOCK_MONGO_PING_RC:-0}"
fi
if [[ "$script" == *'rs.initiate('* ]]; then
  printf 'matching\n' >"${MOCK_MONGO_STATE:?}"
  printf 'initiate\n' >>"${MOCK_MONGO_EVENTS:?}"
  exit "${MOCK_MONGO_INIT_RC:-0}"
fi
if [[ "$script" == *'rs.conf()'* ]]; then
  state="$(cat "${MOCK_MONGO_STATE:?}" 2>/dev/null || printf uninitialized)"
  case "$state" in
    matching) exit 0 ;;
    uninitialized) exit 3 ;;
    conflict) exit 42 ;;
    error) printf 'mock topology error\n' >&2; exit 43 ;;
  esac
fi
printf 'unexpected mongo eval\n' >&2
exit 64
EOF_MONGOSH
chmod +x "$work/bin/mongosh"

export PATH="$work/bin:$PATH"
export MOCK_MONGO_STATE="$work/state"
export MOCK_MONGO_CALLS="$work/calls"
export MOCK_MONGO_EVENTS="$work/events"
: >"$work/calls"
: >"$work/events"

printf 'uninitialized\n' >"$work/state"
MONGO_READY_INTERVAL_SECONDS=1 MONGO_READY_TIMEOUT_SECONDS=2 MONGO_INIT_TIMEOUT_SECONDS=2 \
  bash "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$work/init.err"
assert_contains "initiate" "$(cat "$work/events")" "uninitialized replica set must be initiated"
assert_eq matching "$(cat "$work/state")" "replica state after initialization"
assert_contains "mongosh" "$(head -n1 "$work/calls")" "mongosh preferred when available"
pass "mongo replica initializes an uninitialized Docker-DNS topology"

: >"$work/events"
printf 'matching\n' >"$work/state"
MONGO_READY_INTERVAL_SECONDS=1 MONGO_READY_TIMEOUT_SECONDS=2 MONGO_INIT_TIMEOUT_SECONDS=2 \
  bash "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$work/matching.err"
assert_eq 0 "$(wc -l <"$work/events" | tr -d ' ')" "matching topology must not be re-initiated"
assert_contains "already matches" "$(cat "$work/matching.err")" "idempotent topology diagnostic"
pass "mongo replica is idempotent when topology already matches"

printf 'conflict\n' >"$work/state"
set +e
MONGO_READY_INTERVAL_SECONDS=1 MONGO_READY_TIMEOUT_SECONDS=2 MONGO_INIT_TIMEOUT_SECONDS=2 \
  bash "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$work/conflict.err"
rc=$?
set -e
[[ $rc -ne 0 ]] || fail "conflicting replica topology must fail"
assert_contains "conflicts" "$(cat "$work/conflict.err")" "conflicting topology diagnostic"
pass "mongo replica refuses conflicting existing topology"

set +e
MONGO_MEMBERS='mongo-primary:27017,bad member:27017' \
  bash "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$work/invalid.err"
rc=$?
set -e
[[ $rc -ne 0 ]] || fail "invalid member endpoint must fail"
pass "mongo replica validates Docker-DNS member endpoints before mutation"

cat >"$work/bin/mongo" <<'EOF_MONGO'
#!/usr/bin/env bash
exec "$(dirname "$0")/mongosh" "$@"
EOF_MONGO
chmod +x "$work/bin/mongo"
printf 'matching\n' >"$work/state"
MONGO_SHELL=mongo MONGO_READY_INTERVAL_SECONDS=1 MONGO_READY_TIMEOUT_SECONDS=2 MONGO_INIT_TIMEOUT_SECONDS=2 \
  bash "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$work/legacy.err"
pass "mongo replica retains explicit legacy mongo-shell compatibility"
