#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

assert_contains "$ROOT/bash/certbot-renew.sh" 'CERTBOT_RENEW_INTERVAL:-12h'
assert_contains "$ROOT/bash/certbot-renew.sh" 'CERTBOT_DEPLOY_HOOK:-/usr/local/bin/reload-services'
assert_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_REPLICA_SET_NAME:-rs0'
assert_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_PRIMARY_HOST:-mongo-primary:27017'
pass 'server-helper baseline contracts'
