#!/usr/bin/env bash
set -euo pipefail

REPLICA_SET_NAME="${MONGO_REPLICA_SET_NAME:-rs0}"
MONGO_PRIMARY="${MONGO_PRIMARY_HOST:-mongo-primary:27017}"
MONGO_SECONDARY1="${MONGO_SECONDARY1_HOST:-mongo-secondary1:27017}"
MONGO_SECONDARY2="${MONGO_SECONDARY2_HOST:-mongo-secondary2:27017}"
MONGO_READY_ATTEMPTS="${MONGO_READY_ATTEMPTS:-30}"
MONGO_READY_DELAY="${MONGO_READY_DELAY:-2}"

fail_input() {
  echo "mongo-replica: $1" >&2
  exit 2
}

[[ "$REPLICA_SET_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || \
  fail_input 'invalid MONGO_REPLICA_SET_NAME'

validate_member() {
  local value="$1" label="$2" host port

  if [[ "$value" =~ ^\[([0-9A-Fa-f:]+)\]:([0-9]{1,5})$ ]]; then
    host="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[2]}"
    [[ -n "$host" ]] || fail_input "invalid ${label}"
  elif [[ "$value" =~ ^([A-Za-z0-9._-]+):([0-9]{1,5})$ ]]; then
    host="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[2]}"
  else
    fail_input "invalid ${label}"
  fi

  (( port >= 1 && port <= 65535 )) || fail_input "invalid ${label} port"
}

validate_member "$MONGO_PRIMARY" MONGO_PRIMARY_HOST
validate_member "$MONGO_SECONDARY1" MONGO_SECONDARY1_HOST
validate_member "$MONGO_SECONDARY2" MONGO_SECONDARY2_HOST

[[ "$MONGO_READY_ATTEMPTS" =~ ^[0-9]+$ && "$MONGO_READY_ATTEMPTS" -ge 1 ]] || \
  fail_input 'invalid MONGO_READY_ATTEMPTS'
[[ "$MONGO_READY_DELAY" =~ ^[0-9]+([.][0-9]+)?$ ]] || \
  fail_input 'invalid MONGO_READY_DELAY'

if command -v mongosh >/dev/null 2>&1; then
  MONGO_SHELL=(mongosh --quiet)
elif command -v mongo >/dev/null 2>&1; then
  MONGO_SHELL=(mongo --quiet)
else
  echo "mongo-replica: neither mongosh nor mongo is installed" >&2
  exit 127
fi

mongo_eval() {
  "${MONGO_SHELL[@]}" --eval "$1"
}

ready=0
for ((attempt = 1; attempt <= MONGO_READY_ATTEMPTS; attempt++)); do
  if mongo_eval 'const r=db.adminCommand({ping:1}); if (!r.ok) quit(1);' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep "$MONGO_READY_DELAY"
done

[[ "$ready" -eq 1 ]] || {
  echo "mongo-replica: MongoDB did not become ready after ${MONGO_READY_ATTEMPTS} attempts" >&2
  exit 1
}

state="$(mongo_eval "
try {
  const cfg = rs.conf();
  const expected = [\"$MONGO_PRIMARY\",\"$MONGO_SECONDARY1\",\"$MONGO_SECONDARY2\"];
  const actual = (cfg.members || []).slice().sort((a,b) => a._id-b._id).map(m => m.host);
  if (cfg._id !== \"$REPLICA_SET_NAME\" || JSON.stringify(actual) !== JSON.stringify(expected)) {
    print('CONFLICT');
  } else {
    print('MATCH');
  }
} catch (e) {
  if (e && (e.code === 94 || e.codeName === 'NotYetInitialized')) {
    print('UNINITIALIZED');
  } else {
    print('ERROR:' + ((e && (e.codeName || e.code)) || 'unknown'));
  }
}
" 2>/dev/null | tail -n 1)"

case "$state" in
MATCH)
  echo "Replica Set already initialized with expected topology."
  exit 0
  ;;
CONFLICT)
  echo "mongo-replica: existing replica-set topology conflicts with expected ${REPLICA_SET_NAME}" >&2
  exit 1
  ;;
UNINITIALIZED)
  ;;
ERROR:*)
  echo "mongo-replica: failed to inspect replica-set state (${state#ERROR:})" >&2
  exit 1
  ;;
*)
  echo "mongo-replica: unable to determine replica-set state" >&2
  exit 1
  ;;
esac

echo "Initiating Replica Set..."
mongo_eval "rs.initiate({
  _id: \"$REPLICA_SET_NAME\",
  members: [
    { _id: 0, host: \"$MONGO_PRIMARY\" },
    { _id: 1, host: \"$MONGO_SECONDARY1\" },
    { _id: 2, host: \"$MONGO_SECONDARY2\" }
  ]
})"
