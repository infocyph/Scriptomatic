#!/bin/sh
set -eu

# ---- Root CA bootstrap (Alpine) --------------------------------------------
ROOTCA="${ROOTCA_PATH:-/etc/share/rootCA/rootCA.pem}"
STAMP="/tmp/.rootca_installed"

if [ -r "$ROOTCA" ] && [ ! -f "$STAMP" ]; then
  install -m 0644 "$ROOTCA" /usr/local/share/ca-certificates/rootCA.crt 2>/dev/null || true
  update-ca-certificates >/dev/null 2>&1 || true
  : >"$STAMP" || true
fi
# ---------------------------------------------------------------------------

exec docker-php-entrypoint "$@"
