#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/docker-php-entrypoint" <<'STUB'
#!/bin/sh
printf '%s\n' "$@"
STUB
chmod +x "$tmp/bin/docker-php-entrypoint"

output="$(PATH="$tmp/bin:$PATH" ROOTCA_PATH="$tmp/missing.pem" "$ROOT/bash/php-entry.sh" alpha 'two words')"
assert_eq $'alpha\ntwo words' "$output" 'php-entry argument forwarding changed'
pass 'php entrypoint forwarding'
