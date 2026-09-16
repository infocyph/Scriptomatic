#!/usr/bin/env bash
set -Eeuo pipefail

HOST="${NOTIFY_HOST:-SERVER_TOOLS}"
PORT="${NOTIFY_TCP_PORT:-9901}"
TOKEN="${NOTIFY_TOKEN:-}"
SOURCE="${NOTIFY_SOURCE:-${HOSTNAME:-svc}}"
timeout="2500"
urgency="normal"
TITLE_MAX="${NOTIFY_TITLE_MAX:-100}"
BODY_MAX="${NOTIFY_BODY_MAX:-300}"
STRICT="${DOCKNOTIFY_STRICT:-0}"

usage() {
  cat >&2 <<'EOF'
Usage:
  docknotify [-H host] [-p port] [-t ms] [-u low|normal|critical] [-s source] <title> <body>

Env:
  NOTIFY_HOST          default: SERVER_TOOLS
  NOTIFY_TCP_PORT      default: 9901
  NOTIFY_TOKEN         optional; '-' placeholder is sent when empty
  NOTIFY_SOURCE        optional (default: HOSTNAME or 'svc')
  NOTIFY_TITLE_MAX     optional (default: 100)
  NOTIFY_BODY_MAX      optional (default: 300)
  DOCKNOTIFY_STRICT    0 (best effort) or 1 (send failure is fatal)
EOF
  exit 2
}

fail_usage() {
  printf 'docknotify: %s\n' "$1" >&2
  exit 2
}

while getopts ':H:p:t:u:s:' opt; do
  case "$opt" in
    H) HOST="$OPTARG" ;;
    p) PORT="$OPTARG" ;;
    t) timeout="$OPTARG" ;;
    u) urgency="$OPTARG" ;;
    s) SOURCE="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[[ $# -eq 2 ]] || usage

title="$1"
body="$2"

[[ -n "$HOST" && "$HOST" != *$'\n'* && "$HOST" != *$'\r'* && "$HOST" != *$'\t'* ]] || fail_usage 'invalid host'
[[ "$PORT" =~ ^[0-9]{1,5}$ ]] || fail_usage 'port must be numeric'
(( PORT >= 1 && PORT <= 65535 )) || fail_usage 'port must be between 1 and 65535'
[[ "$timeout" =~ ^[0-9]{1,6}$ ]] || fail_usage 'timeout must be numeric milliseconds'
(( timeout >= 1 )) || fail_usage 'timeout must be positive'
case "$urgency" in low|normal|critical) ;; *) fail_usage 'urgency must be low, normal, or critical' ;; esac
[[ "$TITLE_MAX" =~ ^[0-9]{1,4}$ ]] && (( TITLE_MAX >= 1 )) || fail_usage 'NOTIFY_TITLE_MAX must be positive'
[[ "$BODY_MAX" =~ ^[0-9]{1,5}$ ]] && (( BODY_MAX >= 1 )) || fail_usage 'NOTIFY_BODY_MAX must be positive'
[[ "$STRICT" == 0 || "$STRICT" == 1 ]] || fail_usage 'DOCKNOTIFY_STRICT must be 0 or 1'

if [[ -n "$TOKEN" ]]; then
  [[ "$TOKEN" != *$'\n'* && "$TOKEN" != *$'\r'* && "$TOKEN" != *$'\t'* ]] || fail_usage 'NOTIFY_TOKEN contains a protocol separator'
else
  TOKEN='-'
fi

sanitize_field() {
  local value="$1"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="${value//$'\t'/ }"
  printf '%s' "$value"
}

SOURCE="$(sanitize_field "$SOURCE")"
title="$(sanitize_field "$title")"
body="$(sanitize_field "$body")"
title="${title:0:TITLE_MAX}"
body="${body:0:BODY_MAX}"

command -v nc >/dev/null 2>&1 || {
  printf 'docknotify: nc not found\n' >&2
  exit 127
}

# Stream the protocol record directly so command substitution cannot strip its newline.
if ! printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$TOKEN" "$timeout" "$urgency" "$SOURCE" "$title" "$body" |
  nc -w 1 "$HOST" "$PORT" >/dev/null 2>&1; then
  if [[ "$STRICT" == 1 ]]; then
    printf 'docknotify: failed to send to %s:%s\n' "$HOST" "$PORT" >&2
    exit 1
  fi
  exit 0
fi
