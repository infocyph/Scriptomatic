#!/usr/bin/env sh
set -eu

APP_DIR="${APP_DIR:-/app}"
: "${NODE_LOG_ENABLED:=0}"
: "${NODE_LOG_DIR:=/var/log/node-app}"
: "${NODE_ACCESS_LOG_FILE:=access.log}"
: "${NODE_ERROR_LOG_FILE:=error.log}"
: "${NODE_ACCESS_LOG:=${NODE_LOG_DIR}/${NODE_ACCESS_LOG_FILE}}"
: "${NODE_ERROR_LOG:=${NODE_LOG_DIR}/${NODE_ERROR_LOG_FILE}}"
: "${NODE_KEEPALIVE_ON_FAIL:=0}"
: "${NODE_AUTO_INSTALL:=0}"
: "${NODE_ALLOW_LOCKFILE_FALLBACK:=0}"
: "${HOST:=0.0.0.0}"
: "${PORT:=3000}"
: "${NPM_AUDIT:=0}"
: "${NPM_FUND:=0}"
: "${ROOTCA_PATH:=/etc/share/rootCA/rootCA.pem}"
: "${ROOTCA_DEST:=/usr/local/share/ca-certificates/rootCA.crt}"
: "${ROOTCA_REQUIRED:=0}"

warn() {
  printf '[node-entry] %s\n' "$*" >&2
}

validate_flag() {
  case "$2" in
    0|1) ;;
    *) warn "$1 must be 0 or 1"; exit 2 ;;
  esac
}

validate_flag NODE_LOG_ENABLED "$NODE_LOG_ENABLED"
validate_flag NODE_KEEPALIVE_ON_FAIL "$NODE_KEEPALIVE_ON_FAIL"
validate_flag NODE_AUTO_INSTALL "$NODE_AUTO_INSTALL"
validate_flag NODE_ALLOW_LOCKFILE_FALLBACK "$NODE_ALLOW_LOCKFILE_FALLBACK"
validate_flag NPM_AUDIT "$NPM_AUDIT"
validate_flag NPM_FUND "$NPM_FUND"
validate_flag ROOTCA_REQUIRED "$ROOTCA_REQUIRED"

case "$PORT" in
  ''|*[!0-9]*) warn "PORT must be numeric"; exit 2 ;;
esac
[ "$PORT" -ge 1 ] 2>/dev/null && [ "$PORT" -le 65535 ] 2>/dev/null || {
  warn "PORT must be between 1 and 65535"
  exit 2
}

[ -d "$APP_DIR" ] || {
  warn "APP_DIR does not exist: $APP_DIR"
  exit 1
}
cd "$APP_DIR"
export HOST PORT

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

sha256_file() {
  if has_cmd sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  elif has_cmd openssl; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    return 127
  fi
}

run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif has_cmd sudo; then
    sudo -- "$@"
  else
    return 126
  fi
}

install_root_ca_if_changed() {
  [ -r "$ROOTCA_PATH" ] || return 0

  src_hash="$(sha256_file "$ROOTCA_PATH" 2>/dev/null || true)"
  [ -n "$src_hash" ] || {
    warn "cannot hash ROOTCA; sha256sum or openssl is required"
    [ "$ROOTCA_REQUIRED" = 1 ] && return 1
    return 0
  }

  dst_hash=""
  [ ! -r "$ROOTCA_DEST" ] || dst_hash="$(sha256_file "$ROOTCA_DEST" 2>/dev/null || true)"
  [ "$src_hash" != "$dst_hash" ] || {
    export NODE_EXTRA_CA_CERTS="$ROOTCA_PATH"
    return 0
  }

  if ! run_privileged install -m 0644 "$ROOTCA_PATH" "$ROOTCA_DEST"; then
    warn "unable to install ROOTCA at $ROOTCA_DEST"
    [ "$ROOTCA_REQUIRED" = 1 ] && return 1
    return 0
  fi

  if has_cmd update-ca-certificates && ! run_privileged update-ca-certificates >/dev/null 2>&1; then
    warn "update-ca-certificates failed"
    [ "$ROOTCA_REQUIRED" = 1 ] && return 1
  fi
  export NODE_EXTRA_CA_CERTS="$ROOTCA_PATH"
}

ensure_log_paths() {
  mkdir -p "$(dirname "$NODE_ACCESS_LOG")" "$(dirname "$NODE_ERROR_LOG")"
  touch "$NODE_ACCESS_LOG" "$NODE_ERROR_LOG"
}

run_cmd() {
  if [ "$NODE_LOG_ENABLED" = 1 ]; then
    ensure_log_paths
    exec sh -c '
      access=$1
      error=$2
      shift 2
      exec "$@" >>"$access" 2>>"$error"
    ' sh "$NODE_ACCESS_LOG" "$NODE_ERROR_LOG" "$@"
  fi
  exec "$@"
}

has_script() {
  [ -f package.json ] || return 1
  node -e 'const p=require("./package.json");process.exit(p.scripts&&p.scripts[process.argv[1]]?0:1)' "$1" 2>/dev/null
}

detect_framework() {
  [ -f package.json ] || {
    printf 'generic\n'
    return
  }
  node -e '
    const p=require("./package.json");
    const d={...(p.dependencies||{}),...(p.devDependencies||{})};
    if(d.next) return console.log("next");
    if(d.nuxt||d.nuxi) return console.log("nuxt");
    if(d["@nestjs/core"]||d["@nestjs/cli"]) return console.log("nest");
    if(d.vite) return console.log("vite");
    console.log("generic");
  ' 2>/dev/null || printf 'generic\n'
}

npm_install_flags() {
  flags=''
  [ "$NPM_AUDIT" = 1 ] || flags="$flags --no-audit"
  [ "$NPM_FUND" = 1 ] || flags="$flags --no-fund"
  printf '%s' "$flags"
}

run_with_optional_fallback() {
  if "$@"; then
    return 0
  fi
  [ "$NODE_ALLOW_LOCKFILE_FALLBACK" = 1 ] || return 1
  return 2
}

install_deps() {
  [ "$NODE_AUTO_INSTALL" = 1 ] || return 0
  [ -f package.json ] || return 0
  [ -d node_modules ] && return 0

  warn "node_modules not found; NODE_AUTO_INSTALL=1 permits dependency installation"

  if [ -f pnpm-lock.yaml ]; then
    has_cmd pnpm || {
      warn "pnpm-lock.yaml exists but pnpm is unavailable"
      return 1
    }
    if pnpm install --frozen-lockfile; then return 0; fi
    [ "$NODE_ALLOW_LOCKFILE_FALLBACK" = 1 ] || return 1
    warn "strict pnpm install failed; explicit fallback enabled"
    pnpm install
    return
  fi

  if [ -f yarn.lock ]; then
    has_cmd yarn || {
      warn "yarn.lock exists but yarn is unavailable"
      return 1
    }
    if yarn install --frozen-lockfile; then return 0; fi
    [ "$NODE_ALLOW_LOCKFILE_FALLBACK" = 1 ] || return 1
    warn "strict yarn install failed; explicit fallback enabled"
    yarn install
    return
  fi

  flags="$(npm_install_flags)"
  if [ -f package-lock.json ]; then
    # shellcheck disable=SC2086 # flags are internally constructed fixed npm options.
    if npm ci $flags; then return 0; fi
    [ "$NODE_ALLOW_LOCKFILE_FALLBACK" = 1 ] || return 1
    warn "npm ci failed; explicit fallback enabled"
    # shellcheck disable=SC2086
    npm install $flags
    return
  fi

  # shellcheck disable=SC2086
  npm install $flags
}

select_and_run_app() {
  if [ -n "${NODE_CMD:-}" ]; then
    warn "executing trusted NODE_CMD shell expression"
    run_cmd sh -lc "$NODE_CMD"
  fi

  if has_script dev; then
    framework="$(detect_framework)"
    case "$framework" in
      next) run_cmd env HOSTNAME="$HOST" npm run dev -- --hostname "$HOST" --port "$PORT" ;;
      nuxt) run_cmd env NUXT_HOST="$HOST" NUXT_PORT="$PORT" npm run dev -- --host "$HOST" --port "$PORT" ;;
      vite) run_cmd npm run dev -- --host "$HOST" --port "$PORT" ;;
      nest|generic) run_cmd npm run dev ;;
    esac
  fi

  if has_script start; then
    run_cmd npm start
  fi
  [ ! -f server.js ] || run_cmd node server.js
  [ ! -f index.js ] || run_cmd node index.js

  warn "no runnable app found (checked NODE_CMD, dev/start scripts, server.js, index.js)"
  if [ "$NODE_KEEPALIVE_ON_FAIL" = 1 ]; then
    warn "NODE_KEEPALIVE_ON_FAIL=1; keeping container alive without an app"
    while :; do sleep 3600; done
  fi
  return 1
}

install_root_ca_if_changed

if [ "$#" -gt 0 ]; then
  run_cmd "$@"
fi

install_deps || {
  warn "dependency installation failed"
  exit 1
}
select_and_run_app
