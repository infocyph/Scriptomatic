#!/usr/bin/env bash
set -euo pipefail

REPLICA_SET_NAME="rs0"
MONGO_PRIMARY="mongo-primary:27017"
MONGO_SECONDARY1="mongo-secondary1:27017"
MONGO_SECONDARY2="mongo-secondary2:27017"
MONGO_READY_ATTEMPTS=30
MONGO_READY_DELAY=2

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
