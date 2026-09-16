#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/app" "$work/bin" "$work/ca"

set +e
APP_DIR="$work/app" NODE_LOG_ENABLED=0 sh "$ROOT/bash/node-entry.sh" sh -c 'exit 17'
rc=$?
set -e
assert_eq 17 "$rc" "node-entry direct command exit propagation"
assert_not_file "$work/app/access.log"
pass "direct command forwarding preserves exit and default stdout/stderr mode"

set +e
APP_DIR="$work/app" sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 1 "$rc" "no runnable app should fail by default"
pass "no default keepalive masks an unrunnable app"

cat > "$work/bin/npm" <<'EOF_NPM'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "${NPM_CALLS:?}"
case " $* " in
  *' ci '*) exit 9 ;;
  *) exit 0 ;;
esac
EOF_NPM
chmod +x "$work/bin/npm"

cat > "$work/app/package.json" <<'EOF_PACKAGE'
{"name":"fixture","scripts":{}}
EOF_PACKAGE
: > "$work/app/package-lock.json"
: > "$work/npm-calls"

set +e
PATH="$work/bin:$PATH" NPM_CALLS="$work/npm-calls" APP_DIR="$work/app" \
  NODE_AUTO_INSTALL=1 NODE_ALLOW_LOCKFILE_FALLBACK=0 \
  sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 1 "$rc" "strict npm ci failure should fail startup"
assert_eq 1 "$(wc -l < "$work/npm-calls" | tr -d ' ')" "strict install call count"
assert_contains "$(cat "$work/npm-calls")" 'ci' "strict npm ci call"
assert_not_contains "$(cat "$work/npm-calls")" 'install' "implicit mutable fallback"
pass "lockfile fallback is disabled by default"

: > "$work/npm-calls"
set +e
PATH="$work/bin:$PATH" NPM_CALLS="$work/npm-calls" APP_DIR="$work/app" \
  NODE_AUTO_INSTALL=1 NODE_ALLOW_LOCKFILE_FALLBACK=1 \
  sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 1 "$rc" "fixture remains unrunnable after explicit dependency fallback"
assert_eq 2 "$(wc -l < "$work/npm-calls" | tr -d ' ')" "explicit fallback call count"
assert_contains "$(cat "$work/npm-calls")" 'install' "explicit npm install fallback"
pass "lockfile fallback occurs only when explicitly enabled"

# Ensure dev selection runs exactly once instead of probing a long-running script first.
cat > "$work/app/package.json" <<'EOF_DEV'
{"name":"fixture","scripts":{"dev":"fixture-dev"}}
EOF_DEV
rm -f "$work/app/package-lock.json"
: > "$work/npm-calls"
set +e
PATH="$work/bin:$PATH" NPM_CALLS="$work/npm-calls" APP_DIR="$work/app" NODE_AUTO_INSTALL=0 \
  sh "$ROOT/bash/node-entry.sh" >/dev/null 2>&1
rc=$?
set -e
assert_eq 0 "$rc" "mock dev command exit"
assert_eq 1 "$(wc -l < "$work/npm-calls" | tr -d ' ')" "dev command must run once"
assert_contains "$(cat "$work/npm-calls")" 'run dev' "selected dev command"
pass "generic dev script is selected once without probe execution"

# Content-aware root CA handling using a fake sudo/update-ca-certificates boundary.
cat > "$work/bin/sudo" <<'EOF_SUDO'
#!/usr/bin/env sh
[ "${1:-}" = '--' ] && shift
exec "$@"
EOF_SUDO
cat > "$work/bin/update-ca-certificates" <<'EOF_CA'
#!/usr/bin/env sh
printf 'updated\n' >> "${CA_UPDATE_LOG:?}"
EOF_CA
chmod +x "$work/bin/sudo" "$work/bin/update-ca-certificates"
printf 'ca-v1\n' > "$work/source.pem"
: > "$work/updates"

PATH="$work/bin:$PATH" APP_DIR="$work/app" ROOTCA_PATH="$work/source.pem" ROOTCA_DEST="$work/ca/rootCA.crt" \
  ROOTCA_REQUIRED=1 CA_UPDATE_LOG="$work/updates" sh "$ROOT/bash/node-entry.sh" true
assert_eq 1 "$(wc -l < "$work/updates" | tr -d ' ')" "initial CA refresh"
PATH="$work/bin:$PATH" APP_DIR="$work/app" ROOTCA_PATH="$work/source.pem" ROOTCA_DEST="$work/ca/rootCA.crt" \
  ROOTCA_REQUIRED=1 CA_UPDATE_LOG="$work/updates" sh "$ROOT/bash/node-entry.sh" true
assert_eq 1 "$(wc -l < "$work/updates" | tr -d ' ')" "unchanged CA refresh"
printf 'ca-v2\n' > "$work/source.pem"
PATH="$work/bin:$PATH" APP_DIR="$work/app" ROOTCA_PATH="$work/source.pem" ROOTCA_DEST="$work/ca/rootCA.crt" \
  ROOTCA_REQUIRED=1 CA_UPDATE_LOG="$work/updates" sh "$ROOT/bash/node-entry.sh" true
assert_eq 2 "$(wc -l < "$work/updates" | tr -d ' ')" "changed CA refresh"
pass "Node root CA bootstrap is content-aware"
