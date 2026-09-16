#!/bin/sh
set -eu

ROOTCA="${ROOTCA_PATH:-/etc/share/rootCA/rootCA.pem}"
STAMP="${SCRIPTOMATIC_ROOTCA_STAMP:-/tmp/.rootca_installed}"

fingerprint_ca() {
  cksum < "$ROOTCA" | awk '{print $1 ":" $2}'
}

run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

install_root_ca() {
  [ -r "$ROOTCA" ] || return 0
  command -v cksum >/dev/null 2>&1 || return 0
  command -v update-ca-certificates >/dev/null 2>&1 || return 0

  expected="$(fingerprint_ca)"
  if [ -r "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null || true)" = "$expected" ]; then
    export NODE_EXTRA_CA_CERTS="${NODE_EXTRA_CA_CERTS:-$ROOTCA}"
    return 0
  fi

  if run_privileged install -m 0644 "$ROOTCA" /usr/local/share/ca-certificates/rootCA.crt >/dev/null 2>&1 && \
     run_privileged update-ca-certificates >/dev/null 2>&1; then
    umask 077
    printf '%s\n' "$expected" > "$STAMP" 2>/dev/null || true
  else
    echo "php-entry: unable to install local root CA; continuing" >&2
  fi
}

install_root_ca
exec docker-php-entrypoint "$@"
