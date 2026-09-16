#!/usr/bin/env bash
set -euo pipefail

HOST="${NOTIFY_HOST:-SERVER_TOOLS}"
PORT="${NOTIFY_TCP_PORT:-9901}"
TOKEN="${NOTIFY_TOKEN:-}"
[[ -n "$TOKEN" ]] || TOKEN='-'
SOURCE="${NOTIFY_SOURCE:-${HOSTNAME:-svc}}"

timeout="2500"
urgency="normal"
TITLE_MAX="${NOTIFY_TITLE_MAX:-100}"
BODY_MAX="${NOTIFY_BODY_MAX:-300}"
[[ "$TITLE_MAX" =~ ^[0-9]{1,4}$ ]] || TITLE_MAX=100
[[ "$BODY_MAX" =~ ^[0-9]{1,5}$ ]] || BODY_MAX=300
STRICT="${DOCKNOTIFY_STRICT:-0}"

usage() {
  cat >&2 <<'EOF'
Usage:
  docknotify [-H host] [-p port] [-t ms] [-u low|normal|critical] [-s source] <title> <body>
EOF
  exit 2
}

while getopts ":H:p:t:u:s:" opt; do
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

[[ $# -ge 2 ]] || usage
title="$1"
body="$2"

[[ -n "$HOST" ]] || { echo "docknotify: host is empty" >&2; exit 2; }
[[ "$HOST" != -* && "$HOST" =~ ^[A-Za-z0-9_.:%\[\]-]+$ ]] || {
  echo "docknotify: invalid host" >&2
  exit 2
}
[[ "$PORT" =~ ^[0-9]{1,5}$ ]] || { echo "docknotify: invalid port" >&2; exit 2; }
((PORT >= 1 && PORT <= 65535)) || { echo "docknotify: port out of range" >&2; exit 2; }

[[ "$timeout" =~ ^[0-9]{1,6}$ ]] || timeout="2500"
(( timeout >= 0 && timeout <= 999999 )) || timeout="2500"
case "$urgency" in low | normal | critical) ;; *) urgency="normal" ;; esac

sanitize_field() {
  local value="$1"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="${value//$'\t'/ }"
  printf '%s' "$value"
}

TOKEN="$(sanitize_field "$TOKEN")"
SOURCE="$(sanitize_field "$SOURCE")"
title="$(sanitize_field "$title")"
body="$(sanitize_field "$body")"

title="${title:0:TITLE_MAX}"
body="${body:0:BODY_MAX}"

command -v nc >/dev/null 2>&1 || {
  echo "docknotify: nc not found" >&2
  exit 127
}

if ! printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$TOKEN" "$timeout" "$urgency" "$SOURCE" "$title" "$body" \
  | nc -w 1 "$HOST" "$PORT" >/dev/null 2>&1; then
  if [[ "$STRICT" == "1" ]]; then
    echo "docknotify: failed to send to $HOST:$PORT" >&2
    exit 1
  fi
  exit 0
fi
