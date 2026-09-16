#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

source_text="$(cat "$ROOT/bash/mongo-replica.sh")"
for removed in MONGO_RS_NAME MONGO_MEMBERS MONGO_READY_TIMEOUT_SECONDS MONGO_INIT_TIMEOUT_SECONDS; do
  # Internal constants for readiness are allowed, but none may be environment defaults.
  assert_not_contains "$source_text" '${'"$removed"':-' "Mongo configuration knob must not be introduced: $removed"
done
assert_contains "$source_text" '_id:"rs0"' "historical replica-set name"
assert_contains "$source_text" 'mongo-primary:27017' "historical primary member"
assert_contains "$source_text" 'mongo-secondary1:27017' "historical secondary1 member"
assert_contains "$source_text" 'mongo-secondary2:27017' "historical secondary2 member"
assert_not_contains "$source_text" 'sleep 10' "fixed startup sleep must stay removed"
pass "Mongo public topology remains exactly aligned with main"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"

cat > "$work/bin/mongosh" <<'EOF_MONGOSH'
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
printf '%s\n' "$script" >> "${MOCK_MONGO_CALLS:?}"

if [[ "$script" == *'adminCommand({ping:1})'* ]]; then
  exit 0
fi
if [[ "$script" == *'rs.initiate('* ]]; then
  printf 'matching\n' > "${MOCK_MONGO_STATE:?}"
  printf 'initiate\n' >> "${MOCK_MONGO_EVENTS:?}"
  exit 0
fi
if [[ "$script" == *'rs.conf()'* ]]; then
  state="$(cat "${MOCK_MONGO_STATE:?}" 2>/dev/null || printf uninitialized)"
  case "$state" in
    matching) exit 0 ;;
    uninitialized) exit 3 ;;
    conflict) exit 42 ;;
  esac
fi
exit 64
EOF_MONGOSH
chmod +x "$work/bin/mongosh"

export PATH="$work/bin:$PATH"
export MOCK_MONGO_STATE="$work/state"
export MOCK_MONGO_CALLS="$work/calls"
export MOCK_MONGO_EVENTS="$work/events"
: > "$work/calls"
: > "$work/events"

printf 'uninitialized\n' > "$work/state"
bash "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$work/init.err"
assert_contains "$(cat "$work/events")" 'initiate' "uninitialized replica set must be initiated"
assert_eq matching "$(cat "$work/state")" "replica state after initialization"
pass "Mongo bootstrap replaces fixed sleep with readiness and initialization checks"

: > "$work/events"
printf 'matching\n' > "$work/state"
bash "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$work/matching.err"
assert_eq 0 "$(wc -l < "$work/events" | tr -d ' ')" "matching topology must not be re-initiated"
assert_contains "$(cat "$work/matching.err")" 'already initialized' "idempotent topology diagnostic"
pass "Mongo bootstrap is idempotent for the existing rs0 topology"

printf 'conflict\n' > "$work/state"
set +e
bash "$ROOT/bash/mongo-replica.sh" >/dev/null 2>"$work/conflict.err"
rc=$?
set -e
[[ $rc -ne 0 ]] || fail "conflicting existing topology must fail"
assert_contains "$(cat "$work/conflict.err")" 'conflicts' "conflict diagnostic"
pass "Mongo bootstrap refuses to overwrite a conflicting topology"
