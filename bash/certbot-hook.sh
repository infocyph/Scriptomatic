#!/usr/bin/env bash

container_running() {
  [[ "$(docker container inspect --format '{{.State.Running}}' "$1" 2>/dev/null || true)" == "true" ]]
}

if container_running NGINX; then
  echo "Reloading Nginx..."
  docker exec NGINX nginx -s reload
fi

if container_running APACHE; then
  echo "Reloading Apache..."
  docker exec APACHE apachectl graceful
fi
