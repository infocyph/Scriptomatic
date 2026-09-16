#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/app"

set +e
APP_DIR="$work/app" NODE_LOG_ENABLED=0 sh "$ROOT/bash/node-entry.sh" sh -c 'exit 17'
rc=$?
set -e
assert_eq 17 "$rc" "node-entry direct command exit propagation"
pass "node-entry baseline direct-command forwarding"

printf 'node entrypoint baseline passed; Phase 3 expands policy/CA/dependency coverage\n'
