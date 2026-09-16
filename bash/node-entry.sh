#!/usr/bin/env sh
set -eu

APP_DIR="${APP_DIR:-/app}"
: "${NODE_LOG_ENABLED:=1}"
: "${NODE_LOG_DIR:=/var/log/node-app}"
: "${NODE_ACCESS_LOG_FILE:=access.log}"
: "${NODE_ERROR_LOG_FILE:=error.log}"
: "${NODE_ACCESS_LOG:=${NODE_LOG_DIR}/${NODE_ACCESS_LOG_FILE}}"
: "${NODE_ERROR_LOG:=${NODE_LOG_DIR}/${NODE_ERROR_LOG_FILE}}"
: "${NODE_KEEPALIVE_ON_FAIL:=1}"
: "${HOST:=0.0.0.0}"
: "${PORT:=3000}"
: "${NPM_AUDIT:=0}"
: "${NPM_FUND:=0}"
: "${ROOTCA_PATH:=/etc/share/rootCA/rootCA.pem}"

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
validate_flag NPM_AUDIT "$NPM_AUDIT"
validate_flag NPM_FUND "$NPM_FUND"

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

  # Preserve the original useful behavior: Node can trust the mounted CA even
  # when system trust-store installation is unavailable/best-effort.
  export NODE_EXTRA_CA_CERTS="$ROOTCA_PATH"

  src_hash="$(sha256_file "$ROOTCA_PATH" 2>/dev/null || true)"
  [ -n "$src_hash" ] || {
    warn "cannot hash ROOTCA; sha256sum or openssl is required"
    return 0
  }

  dst_hash=""
  [ ! -r "/usr/local/share/ca-certificates/rootCA.crt" ] || dst_hash="$(sha256_file "/usr/local/share/ca-certificates/rootCA.crt" 2>/dev/null || true)"
  [ "$src_hash" != "$dst_hash" ] || return 0

  if ! run_privileged install -m 0644 "$ROOTCA_PATH" "/usr/local/share/ca-certificates/rootCA.crt"; then
    warn "unable to install ROOTCA at /usr/local/share/ca-certificates/rootCA.crt"
    return 0
  fi

  if has_cmd update-ca-certificates && ! run_privileged update-ca-certificates >/dev/null 2>&1; then
    warn "update-ca-certificates failed"
    :
  fi
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

try_cmd() {
  if [ "$NODE_LOG_ENABLED" = 1 ]; then
    ensure_log_paths
    "$@" >>"$NODE_ACCESS_LOG" 2>>"$NODE_ERROR_LOG"
  else
    "$@"
  fi
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

install_deps() {
  [ -f package.json ] || return 0
  [ -d node_modules ] && return 0

  warn "node_modules not found, installing dependencies..."

  if [ -f pnpm-lock.yaml ]; then
    has_cmd pnpm || {
      warn "pnpm-lock.yaml exists but pnpm is unavailable"
      return 1
    }
    if pnpm install --frozen-lockfile; then return 0; fi
    warn "strict pnpm install failed; trying compatibility fallback"
    pnpm install
    return
  fi

  if [ -f yarn.lock ]; then
    has_cmd yarn || {
      warn "yarn.lock exists but yarn is unavailable"
      return 1
    }
    if yarn install --frozen-lockfile; then return 0; fi
    warn "strict yarn install failed; trying compatibility fallback"
    yarn install
    return
  fi

  flags="$(npm_install_flags)"
  if [ -f package-lock.json ]; then
    # shellcheck disable=SC2086 # internally constructed fixed npm flags.
    if npm ci $flags; then return 0; fi
    warn "npm ci failed; trying compatibility fallback"
    # shellcheck disable=SC2086
    npm install $flags
    return
  fi

  # shellcheck disable=SC2086
  npm install $flags
}

run_dev() {
  has_script dev || return 1

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
    generic)
      # Preserve the old two-form fallback intent, but do not execute a
      # successful dev command a second time.
      if try_cmd npm run dev -- --host "$HOST" --port "$PORT"; then
        return 0
      fi
      if try_cmd npm run dev; then
        return 0
      fi
      warn "dev script failed; trying fallbacks"
      return 1
      ;;
  esac
}

run_start() {
  has_script start || return 1
  run_cmd npm start
}

install_root_ca_if_changed

if [ "$#" -gt 0 ]; then
  run_cmd "$@"
fi

if ! install_deps; then
  warn "dependency install failed; continuing to application fallbacks"
fi

if [ -n "${NODE_CMD:-}" ]; then
  warn "running custom NODE_CMD"
  run_cmd env HOSTNAME="$HOST" NUXT_HOST="$HOST" NUXT_PORT="$PORT" sh -lc "$NODE_CMD"
fi

if run_dev; then
  exit 0
fi
if run_start; then
  exit 0
fi
[ ! -f server.js ] || run_cmd node server.js
[ ! -f index.js ] || run_cmd node index.js

warn "No runnable app started."
warn "Checked: npm scripts dev/start, server.js, index.js."
warn "Set NODE_CMD to override, e.g. NODE_CMD='node app.js'."

if [ "$NODE_KEEPALIVE_ON_FAIL" = 1 ]; then
  warn "Keeping container alive."
  while :; do
    sleep 3600
  done
fi

exit 1
