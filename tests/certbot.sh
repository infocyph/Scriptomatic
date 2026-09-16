#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"

cat > "$work/bin/docker" <<'EOF_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
calls="${MOCK_DOCKER_CALLS:?}"
if [[ "${1:-}" == container && "${2:-}" == inspect ]]; then
  name="${@: -1}"
  case "$name" in
    NGINX) state="${MOCK_NGINX_STATE:-missing}" ;;
    APACHE) state="${MOCK_APACHE_STATE:-missing}" ;;
    *) state=missing ;;
  esac
  case "$state" in
    running) printf 'true\n'; exit 0 ;;
    stopped) printf 'false\n'; exit 0 ;;
    missing) exit 1 ;;
  esac
fi
if [[ "${1:-}" == exec ]]; then
  shift
  name="$1"
  shift
  printf '%s\t%s\n' "$name" "$*" >> "$calls"
  exit 0
fi
exit 64
EOF_DOCKER
chmod +x "$work/bin/docker"
: > "$work/docker-calls"
export PATH="$work/bin:$PATH"
export MOCK_DOCKER_CALLS="$work/docker-calls"

MOCK_NGINX_STATE=missing MOCK_APACHE_STATE=missing bash "$ROOT/bash/certbot-hook.sh" >/dev/null
assert_eq 0 "$(wc -l < "$work/docker-calls" | tr -d ' ')" "missing containers do not reload"

MOCK_NGINX_STATE=stopped MOCK_APACHE_STATE=missing bash "$ROOT/bash/certbot-hook.sh" >/dev/null
assert_eq 0 "$(wc -l < "$work/docker-calls" | tr -d ' ')" "stopped containers do not reload"
pass "certbot hook preserves reload-if-running behavior"

: > "$work/docker-calls"
MOCK_NGINX_STATE=running MOCK_APACHE_STATE=missing bash "$ROOT/bash/certbot-hook.sh" >/dev/null
assert_contains "$(cat "$work/docker-calls")" $'NGINX\tnginx -s reload' "fixed NGINX reload target"
assert_not_contains "$(cat "$work/docker-calls")" '-it' "docker exec must not allocate a TTY"
pass "certbot hook fixes exact running detection and non-interactive exec"

hook_text="$(cat "$ROOT/bash/certbot-hook.sh")"
assert_not_contains "$hook_text" 'CERTBOT_NGINX_CONTAINER' "container-name policy knob must not be introduced"
assert_not_contains "$hook_text" 'CERTBOT_APACHE_CONTAINER' "container-name policy knob must not be introduced"

renew_text="$(cat "$ROOT/bash/certbot-renew.sh")"
assert_contains "$renew_text" 'while true' "historical infinite renewal loop"
assert_contains "$renew_text" 'certbot renew --quiet --deploy-hook /usr/local/bin/reload-services' "historical certbot command"
assert_contains "$renew_text" 'sleep 12h' "historical renewal interval"
assert_not_contains "$renew_text" 'CERTBOT_RENEW_' "renewal policy knobs must not be introduced"
pass "certbot renewal behavior is unchanged from main"
