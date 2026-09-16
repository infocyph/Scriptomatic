#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/fake"
cat >"$tmp/fake/docker" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == inspect ]]; then
  container="${@: -1}"
  case "$container" in
    NGINX) [[ "${DOCKER_RUNNING_NGINX:-0}" == 1 ]] && printf 'true\n' || printf 'false\n' ;;
    APACHE) [[ "${DOCKER_RUNNING_APACHE:-0}" == 1 ]] && printf 'true\n' || printf 'false\n' ;;
  esac
  exit 0
fi
if [[ "$1" == exec ]]; then
  printf '%s\n' "$*" >>"$DOCKER_LOG"
  [[ "${DOCKER_EXEC_FAIL:-0}" == 1 ]] && exit 5
  exit 0
fi
exit 2
EOF
chmod +x "$tmp/fake/docker"
DOCKER_LOG="$tmp/docker.log" PATH="$tmp/fake:$PATH" "$ROOT/bash/certbot-hook.sh"
[[ ! -e "$tmp/docker.log" ]] || fail 'certbot hook reloaded absent containers'
DOCKER_LOG="$tmp/docker.log" DOCKER_RUNNING_NGINX=1 PATH="$tmp/fake:$PATH" "$ROOT/bash/certbot-hook.sh" >/dev/null
assert_contains "$tmp/docker.log" 'exec NGINX nginx -s reload'
assert_not_contains "$tmp/docker.log" '-it'
set +e
DOCKER_LOG="$tmp/docker.log" DOCKER_RUNNING_NGINX=1 DOCKER_EXEC_FAIL=1 PATH="$tmp/fake:$PATH" "$ROOT/bash/certbot-hook.sh" >/dev/null 2>&1
status=$?
set -e
assert_eq 1 "$status" 'certbot hook must report reload failure'

cat >"$tmp/fake/certbot" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CERTBOT_LOG"
exit 0
EOF
cat >"$tmp/fake/sleep" <<'EOF'
#!/usr/bin/env bash
kill -TERM "$PPID"
exit 0
EOF
chmod +x "$tmp/fake/certbot" "$tmp/fake/sleep"

CERTBOT_LOG="$tmp/certbot.log" PATH="$tmp/fake:$PATH" "$ROOT/bash/certbot-renew.sh" >/dev/null
assert_contains "$tmp/certbot.log" 'renew --quiet --deploy-hook /usr/local/bin/reload-services'
assert_eq 1 "$(wc -l <"$tmp/certbot.log" | tr -d ' ')" 'certbot renewal should run once before test shutdown'

pass 'certbot reload and fixed renew contracts'
