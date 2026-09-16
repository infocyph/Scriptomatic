#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/app"

output="$(APP_DIR="$tmp/app" NODE_LOG_ENABLED=0 ROOTCA_PATH="$tmp/missing.pem" \
  "$ROOT/bash/node-entry.sh" sh -c 'printf "%s" "$1"' sh 'forwarded value')"
assert_eq 'forwarded value' "$output" 'node-entry direct command forwarding changed'
pass 'node entrypoint direct command forwarding'
