#!/usr/bin/env bash
set -Eeuo pipefail

MONGO_URI="mongodb://127.0.0.1:27017"
MONGO_READY_TIMEOUT_SECONDS=60
MONGO_READY_INTERVAL_SECONDS=2
MONGO_INIT_TIMEOUT_SECONDS=60

log() { printf 'mongo-replica: %s\n' "$*" >&2; }
fatal() { log "$*"; exit 1; }

if command -v mongosh >/dev/null 2>&1; then
  MONGO_SHELL=mongosh
elif command -v mongo >/dev/null 2>&1; then
  MONGO_SHELL=mongo
else
  fatal "mongosh or mongo is required"
fi

mongo_eval() {
  "$MONGO_SHELL" --quiet "$MONGO_URI" --eval "$1"
}

deadline=$((SECONDS + MONGO_READY_TIMEOUT_SECONDS))
until mongo_eval 'quit(db.adminCommand({ping:1}).ok === 1 ? 0 : 1)' >/dev/null 2>&1; do
  (( SECONDS < deadline )) || fatal "MongoDB did not become ready within ${MONGO_READY_TIMEOUT_SECONDS}s"
  sleep "$MONGO_READY_INTERVAL_SECONDS"
done

check_script='try { const cfg=rs.conf(); const desired=["mongo-primary:27017","mongo-secondary1:27017","mongo-secondary2:27017"]; if (cfg._id !== "rs0" || !cfg.members || cfg.members.length !== 3) quit(42); for (let i=0;i<3;i++){ if (cfg.members[i]._id !== i || cfg.members[i].host !== desired[i]) quit(42); } quit(0); } catch (e) { const msg=String((e && (e.codeName || e.message)) || e); const code=(e && e.code) || 0; if (code === 94 || /NotYetInitialized|no replset config|not yet initialized/i.test(msg)) quit(3); print(msg); quit(43); }'
set +e
mongo_eval "$check_script" >/dev/null 2>&1
state=$?
set -e

case "$state" in
  0)
    log "replica set already initialized"
    exit 0
    ;;
  3)
    echo "Initiating Replica Set..."
    mongo_eval 'const result=rs.initiate({_id:"rs0",members:[{_id:0,host:"mongo-primary:27017"},{_id:1,host:"mongo-secondary1:27017"},{_id:2,host:"mongo-secondary2:27017"}]}); if (!result || result.ok !== 1) { printjson(result); quit(1); }' >/dev/null
    ;;
  42)
    fatal "existing replica-set topology conflicts with Scriptomatic rs0 topology"
    ;;
  *)
    fatal "unable to inspect replica-set state"
    ;;
esac

deadline=$((SECONDS + MONGO_INIT_TIMEOUT_SECONDS))
until mongo_eval "$check_script" >/dev/null 2>&1; do
  (( SECONDS < deadline )) || fatal "replica set did not converge within ${MONGO_INIT_TIMEOUT_SECONDS}s"
  sleep "$MONGO_READY_INTERVAL_SECONDS"
done
