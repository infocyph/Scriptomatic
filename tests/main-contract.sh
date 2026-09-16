#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

scripts=(
  alias-maker.sh banner.sh certbot-hook.sh certbot-renew.sh docknotify.sh
  mongo-replica.sh node-cli-setup.sh node-entry.sh owners.sh php-cli-setup.sh php-entry.sh
)

for script in "${scripts[@]}"; do
  assert_file_exists "$ROOT/bash/$script"
  assert_executable "$ROOT/bash/$script"
done

for file in "$ROOT/bash/php-cli-setup.sh" "$ROOT/bash/node-cli-setup.sh"; do
  assert_contains "$file" ': "${SCRIPTOMATIC_REF:=main}"'
  assert_contains "$file" 'SCRIPTOMATIC_BASE_URL="https://raw.githubusercontent.com/infocyph/Scriptomatic/${SCRIPTOMATIC_REF}/bash"'
  assert_contains "$file" 'TOOLSET_INSTALLER_URL="https://github.com/infocyph/Toolset/releases/latest/download/install.sh"'
  assert_contains "$file" 'bash "$installer" --prefix /usr/local/bin gitx chromacat'
  assert_not_contains "$file" 'TOOLSET_REF'
  assert_not_contains "$file" 'raw.githubusercontent.com/infocyph/Toolset/main'
done

assert_contains "$ROOT/README.md" 'https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/<script>.sh'
assert_contains "$ROOT/README.md" 'pin a full commit SHA'
assert_contains "$ROOT/docs/script-contracts.md" '`main` is the canonical distribution branch'
assert_contains "$ROOT/docs/security-review.md" 'direct installation from `main`'

if grep -IRn 'raw.githubusercontent.com/infocyph/Scriptomatic/master/' \
  "$ROOT/bash" "$ROOT/README.md" "$ROOT/docs/script-contracts.md" "$ROOT/docs/security-review.md" >/dev/null 2>&1; then
  fail 'canonical Scriptomatic surfaces still reference master'
fi

if grep -IRn 'raw.githubusercontent.com/infocyph/Toolset/main' \
  "$ROOT/bash" "$ROOT/README.md" "$ROOT/docs/script-contracts.md" "$ROOT/docs/security-review.md" >/dev/null 2>&1; then
  fail 'Scriptomatic still consumes Toolset from a mutable source branch'
fi

if find "$ROOT/.github/workflows" -maxdepth 1 -type f \( -iname '*release*' -o -iname '*publish*' \) | grep -q .; then
  fail 'release/publish workflow exists despite main-only Scriptomatic distribution contract'
fi

if grep -IRnE '^[[:space:]]*tags:' "$ROOT/.github/workflows" >/dev/null 2>&1; then
  fail 'tag-triggered workflow exists despite main-only Scriptomatic distribution contract'
fi

pass 'main-branch and latest-stable Toolset dependency contract'
