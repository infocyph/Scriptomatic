#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# docknotify: send host notifications via SERVER_TOOLS notifier service
#
# Protocol:
# token<TAB>timeout<TAB>urgency<TAB>source<TAB>title<TAB>body\n
# token placeholder '-' is used if NOTIFY_TOKEN is empty
# -----------------------------------------------------------------------------

HOST="${NOTIFY_HOST:-SERVER_TOOLS}"   # reachable on compose network
PORT="${NOTIFY_TCP_PORT:-9901}"
TOKEN="${NOTIFY_TOKEN:-}"
[[ -n "${TOKEN:-}" ]] || TOKEN='-'

SOURCE="${NOTIFY_SOURCE:-${HOSTNAME:-svc}}"

timeout="2500"
urgency="normal"

# Optional client caps (keep aligned with notifierd defaults)
TITLE_MAX="${NOTIFY_TITLE_MAX:-100}"
BODY_MAX="${NOTIFY_BODY_MAX:-300}"
[[ "$TITLE_MAX" =~ ^[0-9]{1,4}$ ]] || TITLE_MAX=100
[[ "$BODY_MAX"  =~ ^[0-9]{1,5}$ ]] || BODY_MAX=300

usage() {
  cat >&2 <<'EOF'
Usage:
  docknotify [-H host] [-p port] [-t ms] [-u low|normal|critical] [-s source] <title> <body>

Env:
  NOTIFY_HOST      default: SERVER_TOOLS
  NOTIFY_TCP_PORT  default: 9901
  NOTIFY_TOKEN     optional (if empty, '-' placeholder is sent)
  NOTIFY_SOURCE    optional (default: HOSTNAME or 'svc')
  NOTIFY_TITLE_MAX optional (default: 100)
  NOTIFY_BODY_MAX  optional (default: 300)
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

[[ -n "${HOST:-}" ]] || { echo "docknotify: host is empty" >&2; exit 2; }
[[ "$PORT" =~ ^[0-9]{1,5}$ ]] || { echo "docknotify: invalid port: $PORT" >&2; exit 2; }

# sanitize to keep one-line protocol stable
SOURCE="${SOURCE//$'\n'/ }"; SOURCE="${SOURCE//$'\r'/ }"; SOURCE="${SOURCE//$'\t'/ }"
title="${title//$'\n'/ }";   title="${title//$'\r'/ }";   title="${title//$'\t'/ }"
body="${body//$'\n'/ }";     body="${body//$'\r'/ }";     body="${body//$'\t'/ }"

# validate (avoid breaking the server)
[[ "$timeout" =~ ^[0-9]{1,6}$ ]] || timeout="2500"
case "$urgency" in low|normal|critical) ;; *) urgency="normal" ;; esac

# apply caps client-side (optional but nice)
title="${title:0:${TITLE_MAX}}"
body="${body:0:${BODY_MAX}}"

command -v nc >/dev/null 2>&1 || { echo "docknotify: nc not found" >&2; exit 127; }

# prefer clean close if supported
nc_args=(-w 1)
nc -h 2>&1 | grep -q -- ' -N' && nc_args=(-N -w 1)

# send (explicit newline)
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$TOKEN" "$timeout" "$urgency" "$SOURCE" "$title" "$body" \
  | nc "${nc_args[@]}" "$HOST" "$PORT"
