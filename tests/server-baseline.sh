#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

assert_contains "$ROOT/bash/certbot-renew.sh" 'RENEW_INTERVAL="12h"'
assert_contains "$ROOT/bash/certbot-renew.sh" 'DEPLOY_HOOK="/usr/local/bin/reload-services"'
assert_not_contains "$ROOT/bash/certbot-renew.sh" 'CERTBOT_RENEW_INTERVAL'
assert_not_contains "$ROOT/bash/certbot-renew.sh" 'CERTBOT_DEPLOY_HOOK'
assert_not_contains "$ROOT/bash/certbot-renew.sh" 'CERTBOT_RENEW_ONCE'

assert_contains "$ROOT/bash/mongo-replica.sh" 'REPLICA_SET_NAME="rs0"'
assert_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_PRIMARY="mongo-primary:27017"'
assert_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_SECONDARY1="mongo-secondary1:27017"'
assert_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_SECONDARY2="mongo-secondary2:27017"'
assert_not_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_REPLICA_SET_NAME'
assert_not_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_PRIMARY_HOST'
assert_not_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_SECONDARY1_HOST'
assert_not_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_SECONDARY2_HOST'

pass 'server-helper baseline contracts'
