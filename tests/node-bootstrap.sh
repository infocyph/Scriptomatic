#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

command -v node >/dev/null 2>&1 || fail "node fixture missing node"
command -v npm >/dev/null 2>&1 || fail "node fixture missing npm"
[[ -f /etc/alpine-release ]] || fail "node bootstrap integration expects Alpine fixture"
bash -n "$ROOT/bash/node-cli-setup.sh"
pass "Node Alpine fixture and setup parser are available"

printf 'node bootstrap execution remains Phase 3 work; CI fixture is established\n'
