#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"

for script in "$ROOT"/bash/*.sh; do
  assert_file_exists "$script"
  [[ -s "$script" ]] || fail "empty script: $script"
  head -n 1 "$script" | grep -Eq '^#!' || fail "missing shebang: $script"
done

set +e
"$ROOT/bash/docknotify.sh" >/dev/null 2>&1
status=$?
set -e
assert_eq 2 "$status" 'docknotify usage exit code changed'

pass 'repository smoke checks'
