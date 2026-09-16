#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

# Scriptomatic intentionally permits direct /main/ consumption. Stale self-refs
# to /master/ are not part of that policy.
if grep -IRn 'raw.githubusercontent.com/infocyph/Scriptomatic/master/' "$ROOT/bash" >/dev/null 2>&1; then
  fail 'stale Scriptomatic master raw URL found'
fi

# Toolset must use its stable release installer, never source-branch scripts.
if grep -IRn 'raw.githubusercontent.com/infocyph/Toolset/main' "$ROOT/bash" >/dev/null 2>&1; then
  fail 'mutable Toolset main dependency found'
fi

if grep -IRnE 'curl[^|\n]*\|[[:space:]]*(ba)?sh|wget[^|\n]*\|[[:space:]]*(ba)?sh' "$ROOT/bash" >/dev/null 2>&1; then
  fail 'remote content piped directly to shell'
fi

if grep -IRnE 'rm[[:space:]]+-rf[[:space:]]+/(tmp|var/tmp)/\*' "$ROOT/bash" >/dev/null 2>&1; then
  fail 'broad temporary-directory deletion found'
fi

if grep -IRnE '(^|[[:space:]])eval([[:space:]]|$)' "$ROOT/bash" >/dev/null 2>&1; then
  fail 'eval found in shipped scripts'
fi

if grep -IRnE 'docker[[:space:]]+exec[[:space:]]+-(it|ti)([[:space:]]|$)' "$ROOT/bash" >/dev/null 2>&1; then
  fail 'interactive docker exec found in automation helper'
fi

if grep -IRnE 'for[[:space:]]+[^;]+[[:space:]]+in[[:space:]]+\$\([^)]*git[[:space:]]+ls-files' "$ROOT/bash" >/dev/null 2>&1; then
  fail 'whitespace-unsafe git ls-files iteration found'
fi

for file in "$ROOT/bash/php-cli-setup.sh" "$ROOT/bash/node-cli-setup.sh"; do
  assert_contains "$file" 'SCRIPTOMATIC_DOWNLOAD_CONNECT_TIMEOUT'
  assert_contains "$file" 'SCRIPTOMATIC_DOWNLOAD_MAX_TIME'
  assert_contains "$file" 'SCRIPTOMATIC_DOWNLOAD_RETRIES'
  assert_contains "$file" ': "${SCRIPTOMATIC_REF:=main}"'
  assert_contains "$file" 'SCRIPTOMATIC_BASE_URL="https://raw.githubusercontent.com/infocyph/Scriptomatic/${SCRIPTOMATIC_REF}/bash"'
  assert_contains "$file" 'TOOLSET_INSTALLER_URL="https://github.com/infocyph/Toolset/releases/latest/download/install.sh"'
  assert_contains "$file" 'bash "$installer" --prefix /usr/local/bin gitx chromacat'
  assert_not_contains "$file" 'TOOLSET_REF'
  assert_contains "$file" 'chown root:root /usr/local/bin/'
done

assert_contains "$ROOT/bash/node-entry.sh" 'sh -lc "$NODE_CMD"'
assert_contains "$ROOT/docs/security-review.md" 'trusted shell-expression'
assert_contains "$ROOT/bash/docknotify.sh" 'TOKEN="$(sanitize_field "$TOKEN")"'
assert_contains "$ROOT/bash/mongo-replica.sh" 'REPLICA_SET_NAME="rs0"'
assert_contains "$ROOT/bash/mongo-replica.sh" "e.code === 94"
assert_not_contains "$ROOT/bash/mongo-replica.sh" 'MONGO_REPLICA_SET_NAME'
assert_not_contains "$ROOT/bash/certbot-renew.sh" 'CERTBOT_RENEW_INTERVAL'
assert_not_contains "$ROOT/bash/certbot-renew.sh" 'CERTBOT_DEPLOY_HOOK'
assert_not_contains "$ROOT/bash/certbot-renew.sh" 'CERTBOT_RENEW_ONCE'

pass 'security and reliability audit'
