#!/usr/bin/env bash
set -Eeuo pipefail

: "${CERTBOT_NGINX_CONTAINER:=NGINX}"
: "${CERTBOT_APACHE_CONTAINER:=APACHE}"
: "${CERTBOT_RELOAD_TIMEOUT_SECONDS:=20}"

log() {
  printf 'certbot-hook: %s\n' "$*" >&2
}

fatal() {
  log "$*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "required command not found: $1"
}

validate_uint() {
  local name="$1" value="$2" min="$3" max="$4"
  [[ "$value" =~ ^[0-9]+$ ]] || fatal "$name must be an integer"
  (( value >= min && value <= max )) || fatal "$name must be between $min and $max"
}

container_running() {
  local name="$1" output rc

  set +e
  output="$(docker container inspect --format '{{.State.Running}}' "$name" 2>&1)"
  rc=$?
  set -e

  if (( rc != 0 )); then
    case "$output" in
      *"No such object"*|*"No such container"*) return 2 ;;
      *) log "unable to inspect container '$name': $output"; return 1 ;;
    esac
  fi

  case "$output" in
    true) return 0 ;;
    false) return 3 ;;
    *) log "unexpected Docker state for '$name': $output"; return 1 ;;
  esac
}

reload_target() {
  local label="$1" name="$2"
  shift 2
  local rc

  if [[ -z "$name" ]]; then
    log "$label reload disabled because its container name is empty"
    return 0
  fi

  if container_running "$name"; then
    :
  else
    rc=$?
    case "$rc" in
      2)
        log "$label container '$name' is not present; skipping"
        return 0
        ;;
      3)
        log "$label container '$name' is not running; skipping"
        return 0
        ;;
      *)
        return "$rc"
        ;;
    esac
  fi

  log "reloading $label in container '$name'"
  if ! timeout "$CERTBOT_RELOAD_TIMEOUT_SECONDS" docker exec "$name" "$@"; then
    log "$label reload failed for container '$name'"
    return 1
  fi
}

main() {
  require_command docker
  require_command timeout
  validate_uint CERTBOT_RELOAD_TIMEOUT_SECONDS "$CERTBOT_RELOAD_TIMEOUT_SECONDS" 1 300

  local failures=0
  reload_target Nginx "$CERTBOT_NGINX_CONTAINER" nginx -s reload || failures=$((failures + 1))
  reload_target Apache "$CERTBOT_APACHE_CONTAINER" apachectl graceful || failures=$((failures + 1))

  (( failures == 0 )) || fatal "$failures configured reload target(s) failed"
}

main "$@"
