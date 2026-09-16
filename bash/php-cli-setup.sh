#!/usr/bin/env bash
# php-cli-setup.sh USERNAME PHP_VERSION
set -Eeuo pipefail
shopt -s extglob

USERNAME="${1:?username required}"
PHP_VERSION="${2:?php-version required}"

LEGACY_UID_ENV="$(printenv UID 2>/dev/null || true)"
TARGET_UID="${LEGACY_UID_ENV:-1000}"
TARGET_GID="${GID:-1000}"
: "${LINUX_PKG:=}"
: "${LINUX_PKG_VERSIONED:=}"
: "${PHP_EXT:=}"
: "${PHP_EXT_VERSIONED:=}"
: "${MSMTP_FROM:=dev@localhost}"
: "${SCRIPTOMATIC_REF:=main}"
: "${TOOLSET_REF:=2.0}"

SCRIPTOMATIC_BASE_URL="https://raw.githubusercontent.com/infocyph/Scriptomatic"
TOOLSET_RELEASE_BASE_URL="https://github.com/infocyph/Toolset/releases/download"
IPE_URL="https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions"
OHMB_URL="https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh"
DOWNLOAD_CONNECT_TIMEOUT=5
DOWNLOAD_MAX_TIME=90
DOWNLOAD_ATTEMPTS=4

HOME_DIR="/home/${USERNAME}"
BASHRC="${HOME_DIR}/.bashrc"
PHP_PROFILE="php$(v=${PHP_VERSION//[^0-9.]/}; printf '%s%s' "${v%%.*}" "${v#*.}" | cut -d. -f1)"
SOCK_DIR="${HOME_DIR}/.run/php-fpm"
DOMAINS_DIR="/usr/local/etc/php-fpm.domains/${PHP_PROFILE}"
COMPOSER_HOME_VERSIONED="${HOME_DIR}/.composer/${PHP_PROFILE}"
WORKDIR=""

cleanup() {
  [[ -z "${WORKDIR:-}" ]] || rm -rf -- "$WORKDIR"
}
trap cleanup EXIT INT TERM HUP

fatal() {
  printf 'php-cli-setup: %s\n' "$*" >&2
  exit 1
}

trim() {
  local value="$1"
  value="${value##+([[:space:]])}"
  value="${value%%+([[:space:]])}"
  printf '%s' "$value"
}

validate_uint() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] && (( value > 0 && value <= 2147483647 )) || fatal "$name must be a positive integer"
}


parse_csv() {
  local input="$1" kind="$2" out_name="$3"
  local -n out_ref="$out_name"
  local -a raw=()
  local token
  out_ref=()
  [[ -n "${input//[[:space:]]/}" ]] || return 0
  IFS=',' read -r -a raw <<< "$input"
  for token in "${raw[@]}"; do
    token="$(trim "$token")"
    [[ -n "$token" ]] || continue
    [[ "$token" != -* ]] || fatal "$kind token may not begin with '-': $token"
    case "$kind" in
      package)
        [[ "$token" =~ ^[A-Za-z0-9._+@:=\<\>~-]+$ ]] || fatal "unsafe package token: $token"
        ;;
      extension)
        [[ "$token" =~ ^[A-Za-z0-9._+@\^/:~-]+$ ]] || fatal "unsafe PHP extension token: $token"
        ;;
      *) fatal "internal error: unknown CSV kind $kind" ;;
    esac
    out_ref+=("$token")
  done
}

validate_inputs() {
  [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}\$?$ ]] || fatal "invalid Linux username: $USERNAME"
  [[ "$PHP_VERSION" =~ ^[0-9]+\.[0-9]+([.][0-9]+)?([_-][A-Za-z0-9._-]+)?$ ]] || fatal "invalid PHP version: $PHP_VERSION"
  validate_uint TARGET_UID "$TARGET_UID"
  validate_uint TARGET_GID "$TARGET_GID"
  [[ "$MSMTP_FROM" != *$'\n'* && "$MSMTP_FROM" != *$'\r'* ]] || fatal "MSMTP_FROM must be one line"
  [[ "$MSMTP_FROM" =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]] || fatal "invalid MSMTP_FROM address"
  [[ "$SCRIPTOMATIC_REF" =~ ^[A-Za-z0-9._/-]+$ ]] || fatal "invalid SCRIPTOMATIC_REF"
  [[ "$TOOLSET_REF" =~ ^[A-Za-z0-9._-]+$ ]] || fatal "invalid TOOLSET_REF"
}

require_capabilities() {
  command -v apk >/dev/null 2>&1 || fatal "apk is required; php-cli-setup supports Alpine PHP images"
  command -v php >/dev/null 2>&1 || fatal "php is required"
  [[ -d /usr/local/etc/php ]] || fatal "official PHP image layout /usr/local/etc/php is required"
  [[ -f /usr/local/etc/php-fpm.conf ]] || fatal "missing /usr/local/etc/php-fpm.conf"
  command -v sha256sum >/dev/null 2>&1 || fatal "sha256sum is required"
}

download() {
  local url="$1" dest="$2" attempt
  for ((attempt=1; attempt<=DOWNLOAD_ATTEMPTS; attempt++)); do
    if curl --fail --location --silent --show-error \
      --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" \
      --max-time "$DOWNLOAD_MAX_TIME" \
      --output "$dest" "$url"; then
      return 0
    fi
    (( attempt < DOWNLOAD_ATTEMPTS )) || break
    sleep "$attempt"
  done
  fatal "download failed after ${DOWNLOAD_ATTEMPTS} attempt(s): $url"
}

verify_sha256() {
  local file="$1" expected="$2" actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || fatal "SHA-256 mismatch for $(basename "$file")"
}

atomic_install() {
  local source="$1" dest="$2" mode="${3:-0755}" dir tmp
  dir="$(dirname "$dest")"
  mkdir -p -- "$dir"
  tmp="$(mktemp "${dir}/.scriptomatic.XXXXXX")"
  install -m "$mode" "$source" "$tmp"
  mv -f -- "$tmp" "$dest"
}

atomic_write() {
  local dest="$1" mode="$2" dir tmp
  dir="$(dirname "$dest")"
  mkdir -p -- "$dir"
  tmp="$(mktemp "${dir}/.scriptomatic.XXXXXX")"
  cat > "$tmp"
  chmod "$mode" "$tmp"
  mv -f -- "$tmp" "$dest"
}

user_exists() { getent passwd "$1" >/dev/null 2>&1; }
line_in_file() { grep -qF -- "$1" "$2" 2>/dev/null; }
run_as_user() { sudo -u "$USERNAME" -H -- "$@"; }

install_php_extension_installer() {
  local source="$WORKDIR/install-php-extensions"
  download "$IPE_URL" "$source"
  bash -n "$source"
  chmod 0755 "$source"
  printf '%s' "$source"
}

install_toolset_helper() {
  local asset="$1" dest="$2"
  local sums="$WORKDIR/toolset-SHA256SUMS"
  local file="$WORKDIR/toolset-$asset" expected
  if [[ ! -f "$sums" ]]; then
    download "${TOOLSET_RELEASE_BASE_URL%/}/${TOOLSET_REF}/SHA256SUMS" "$sums"
  fi
  expected="$(awk -v name="$asset" '$2 == name || $2 == "*" name {print $1; exit}' "$sums")"
  [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || fatal "Toolset checksum missing for $asset at $TOOLSET_REF"
  download "${TOOLSET_RELEASE_BASE_URL%/}/${TOOLSET_REF}/${asset}" "$file"
  verify_sha256 "$file" "${expected,,}"
  bash -n "$file"
  atomic_install "$file" "$dest" 0755
}

install_scriptomatic_helper() {
  local source_name="$1" dest="$2"
  local file="$WORKDIR/scriptomatic-$source_name"
  download "${SCRIPTOMATIC_BASE_URL%/}/${SCRIPTOMATIC_REF}/bash/${source_name}" "$file"
  case "$source_name" in
    php-entry.sh) sh -n "$file" ;;
    *) bash -n "$file" ;;
  esac
  atomic_install "$file" "$dest" 0755
}

install_os_and_php() {
  printf '👉 Installing base Alpine packages and PHP extensions…\n'
  local -a linux_pkg=() linux_pkg_versioned=() php_ext=() php_ext_versioned=() extensions=()
  parse_csv "$LINUX_PKG" package linux_pkg
  parse_csv "$LINUX_PKG_VERSIONED" package linux_pkg_versioned
  parse_csv "$PHP_EXT" extension php_ext
  parse_csv "$PHP_EXT_VERSIONED" extension php_ext_versioned

  apk add --no-cache \
    curl git git-credential-libsecret bash shadow sudo dos2unix lsd \
    tzdata figlet ncurses musl-locales gawk ca-certificates msmtp jq zip \
    "${linux_pkg[@]}" "${linux_pkg_versioned[@]}"

  update-ca-certificates >/dev/null 2>&1 || true

  extensions=("${php_ext[@]}" "${php_ext_versioned[@]}")
  local installer
  installer="$(install_php_extension_installer)"
  "$installer" @composer "${extensions[@]}"

  if [[ -f /usr/local/etc/php-fpm.d/zz-docker.conf ]]; then
    sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /usr/local/etc/php-fpm.d/zz-docker.conf
  fi
}

configure_fpm_includes_and_dirs() {
  printf '👉 Configuring PHP-FPM includes (/usr/local/etc/php-fpm.conf)…\n'
  local fpm_conf="/usr/local/etc/php-fpm.conf"
  [[ -f "$fpm_conf" ]] || fatal "missing $fpm_conf"

  if ! grep -qE '^[[:space:]]*include[[:space:]]*=[[:space:]]*/usr/local/etc/php-fpm\.d/\*\.conf[[:space:]]*$' "$fpm_conf"; then
    printf '\n; Default pool include\ninclude=/usr/local/etc/php-fpm.d/*.conf\n' >> "$fpm_conf"
  fi
  if ! grep -qF -- "include=${DOMAINS_DIR}/*.conf" "$fpm_conf"; then
    printf '\n; Extra pool dir mounted from host\ninclude=%s/*.conf\n' "$DOMAINS_DIR" >> "$fpm_conf"
  fi
}

configure_required_ini() {
  printf '👉 Writing PHP CA bundle ini…\n'
  atomic_write /usr/local/etc/php/conf.d/99-script-bundle.ini 0644 <<'EOF_INI'
openssl.cafile=/etc/ssl/certs/ca-certificates.crt
curl.cainfo=/etc/ssl/certs/ca-certificates.crt
sendmail_path="/usr/bin/msmtp -t"
EOF_INI
}

configure_msmtp() {
  printf '👉 Writing msmtp config (/etc/msmtprc)…\n'
  atomic_write /etc/msmtprc 0644 <<EOF_MSMTP
# Auto-generated by Scriptomatic
defaults
auth           off
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /tmp/msmtp.log

account        mailpit
host           mailpit
port           1025
from           ${MSMTP_FROM}

account default : mailpit
EOF_MSMTP
}

configure_composer_home() {
  printf '👉 Configuring Composer home (%s)…\n' "$COMPOSER_HOME_VERSIONED"
  atomic_write /etc/profile.d/composer-home.sh 0644 <<EOF_PROFILE
#!/bin/sh
export COMPOSER_HOME="${COMPOSER_HOME_VERSIONED}"
EOF_PROFILE

  if [[ -f "$BASHRC" ]] && ! line_in_file "export COMPOSER_HOME=\"${COMPOSER_HOME_VERSIONED}\"" "$BASHRC"; then
    printf '\nexport COMPOSER_HOME="%s"\n' "$COMPOSER_HOME_VERSIONED" >> "$BASHRC"
  fi
}

install_helper_scripts() {
  printf '👉 Installing helper scripts…\n'
  install_toolset_helper gitx /usr/local/bin/gitx
  install_toolset_helper chromacat /usr/local/bin/chromacat
  install_scriptomatic_helper banner.sh /usr/local/bin/show-banner
  install_scriptomatic_helper docknotify.sh /usr/local/bin/docknotify
  install_scriptomatic_helper php-entry.sh /usr/local/bin/php-entry
  install_scriptomatic_helper alias-maker.sh /usr/local/bin/alias-maker
  chown root:root /usr/local/bin/gitx /usr/local/bin/chromacat /usr/local/bin/show-banner \
    /usr/local/bin/docknotify /usr/local/bin/php-entry /usr/local/bin/alias-maker
  chmod 0755 /usr/local/bin/gitx /usr/local/bin/chromacat /usr/local/bin/show-banner \
    /usr/local/bin/docknotify /usr/local/bin/php-entry /usr/local/bin/alias-maker
}

set_banner_hook() {
  printf '👉 Setting global banner hook…\n'
  atomic_write /etc/profile.d/banner-hook.sh 0755 <<EOF_BANNER
#!/bin/sh
if [ -n "\$PS1" ] && [ -z "\${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "PHP ${PHP_VERSION}" || true
fi
EOF_BANNER
  atomic_write /etc/profile.d/git-config-global.sh 0644 <<'EOF_GIT'
#!/bin/sh
export GIT_CONFIG_GLOBAL=/git-config/.gitconfig
EOF_GIT
}

create_user() {
  printf '👉 Ensuring user %s (UID=%s, GID=%s) exists…\n' "$USERNAME" "$TARGET_UID" "$TARGET_GID"
  local group_name
  if getent group "$TARGET_GID" >/dev/null 2>&1; then
    group_name="$(getent group "$TARGET_GID" | cut -d: -f1)"
  else
    addgroup -g "$TARGET_GID" "$USERNAME"
    group_name="$USERNAME"
  fi

  if ! user_exists "$USERNAME"; then
    adduser -D -u "$TARGET_UID" -G "$group_name" -h "$HOME_DIR" -s /bin/bash "$USERNAME"
  fi

  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USERNAME" > "/etc/sudoers.d/${USERNAME}"
  chmod 0440 "/etc/sudoers.d/${USERNAME}"

  mkdir -p "${COMPOSER_HOME_VERSIONED}/vendor" /var/log/php-fpm "$DOMAINS_DIR" "$SOCK_DIR"
  : > "${DOMAINS_DIR}/00-empty.conf"
  chmod 0644 "${DOMAINS_DIR}/00-empty.conf"
  chown -R "$TARGET_UID:$TARGET_GID" "${HOME_DIR}/.composer" "$SOCK_DIR" /var/log/php-fpm
  chmod 0755 "$DOMAINS_DIR" "$SOCK_DIR" /var/log/php-fpm
}

configure_oh_my_bash() {
  printf '👉 Configuring Oh My Bash for %s…\n' "$USERNAME"

  if [[ ! -d "${HOME_DIR}/.oh-my-bash" ]]; then
    local installer="$WORKDIR/oh-my-bash-install.sh"
    download "$OHMB_URL" "$installer"
    bash -n "$installer"
    run_as_user bash -s -- --unattended < "$installer"
  fi

  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"
  sed -i '
    s/^[[:space:]]*#\?[[:space:]]*OSH_THEME=.*/OSH_THEME="lambda"/
    s/^[[:space:]]*#\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/
    s/^[[:space:]]*#\?[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/
    /^[[:space:]]*#\?[[:space:]]*plugins=([[:space:]]*$/,/^[[:space:]]*)[[:space:]]*$/c\plugins=(git bashmarks colored-man-pages npm xterm)
  ' "$BASHRC" || true
}

add_banner_snippet() {
  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"
  if ! line_in_file 'show-banner "PHP' "$BASHRC"; then
    printf '👉 Adding banner snippet to .bashrc…\n'
    cat >> "$BASHRC" <<EOF_BASHRC

if [ -n "\$PS1" ] && [ -z "\${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "PHP ${PHP_VERSION}" || true
fi
EOF_BASHRC
  fi
  chown "$TARGET_UID:$TARGET_GID" "$BASHRC"
}

run_alias_maker() {
  printf '👉 Applying aliases via alias-maker…\n'
  run_as_user /usr/local/bin/alias-maker
}

validate_runtime_config() {
  php --ini >/dev/null
  php -r 'exit(openssl_get_cert_locations()["default_cert_file"] === "" ? 1 : 0);' >/dev/null 2>&1 || true
  if command -v php-fpm >/dev/null 2>&1; then
    php-fpm -t >/dev/null 2>&1 || fatal "php-fpm configuration validation failed"
  fi
}

main() {
  [[ $EUID -eq 0 ]] || fatal "run as root inside the PHP image build"
  validate_inputs
  require_capabilities
  WORKDIR="$(mktemp -d /tmp/scriptomatic-php.XXXXXX)"
  chmod 0700 "$WORKDIR"

  install_os_and_php
  configure_required_ini
  configure_msmtp
  install_helper_scripts
  set_banner_hook
  configure_fpm_includes_and_dirs
  create_user
  configure_oh_my_bash
  configure_composer_home
  add_banner_snippet
  run_alias_maker
  validate_runtime_config

  rm -rf -- /var/cache/apk/*
  printf '✅ cli-setup complete for %s\n' "$USERNAME"
}

main "$@"
