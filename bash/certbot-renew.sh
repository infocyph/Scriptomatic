#!/usr/bin/env bash
set -Eeuo pipefail

: "${CERTBOT_BIN:=certbot}"
: "${CERTBOT_DEPLOY_HOOK:=/usr/local/bin/reload-services}"
: "${CERTBOT_RENEW_INTERVAL_SECONDS:=43200}"
: "${CERTBOT_RENEW_JITTER_SECONDS:=0}"
: "${CERTBOT_RENEW_FAILURE_BACKOFF_SECONDS:=60}"
: "${CERTBOT_RENEW_MAX_FAILURES:=5}"
: "${CERTBOT_RENEW_ONCE:=0}"

stop_requested=0
sleep_pid=''

log() {
  printf 'certbot-renew: %s\n' "$*" >&2
}

fatal() {
  log "$*"
  exit 1
}

validate_uint() {
  local name="$1" value="$2" min="$3" max="$4"
  [[ "$value" =~ ^[0-9]+$ ]] || fatal "$name must be an integer"
  (( value >= min && value <= max )) || fatal "$name must be between $min and $max"
}

validate_bool() {
  local name="$1" value="$2"
  [[ "$value" == 0 || "$value" == 1 ]] || fatal "$name must be 0 or 1"
}

request_stop() {
  stop_requested=1
  if [[ -n "$sleep_pid" ]]; then
    kill "$sleep_pid" >/dev/null 2>&1 || true
  fi
}

sleep_interruptible() {
  local seconds="$1"
  (( seconds > 0 )) || return 0

  sleep "$seconds" &
  sleep_pid=$!
  wait "$sleep_pid" 2>/dev/null || true
  sleep_pid=''
}

next_interval() {
  local delay="$CERTBOT_RENEW_INTERVAL_SECONDS"
  if (( CERTBOT_RENEW_JITTER_SECONDS > 0 )); then
    delay=$((delay + (RANDOM % (CERTBOT_RENEW_JITTER_SECONDS + 1))))
  fi
  printf '%s' "$delay"
}

run_renewal() {
  "$CERTBOT_BIN" renew --quiet --deploy-hook "$CERTBOT_DEPLOY_HOOK"
}

main() {
  command -v "$CERTBOT_BIN" >/dev/null 2>&1 || fatal "certbot executable not found: $CERTBOT_BIN"
  [[ -x "$CERTBOT_DEPLOY_HOOK" ]] || fatal "deploy hook is not executable: $CERTBOT_DEPLOY_HOOK"

  validate_uint CERTBOT_RENEW_INTERVAL_SECONDS "$CERTBOT_RENEW_INTERVAL_SECONDS" 1 604800
  validate_uint CERTBOT_RENEW_JITTER_SECONDS "$CERTBOT_RENEW_JITTER_SECONDS" 0 86400
  validate_uint CERTBOT_RENEW_FAILURE_BACKOFF_SECONDS "$CERTBOT_RENEW_FAILURE_BACKOFF_SECONDS" 1 86400
  validate_uint CERTBOT_RENEW_MAX_FAILURES "$CERTBOT_RENEW_MAX_FAILURES" 0 1000
  validate_bool CERTBOT_RENEW_ONCE "$CERTBOT_RENEW_ONCE"

  trap request_stop INT TERM

  local failures=0 delay
  while (( stop_requested == 0 )); do
    if run_renewal; then
      failures=0
      log "renewal cycle completed"
    else
      failures=$((failures + 1))
      log "renewal cycle failed (consecutive failures: $failures)"

      if (( CERTBOT_RENEW_MAX_FAILURES > 0 && failures >= CERTBOT_RENEW_MAX_FAILURES )); then
        fatal "failure threshold reached; exiting so the container supervisor can restart or surface the fault"
      fi

      (( stop_requested == 1 )) && break
      sleep_interruptible "$CERTBOT_RENEW_FAILURE_BACKOFF_SECONDS"
      (( stop_requested == 1 )) && break
    fi

    (( CERTBOT_RENEW_ONCE == 1 )) && break
    delay="$(next_interval)"
    log "next renewal cycle in ${delay}s"
    sleep_interruptible "$delay"
  done

  log "shutdown requested; exiting"
}

main "$@"
