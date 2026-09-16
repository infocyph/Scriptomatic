#!/usr/bin/env sh
# /usr/local/bin/node-entry
set -eu

APP_DIR="${APP_DIR:-/app}"
cd "$APP_DIR"

###############################################################################
# Default runtime logs
###############################################################################
: "${NODE_LOG_ENABLED:=1}"
: "${NODE_LOG_DIR:=/var/log/node-app}"
: "${NODE_ACCESS_LOG_FILE:=access.log}"
: "${NODE_ERROR_LOG_FILE:=error.log}"
: "${NODE_ACCESS_LOG:=${NODE_LOG_DIR}/${NODE_ACCESS_LOG_FILE}}"
: "${NODE_ERROR_LOG:=${NODE_LOG_DIR}/${NODE_ERROR_LOG_FILE}}"
: "${NODE_KEEPALIVE_ON_FAIL:=1}"

ensure_log_paths() {
  access_dir="$(dirname "$NODE_ACCESS_LOG")"
  error_dir="$(dirname "$NODE_ERROR_LOG")"

  mkdir -p "$access_dir" "$error_dir" 2>/dev/null || {
    echo "[node-entry] unable to create log directory." >&2
    return 1
  }
  touch "$NODE_ACCESS_LOG" "$NODE_ERROR_LOG" 2>/dev/null || {
    echo "[node-entry] unable to create log files." >&2
    return 1
  }
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

trial_pid=""
trial_signal=0
forward_trial_signal() {
  trial_signal=1
  if [ -n "$trial_pid" ]; then
    kill -TERM "$trial_pid" 2>/dev/null || true
  fi
}

run_trial() {
  trial_pid=""
  trial_signal=0
  trap 'forward_trial_signal' HUP INT TERM

  if [ "$NODE_LOG_ENABLED" = "1" ]; then
    ensure_log_paths || {
      trap - HUP INT TERM
      return 1
    }
    "$@" >>"$NODE_ACCESS_LOG" 2>>"$NODE_ERROR_LOG" &
  else
    "$@" &
  fi
  trial_pid=$!

  trial_status=0
  wait "$trial_pid" || trial_status=$?
  trial_pid=""
  trap - HUP INT TERM

  if [ "$trial_signal" = "1" ]; then
    exit "$trial_status"
  fi

  return "$trial_status"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

has_script() {
  [ -f package.json ] || return 1
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

ensure_npm_cache_permissions() {
  cache_dir="${NPM_CONFIG_CACHE:-$HOME/.npm}"
  mkdir -p "$cache_dir" 2>/dev/null || true

  if [ "$(id -u)" = "0" ]; then
    chown -R "$(id -u):$(id -g)" "$cache_dir" 2>/dev/null || true
  elif command -v sudo >/dev/null 2>&1; then
    sudo -n chown -R "$(id -u):$(id -g)" "$cache_dir" 2>/dev/null || true
  fi
}

###############################################################################
# Alpine Root CA bootstrap
###############################################################################
ROOTCA="${ROOTCA_PATH:-/etc/share/rootCA/rootCA.pem}"
CA_DEST="/usr/local/share/ca-certificates/rootCA.crt"

install_root_ca() {
  [ -r "$ROOTCA" ] || return 0
  command -v update-ca-certificates >/dev/null 2>&1 || return 0

  if [ -r "$CA_DEST" ] && cmp -s "$ROOTCA" "$CA_DEST" 2>/dev/null; then
    return 0
  fi

  if [ "$(id -u)" = "0" ]; then
    install -m 0644 "$ROOTCA" "$CA_DEST" 2>/dev/null || return 0
    update-ca-certificates >/dev/null 2>&1 || true
    return 0
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo -n install -m 0644 "$ROOTCA" "$CA_DEST" 2>/dev/null || return 0
    sudo -n update-ca-certificates >/dev/null 2>&1 || true
  fi
}

if [ -r "$ROOTCA" ]; then
  export NODE_EXTRA_CA_CERTS="$ROOTCA"
  install_root_ca
fi

###############################################################################
# Direct command override
###############################################################################
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

export HOST PORT

npm_install_with_flags() {
  npm_action="$1"
  shift
  set -- "$@"
  [ "$NPM_AUDIT" = "1" ] || set -- "$@" --no-audit
  [ "$NPM_FUND" = "1" ] || set -- "$@" --no-fund
  npm "$npm_action" "$@"
}

install_deps() {
  [ -f package.json ] || return 0
  [ -d node_modules ] && return 0

  echo "[node-entry] node_modules not found, installing dependencies..." >&2

  ensure_npm_cache_permissions

  if [ -f pnpm-lock.yaml ]; then
    if has_cmd corepack; then
      corepack enable >/dev/null 2>&1 || true
    fi
    if has_cmd pnpm; then
      pnpm install --frozen-lockfile || pnpm install
      return 0
    fi
  fi

  if [ -f yarn.lock ]; then
    if has_cmd corepack; then
      corepack enable >/dev/null 2>&1 || true
    fi
    if has_cmd yarn; then
      yarn install --frozen-lockfile || yarn install
      return 0
    fi
  fi

  if [ -f package-lock.json ]; then
    npm_install_with_flags ci || npm_install_with_flags install
    return 0
  fi

  npm_install_with_flags install
}

RUN_HANDLED=0
run_dev() {
  if ! has_script dev; then
    return 0
  fi

  echo "[node-entry] attempting dev script..." >&2

  framework="$(detect_framework)"

  case "$framework" in
  next)
    run_cmd env HOSTNAME="$HOST" npm run dev -- --hostname "$HOST" --port "$PORT"
    ;;

  nuxt)
    run_cmd env NUXT_HOST="$HOST" NUXT_PORT="$PORT" npm run dev -- --host "$HOST" --port "$PORT"
    ;;

  vite)
    run_cmd npm run dev -- --host "$HOST" --port "$PORT"
    ;;

  nest)
    run_cmd npm run dev
    ;;

  *)
    if run_trial npm run dev -- --host "$HOST" --port "$PORT"; then
      RUN_HANDLED=1
      return 0
    fi

    if run_trial npm run dev; then
      RUN_HANDLED=1
      return 0
    fi

    echo "[node-entry] dev script failed; keeping container alive and trying fallbacks." >&2
    ;;
  esac
}

run_start() {
  if has_script start; then
    echo "[node-entry] attempting start script..." >&2
    run_cmd npm start
  fi
}

install_deps || echo "[node-entry] dependency install failed; continuing to fallbacks." >&2

###############################################################################
# Respect explicit NODE_CMD
###############################################################################
if [ -n "${NODE_CMD:-}" ]; then
  echo "[node-entry] running custom NODE_CMD..." >&2
  run_cmd env \
    HOSTNAME="$HOST" \
    NUXT_HOST="$HOST" \
    NUXT_PORT="$PORT" \
    sh -lc "$NODE_CMD"
fi

run_dev
[ "$RUN_HANDLED" = "1" ] && exit 0
run_start

[ -f server.js ] && run_cmd node server.js
[ -f index.js ] && run_cmd node index.js

echo "[node-entry] No runnable app started." >&2
echo "[node-entry] Checked: npm scripts dev/start, server.js, index.js." >&2
echo "[node-entry] Set NODE_CMD to override, e.g. NODE_CMD='node app.js'." >&2

if [ "$NODE_KEEPALIVE_ON_FAIL" = "1" ]; then
  echo "[node-entry] Keeping container alive." >&2
  while :; do
    sleep 3600
  done
fi

exit 1
