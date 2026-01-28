#!/usr/bin/env sh
# /usr/local/bin/node-entry
# Fast, resilient dev entry:
# - Installs deps if node_modules missing
# - Prefers dev script, then start, then server.js/index.js
# - Skips audit/fund by default (opt-in via NPM_AUDIT=1 / NPM_FUND=1)
set -eu

APP_DIR="${APP_DIR:-/app}"
cd "$APP_DIR"

# Respect override if user explicitly sets NODE_CMD
if [ -n "${NODE_CMD:-}" ]; then
  exec sh -lc "$NODE_CMD"
fi

# npm noise + speed knobs (can be overridden by env)
: "${NPM_AUDIT:=0}"
: "${NPM_FUND:=0}"

npm_flags=""
[ "$NPM_AUDIT" = "1" ] || npm_flags="$npm_flags --no-audit"
[ "$NPM_FUND"  = "1" ] || npm_flags="$npm_flags --no-fund"

# Install deps if missing
if [ ! -d node_modules ]; then
  if [ -f package-lock.json ]; then
    npm ci $npm_flags
  else
    npm install $npm_flags
  fi
fi

# Helper: check script exists in package.json
has_script() {
  # Usage: has_script dev|start
  node -e "const p=require('./package.json');process.exit(p.scripts&&p.scripts['$1']?0:1)" 2>/dev/null
}

if has_script dev; then
  exec npm run dev
fi

if has_script start; then
  exec npm start
fi

[ -f server.js ] && exec node server.js
[ -f index.js ] && exec node index.js

echo "No runnable script found (dev/start missing; server.js/index.js not found)."
echo "Set NODE_CMD to override, e.g.: NODE_CMD='node app.js' or 'npm run serve'."
if command -v bash >/dev/null 2>&1; then
  exec bash
fi
exec sh
