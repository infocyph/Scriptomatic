#!/usr/bin/env sh
# /usr/local/bin/node-entry
set -eu

APP_DIR="${APP_DIR:-/app}"
cd "$APP_DIR"
# 20260318929
###############################################################################
# Default runtime logs for all launched commands
###############################################################################
: "${NODE_LOG_ENABLED:=1}"
: "${NODE_LOG_DIR:=/var/log/node-app}"
: "${NODE_ACCESS_LOG_FILE:=access.log}"
: "${NODE_ERROR_LOG_FILE:=error.log}"
: "${NODE_ACCESS_LOG:=${NODE_LOG_DIR}/${NODE_ACCESS_LOG_FILE}}"
: "${NODE_ERROR_LOG:=${NODE_LOG_DIR}/${NODE_ERROR_LOG_FILE}}"
: "${NODE_KEEPALIVE_ON_FAIL:=1}"

ensure_log_paths() {
  mkdir -p "$(dirname "$NODE_ACCESS_LOG")" "$(dirname "$NODE_ERROR_LOG")" 2>/dev/null || true
  touch "$NODE_ACCESS_LOG" "$NODE_ERROR_LOG" 2>/dev/null || true
}

run_cmd() {
  if [ "$NODE_LOG_ENABLED" = "1" ]; then
    ensure_log_paths
    exec sh -c '
      access="$1"
      error="$2"
      shift 2
      exec "$@" >>"$access" 2>>"$error"
    ' sh "$NODE_ACCESS_LOG" "$NODE_ERROR_LOG" "$@"
  fi
  exec "$@"
}

try_cmd() {
  if [ "$NODE_LOG_ENABLED" = "1" ]; then
    ensure_log_paths
    "$@" >>"$NODE_ACCESS_LOG" 2>>"$NODE_ERROR_LOG"
  else
    "$@"
  fi
}

ensure_npm_cache_permissions() {
  cache_dir="${NPM_CONFIG_CACHE:-$HOME/.npm}"
  mkdir -p "$cache_dir" 2>/dev/null || true

  if command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$(id -u):$(id -g)" "$cache_dir" 2>/dev/null || true
  else
    chown -R "$(id -u):$(id -g)" "$cache_dir" 2>/dev/null || true
  fi
}

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
  run_cmd "$@"
fi

###############################################################################
# Defaults used by common dev servers
###############################################################################
: "${HOST:=0.0.0.0}"
: "${PORT:=3000}"
: "${NPM_AUDIT:=0}"
: "${NPM_FUND:=0}"

npm_flags=""
[ "$NPM_AUDIT" = "1" ] || npm_flags="$npm_flags --no-audit"
[ "$NPM_FUND" = "1" ] || npm_flags="$npm_flags --no-fund"

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

has_script() {
  node -e "const p=require('./package.json');process.exit(p.scripts&&p.scripts['$1']?0:1)" 2>/dev/null
}

detect_framework() {
  [ -f package.json ] || {
    echo generic
    return
  }

  node -e '
    const p = require("./package.json");
    const deps = { ...(p.dependencies || {}), ...(p.devDependencies || {}) };

    if (deps.next) return console.log("next");
    if (deps.nuxt || deps.nuxi) return console.log("nuxt");
    if (deps["@nestjs/core"] || deps["@nestjs/cli"]) return console.log("nest");
    if (deps.vite) return console.log("vite");

    console.log("generic");
  ' 2>/dev/null || echo generic
}

install_deps() {
  [ -f package.json ] || return 0
  [ -d node_modules ] && return 0

  echo "[node-entry] node_modules not found, installing dependencies..." >&2

  ensure_npm_cache_permissions

  if [ -f pnpm-lock.yaml ]; then
    if has_cmd corepack; then corepack enable >/dev/null 2>&1 || true; fi
    if has_cmd pnpm; then
      pnpm install --frozen-lockfile || pnpm install
      return 0
    fi
  fi

  if [ -f yarn.lock ]; then
    if has_cmd corepack; then corepack enable >/dev/null 2>&1 || true; fi
    if has_cmd yarn; then
      yarn install --frozen-lockfile || yarn install
      return 0
    fi
  fi

  if [ -f package-lock.json ]; then
    npm ci $npm_flags || npm install $npm_flags
    return 0
  fi

  npm install $npm_flags
}

run_dev() {
  if ! has_script dev; then
    return 0
  fi

  echo "[node-entry] attempting dev script..." >&2

  framework="$(detect_framework)"

  case "$framework" in
  next)
    if try_cmd env HOSTNAME="$HOST" PORT="$PORT" npm run dev -- --hostname "$HOST" --port "$PORT"; then
      exit 0
    fi
    ;;
  nuxt)
    if try_cmd env NUXT_HOST="$HOST" HOST="$HOST" NUXT_PORT="$PORT" PORT="$PORT" npm run dev; then
      exit 0
    fi
    ;;
  vite)
    if try_cmd npm run dev -- --host "$HOST" --port "$PORT"; then
      exit 0
    fi
    ;;
  nest)
    if try_cmd env HOST="$HOST" PORT="$PORT" npm run dev; then
      exit 0
    fi
    ;;
  *)
    if try_cmd npm run dev -- --host "$HOST" --port "$PORT"; then
      exit 0
    fi

    if try_cmd env HOST="$HOST" PORT="$PORT" npm run dev; then
      exit 0
    fi
    ;;
  esac

  echo "[node-entry] dev script failed; keeping container alive and trying fallbacks." >&2
}

run_start() {
  if has_script start; then
    echo "[node-entry] attempting start script..." >&2
    if try_cmd npm start; then
      exit 0
    fi
    echo "[node-entry] start script failed; keeping container alive and trying fallbacks." >&2
  fi
}

install_deps || echo "[node-entry] dependency install failed; continuing to fallbacks." >&2

###############################################################################
# Respect override if user explicitly sets NODE_CMD
###############################################################################
if [ -n "${NODE_CMD:-}" ]; then
  echo "[node-entry] running custom NODE_CMD..." >&2
  run_cmd env \
    HOST="$HOST" \
    PORT="$PORT" \
    HOSTNAME="$HOST" \
    NUXT_HOST="$HOST" \
    NUXT_PORT="$PORT" \
    sh -lc "$NODE_CMD"
fi

run_dev
run_start

if [ -f server.js ]; then
  run_cmd node server.js
fi

if [ -f index.js ]; then
  run_cmd node index.js
fi

echo "[node-entry] No runnable app started." >&2
echo "[node-entry] Checked: npm scripts dev/start, server.js, index.js." >&2
echo "[node-entry] Set NODE_CMD to override, e.g. NODE_CMD='node app.js'." >&2

if [ "${NODE_KEEPALIVE_ON_FAIL}" = "1" ]; then
  echo "[node-entry] Keeping container alive." >&2
  while :; do
    sleep 3600
  done
fi

exit 1