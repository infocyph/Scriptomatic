#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

assert_contains "$ROOT/bash/certbot-renew.sh" 'sleep 12h'
assert_contains "$ROOT/bash/certbot-renew.sh" 'certbot renew --quiet --deploy-hook /usr/local/bin/reload-services'
assert_contains "$ROOT/bash/mongo-replica.sh" '_id: "rs0"'
assert_contains "$ROOT/bash/mongo-replica.sh" 'mongo-primary:27017'
pass 'server-helper baseline contracts'
