#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash_scripts=(
  bash/alias-maker.sh
  bash/banner.sh
  bash/certbot-hook.sh
  bash/certbot-renew.sh
  bash/docknotify.sh
  bash/mongo-replica.sh
  bash/node-cli-setup.sh
  bash/owners.sh
  bash/php-cli-setup.sh
)
sh_scripts=(
  bash/node-entry.sh
  bash/php-entry.sh
)

for script in "${bash_scripts[@]}"; do
  bash -n "$ROOT/$script"
done
for script in "${sh_scripts[@]}"; do
  sh -n "$ROOT/$script"
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S error -s bash "${bash_scripts[@]/#/$ROOT/}"
  shellcheck -S error -s sh "${sh_scripts[@]/#/$ROOT/}"
  shellcheck -S error "$ROOT"/tests/*.sh "$ROOT"/tests/lib/*.sh
fi

printf 'static validation passed\n'
