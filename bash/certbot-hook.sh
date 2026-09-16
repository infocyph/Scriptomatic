#!/usr/bin/env bash
set -u

command -v docker >/dev/null 2>&1 || {
  echo "reload-services: docker is not installed" >&2
  exit 127
}

status=0

reload_if_running() {
  local container="$1"
  shift

  if [[ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)" != "true" ]]; then
    return 0
  fi

  echo "Reloading ${container}..."
  if ! docker exec "$container" "$@"; then
    echo "reload-services: failed to reload ${container}" >&2
    status=1
  fi
}

reload_if_running NGINX nginx -s reload
reload_if_running APACHE apachectl graceful

exit "$status"
