#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

source_text="$(cat "$ROOT/bash/php-entry.sh")"
assert_not_contains "$source_text" 'ROOTCA_REQUIRED' "root CA strictness policy must not be introduced"
assert_not_contains "$source_text" '${ROOTCA_DEST:-' "root CA destination must not become a public knob"
assert_not_contains "$source_text" '.rootca_installed' "stale root CA stamp must stay removed"
assert_contains "$source_text" 'sha256_file' "root CA refresh compares content"
assert_contains "$source_text" '/usr/local/share/ca-certificates/rootCA.crt' "historical CA destination remains fixed"
pass "PHP CA hardening preserves the original public interface"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"

cat > "$work/bin/docker-php-entrypoint" <<'EOF_ENTRY'
#!/usr/bin/env sh
printf '%s\n' "$*" > "${ENTRY_ARGS_FILE:?}"
exit 23
EOF_ENTRY
chmod +x "$work/bin/docker-php-entrypoint"

set +e
PATH="$work/bin:$PATH" ENTRY_ARGS_FILE="$work/args" ROOTCA_PATH="$work/missing.pem" \
  sh "$ROOT/bash/php-entry.sh" alpha 'two words'
rc=$?
set -e
assert_eq 23 "$rc" "php-entry final process exit code"
assert_eq 'alpha two words' "$(cat "$work/args")" "php-entry argument forwarding"
pass "php-entry remains a transparent final process wrapper"
