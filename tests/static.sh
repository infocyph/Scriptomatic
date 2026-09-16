#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

bash_scripts=(
  alias-maker.sh banner.sh certbot-hook.sh certbot-renew.sh docknotify.sh
  mongo-replica.sh node-cli-setup.sh owners.sh php-cli-setup.sh
)
sh_scripts=(node-entry.sh php-entry.sh)
all_scripts=("${bash_scripts[@]}" "${sh_scripts[@]}")

for script in "${bash_scripts[@]}"; do
  bash -n "$ROOT/bash/$script"
done
for script in "${sh_scripts[@]}"; do
  sh -n "$ROOT/bash/$script"
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "$ROOT"/bash/*.sh "$ROOT"/tests/*.sh "$ROOT"/tests/lib/*.sh
fi

for script in "${all_scripts[@]}"; do
  assert_executable "$ROOT/bash/$script"
done

if grep -IRIl $'\r' "$ROOT/bash" "$ROOT/tests" "$ROOT/.github" 2>/dev/null | grep -q .; then
  fail 'CRLF detected in shell/CI files'
fi

if grep -IRnE '^(<<<<<<<|=======|>>>>>>>)' "$ROOT/bash" "$ROOT/tests" "$ROOT/.github" >/dev/null 2>&1; then
  fail 'merge conflict marker detected'
fi

if grep -IRnE '(^|[[:space:]])set[[:space:]]+-x([[:space:]]|$)' "$ROOT/bash" >/dev/null 2>&1; then
  fail 'debug set -x left in shipped script'
fi

pass 'static validation'
