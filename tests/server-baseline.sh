#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT/bash/certbot-hook.sh"
bash -n "$ROOT/bash/certbot-renew.sh"
bash -n "$ROOT/bash/mongo-replica.sh"
printf 'server/service helper parser baseline passed\n'
