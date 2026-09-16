#!/usr/bin/env sh
set -eu

ROOTCA="${ROOTCA_PATH:-/etc/share/rootCA/rootCA.pem}"
ROOTCA_DEST="${ROOTCA_DEST:-/usr/local/share/ca-certificates/rootCA.crt}"
ROOTCA_REQUIRED="${ROOTCA_REQUIRED:-0}"

warn() {
  printf 'php-entry: %s\n' "$*" >&2
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    return 127
  fi
}

run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo -- "$@"
  else
    return 126
  fi
}

install_root_ca_if_changed() {
  [ -r "$ROOTCA" ] || return 0

  src_hash="$(sha256_file "$ROOTCA" 2>/dev/null || true)"
  [ -n "$src_hash" ] || {
    warn "cannot hash ROOTCA; sha256sum or openssl is required"
    [ "$ROOTCA_REQUIRED" = "1" ] && return 1
    return 0
  }

  dst_hash=""
  if [ -r "$ROOTCA_DEST" ]; then
    dst_hash="$(sha256_file "$ROOTCA_DEST" 2>/dev/null || true)"
  fi

  if [ "$src_hash" = "$dst_hash" ]; then
    export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"
    return 0
  fi

  if ! run_privileged install -m 0644 "$ROOTCA" "$ROOTCA_DEST"; then
    warn "unable to install ROOTCA at $ROOTCA_DEST"
    [ "$ROOTCA_REQUIRED" = "1" ] && return 1
    return 0
  fi

  if command -v update-ca-certificates >/dev/null 2>&1; then
    if ! run_privileged update-ca-certificates >/dev/null 2>&1; then
      warn "update-ca-certificates failed"
      [ "$ROOTCA_REQUIRED" = "1" ] && return 1
    fi
  fi

  export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"
}

install_root_ca_if_changed

command -v docker-php-entrypoint >/dev/null 2>&1 || {
  warn "docker-php-entrypoint not found"
  exit 127
}
exec docker-php-entrypoint "$@"
