#!/usr/bin/env bash
set -u

RENEW_INTERVAL="${CERTBOT_RENEW_INTERVAL:-12h}"
DEPLOY_HOOK="${CERTBOT_DEPLOY_HOOK:-/usr/local/bin/reload-services}"
RENEW_ONCE="${CERTBOT_RENEW_ONCE:-0}"

command -v certbot >/dev/null 2>&1 || {
  echo "certbot-renew: certbot is not installed" >&2
  exit 127
}

if [[ ! -x "$DEPLOY_HOOK" ]]; then
  echo "certbot-renew: deploy hook is not executable: $DEPLOY_HOOK" >&2
  exit 1
fi

stopping=0
trap 'stopping=1' INT TERM

while [[ "$stopping" -eq 0 ]]; do
  if ! certbot renew --quiet --deploy-hook "$DEPLOY_HOOK"; then
    echo "certbot-renew: renewal attempt failed; retrying after $RENEW_INTERVAL" >&2
  fi

  [[ "$RENEW_ONCE" == "1" ]] && break
  [[ "$stopping" -eq 0 ]] || break

  sleep "$RENEW_INTERVAL" &
  sleep_pid=$!
  wait "$sleep_pid" || true
done

exit 0
