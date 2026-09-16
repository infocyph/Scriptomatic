#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/ca"
printf 'ca-v1\n' > "$work/source.pem"

cat > "$work/bin/docker-php-entrypoint" <<'EOF_ENTRY'
#!/usr/bin/env sh
printf '%s\n' "$*" > "${ENTRY_ARGS_FILE:?}"
exit "${ENTRY_EXIT_CODE:-0}"
EOF_ENTRY
chmod +x "$work/bin/docker-php-entrypoint"

cat > "$work/bin/update-ca-certificates" <<'EOF_CA'
#!/usr/bin/env sh
printf 'updated\n' >> "${CA_UPDATE_LOG:?}"
EOF_CA
chmod +x "$work/bin/update-ca-certificates"

export PATH="$work/bin:$PATH"
export ROOTCA_PATH="$work/source.pem"
export ROOTCA_DEST="$work/ca/rootCA.crt"
export ROOTCA_REQUIRED=1
export ENTRY_ARGS_FILE="$work/args"
export CA_UPDATE_LOG="$work/updates"

set +e
ENTRY_EXIT_CODE=23 sh "$ROOT/bash/php-entry.sh" alpha 'two words'
rc=$?
set -e
assert_eq 23 "$rc" "php-entry final process exit code"
assert_eq 'alpha two words' "$(cat "$work/args")" "php-entry argument forwarding"
assert_eq 'ca-v1' "$(tr -d '\n' < "$ROOTCA_DEST")" "root CA installed"
assert_eq 1 "$(wc -l < "$work/updates" | tr -d ' ')" "root CA update count"
pass "php-entry installs changed CA and preserves final exit code"

ENTRY_EXIT_CODE=0 sh "$ROOT/bash/php-entry.sh" beta
assert_eq 1 "$(wc -l < "$work/updates" | tr -d ' ')" "unchanged CA must not refresh"
pass "php-entry CA handling is content-aware"

printf 'ca-v2\n' > "$work/source.pem"
ENTRY_EXIT_CODE=0 sh "$ROOT/bash/php-entry.sh" gamma
assert_eq 2 "$(wc -l < "$work/updates" | tr -d ' ')" "changed CA refresh count"
pass "php-entry refreshes changed CA content"
