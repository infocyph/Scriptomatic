#!/usr/bin/env sh
# /usr/local/bin/node-entry
set -eu

APP_DIR="${APP_DIR:-/app}"
cd "$APP_DIR"

###############################################################################
# Alpine Root CA bootstrap (runtime)
###############################################################################
ROOTCA="${ROOTCA_PATH:-/etc/share/rootCA/rootCA.pem}"
STAMP="/tmp/.rootca_installed"

if [ -r "$ROOTCA" ]; then
  export NODE_EXTRA_CA_CERTS="$ROOTCA"
  if [ ! -f "$STAMP" ] && command -v update-ca-certificates >/dev/null 2>&1; then
    sudo install -m 0644 "$ROOTCA" /usr/local/share/ca-certificates/rootCA.crt 2>/dev/null || true
    sudo update-ca-certificates >/dev/null 2>&1 || true
    : >"$STAMP" || true
  fi
fi

# If user provided a command (docker run image <cmd>), run it directly
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

###############################################################################
# Respect override if user explicitly sets NODE_CMD
###############################################################################
if [ -n "${NODE_CMD:-}" ]; then
  exec sh -lc "$NODE_CMD"
fi

###############################################################################
# Defaults used by common dev servers (Vite, etc.)
###############################################################################
: "${HOST:=0.0.0.0}"
: "${PORT:=3000}"

: "${NPM_AUDIT:=0}"
: "${NPM_FUND:=0}"

npm_flags=""
[ "$NPM_AUDIT" = "1" ] || npm_flags="$npm_flags --no-audit"
[ "$NPM_FUND" = "1" ] || npm_flags="$npm_flags --no-fund"

if [ ! -d node_modules ]; then
  if [ -f package-lock.json ]; then
    npm ci $npm_flags
  else
    npm install $npm_flags
  fi
fi

has_script() {
  # Usage: has_script dev|start
  node -e "const p=require('./package.json');process.exit(p.scripts&&p.scripts['$1']?0:1)" 2>/dev/null
}

if has_script dev; then
  exec npm run dev -- --host "$HOST" --port "$PORT"
fi

if has_script start; then
  exec npm start
fi

[ -f server.js ] && exec node server.js
[ -f index.js ] && exec node index.js

echo "No runnable script found (dev/start missing; server.js/index.js not found)." >&2
echo "Set NODE_CMD to override, e.g.: NODE_CMD='node app.js' or 'npm run serve'." >&2
command -v bash >/dev/null 2>&1 && exec bash
exec sh
