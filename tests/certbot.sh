#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"

cat >"$work/bin/docker" <<'EOF_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
calls="${MOCK_DOCKER_CALLS:?}"
if [[ "${1:-}" == container && "${2:-}" == inspect ]]; then
  name="${@: -1}"
  case "$name" in
    NGINX|WEB_NGINX) state="${MOCK_NGINX_STATE:-missing}" ;;
    APACHE|WEB_APACHE) state="${MOCK_APACHE_STATE:-missing}" ;;
    *) state=missing ;;
  esac
  case "$state" in
    running) printf 'true\n'; exit 0 ;;
    stopped) printf 'false\n'; exit 0 ;;
    missing) printf 'Error: No such object: %s\n' "$name" >&2; exit 1 ;;
    error) printf 'Cannot connect to the Docker daemon\n' >&2; exit 1 ;;
  esac
fi
if [[ "${1:-}" == exec ]]; then
  shift
  name="$1"
  shift
  printf '%s\t%s\n' "$name" "$*" >>"$calls"
  [[ "${MOCK_DOCKER_FAIL_TARGET:-}" == "$name" ]] && exit 9
  exit 0
fi
printf 'unexpected docker invocation: %s\n' "$*" >&2
exit 64
EOF_DOCKER
chmod +x "$work/bin/docker"
: >"$work/docker-calls"

export PATH="$work/bin:$PATH"
export MOCK_DOCKER_CALLS="$work/docker-calls"

MOCK_NGINX_STATE=missing MOCK_APACHE_STATE=missing \
  bash "$ROOT/bash/certbot-hook.sh" >/dev/null 2>"$work/hook-missing.err"
assert_eq 0 "$(wc -l <"$work/docker-calls" | tr -d ' ')" "missing optional containers do not execute reloads"
pass "certbot hook skips missing optional containers"

: >"$work/docker-calls"
MOCK_NGINX_STATE=running MOCK_APACHE_STATE=missing \
  bash "$ROOT/bash/certbot-hook.sh" >/dev/null 2>"$work/hook-nginx.err"
assert_contains "NGINX" "$(cat "$work/docker-calls")" "Nginx exact target"
assert_not_contains "-it" "$(cat "$work/docker-calls")" "hook must not request a TTY"
pass "certbot hook reloads an exact running target without TTY"

set +e
MOCK_NGINX_STATE=stopped MOCK_APACHE_STATE=missing \
  bash "$ROOT/bash/certbot-hook.sh" >/dev/null 2>"$work/hook-stopped.err"
rc=$?
set -e
[[ $rc -ne 0 ]] || fail "stopped configured container must fail the hook"
pass "certbot hook reports stopped configured targets"

set +e
MOCK_NGINX_STATE=running MOCK_APACHE_STATE=missing MOCK_DOCKER_FAIL_TARGET=NGINX \
  bash "$ROOT/bash/certbot-hook.sh" >/dev/null 2>"$work/hook-reload-fail.err"
rc=$?
set -e
[[ $rc -ne 0 ]] || fail "reload failure must propagate"
unset MOCK_DOCKER_FAIL_TARGET
pass "certbot hook propagates reload failures"

: >"$work/docker-calls"
CERTBOT_NGINX_CONTAINER=WEB_NGINX CERTBOT_APACHE_CONTAINER=WEB_APACHE \
MOCK_NGINX_STATE=running MOCK_APACHE_STATE=running \
  bash "$ROOT/bash/certbot-hook.sh" >/dev/null 2>"$work/hook-custom.err"
assert_contains $'WEB_NGINX\tnginx -s reload' "$(cat "$work/docker-calls")" "custom Nginx target"
assert_contains $'WEB_APACHE\tapachectl graceful' "$(cat "$work/docker-calls")" "custom Apache target"
pass "certbot hook supports LocalDevStack/container name overrides"

cat >"$work/bin/certbot" <<'EOF_CERTBOT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${MOCK_CERTBOT_CALLS:?}"
exit "${MOCK_CERTBOT_RC:-0}"
EOF_CERTBOT
chmod +x "$work/bin/certbot"
cat >"$work/reload-services" <<'EOF_HOOK'
#!/usr/bin/env sh
exit 0
EOF_HOOK
chmod +x "$work/reload-services"
: >"$work/certbot-calls"
export MOCK_CERTBOT_CALLS="$work/certbot-calls"

CERTBOT_BIN=certbot CERTBOT_DEPLOY_HOOK="$work/reload-services" CERTBOT_RENEW_ONCE=1 \
  bash "$ROOT/bash/certbot-renew.sh" >/dev/null 2>"$work/renew-once.err"
assert_contains "renew --quiet --deploy-hook $work/reload-services" "$(cat "$work/certbot-calls")" "renew command contract"
pass "certbot renew supports deterministic one-cycle container execution"

set +e
MOCK_CERTBOT_RC=7 CERTBOT_BIN=certbot CERTBOT_DEPLOY_HOOK="$work/reload-services" \
CERTBOT_RENEW_MAX_FAILURES=1 CERTBOT_RENEW_FAILURE_BACKOFF_SECONDS=1 \
  bash "$ROOT/bash/certbot-renew.sh" >/dev/null 2>"$work/renew-fail.err"
rc=$?
set -e
[[ $rc -ne 0 ]] || fail "renew failure threshold must terminate the foreground process"
assert_contains "failure threshold reached" "$(cat "$work/renew-fail.err")" "failure threshold diagnostic"
unset MOCK_CERTBOT_RC
pass "certbot renew does not silently loop forever on repeated failure"

CERTBOT_BIN=certbot CERTBOT_DEPLOY_HOOK="$work/reload-services" \
CERTBOT_RENEW_INTERVAL_SECONDS=30 CERTBOT_RENEW_JITTER_SECONDS=0 \
  bash "$ROOT/bash/certbot-renew.sh" >/dev/null 2>"$work/renew-signal.err" &
pid=$!
sleep 0.2
kill -TERM "$pid"
wait "$pid"
pass "certbot renew exits cleanly on container termination signal"
