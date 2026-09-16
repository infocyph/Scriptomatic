#!/usr/bin/env bash
# php-cli-setup.sh USERNAME PHP_VERSION
set -euo pipefail

USERNAME="${1:?username required}"
PHP_VERSION="${2:?php-version required}"
HOME_DIR="/home/${USERNAME}"
BASHRC="${HOME_DIR}/.bashrc"

: "${UID:=1000}"
: "${GID:=1000}"
: "${LINUX_PKG:=}"
: "${LINUX_PKG_VERSIONED:=}"
: "${PHP_EXT:=}"
: "${PHP_EXT_VERSIONED:=}"
: "${MSMTP_FROM:=dev@localhost}"
: "${SCRIPTOMATIC_REF:=main}"
: "${TOOLSET_REF:=2.0}"
: "${SCRIPTOMATIC_DOWNLOAD_CONNECT_TIMEOUT:=10}"
: "${SCRIPTOMATIC_DOWNLOAD_MAX_TIME:=120}"
: "${SCRIPTOMATIC_DOWNLOAD_RETRIES:=3}"

OHMB_URL="https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh"
IPE_URL="https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions"
SCRIPTOMATIC_BASE_URL="https://raw.githubusercontent.com/infocyph/Scriptomatic/${SCRIPTOMATIC_REF}/bash"
TOOLSET_RELEASE_BASE_URL="https://github.com/infocyph/Toolset/releases/download/${TOOLSET_REF}"
PHP_PROFILE="php$(v=${PHP_VERSION//[^0-9.]/}; printf '%s%s' "${v%%.*}" "${v#*.}" | cut -d. -f1)"
SOCK_DIR="${HOME_DIR}/.run/php-fpm"
DOMAINS_DIR="/usr/local/etc/php-fpm.domains/${PHP_PROFILE}"
COMPOSER_HOME_VERSIONED="${HOME_DIR}/.composer/${PHP_PROFILE}"
SCRIPTOMATIC_TMP_DIR=""
TOOLSET_SUMS_FILE=""

cleanup() {
  if [[ -n "${SCRIPTOMATIC_TMP_DIR:-}" && -d "$SCRIPTOMATIC_TMP_DIR" ]]; then
    rm -rf -- "$SCRIPTOMATIC_TMP_DIR"
  fi
}
trap cleanup EXIT HUP INT TERM

user_exists() { getent passwd "$1" >/dev/null 2>&1; }
line_in_file() { grep -qF -- "$1" "$2" 2>/dev/null; }
run_as_user() { sudo -u "$USERNAME" -H -- "$@"; }
user_by_uid() { getent passwd "$1" 2>/dev/null | cut -d: -f1; }
group_by_gid() { getent group "$1" 2>/dev/null | cut -d: -f1; }

validate_username() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_.-]{0,30}[A-Za-z0-9_$.-]?$ ]] || {
    echo "Invalid username: $1" >&2
    return 1
  }
}

validate_id() {
  local label="$1" value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 0 && value <= 2147483647 )) || {
    echo "Invalid ${label}: ${value}" >&2
    return 1
  }
}

validate_version() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+){0,3}([+._-][A-Za-z0-9._-]+)?$ ]] || {
    echo "Invalid PHP version: $1" >&2
    return 1
  }
}

validate_dependency_refs() {
  [[ "$SCRIPTOMATIC_REF" == main || "$SCRIPTOMATIC_REF" =~ ^[0-9A-Fa-f]{40}$ ]] || {
    echo "Invalid SCRIPTOMATIC_REF: use main or a full 40-character commit SHA" >&2
    return 1
  }
  [[ "$TOOLSET_REF" =~ ^[0-9]+[.][0-9]+$ ]] || {
    echo "Invalid TOOLSET_REF: use an exact stable MAJOR.MINOR release such as 2.0" >&2
    return 1
  }
}

validate_token() {
  local label="$1" token="$2"
  [[ -n "$token" ]] || return 0
  [[ "$token" != -* ]] || { echo "Invalid ${label} token: ${token}" >&2; return 1; }
  [[ "$token" =~ ^[A-Za-z0-9@._+/:=~^*-]+$ ]] || {
    echo "Invalid ${label} token: ${token}" >&2
    return 1
  }
}

parse_csv() {
  local value="$1" label="$2" out_name="$3" token
  local -n out="$out_name"
  out=()
  [[ -n "${value//[[:space:]]/}" ]] || return 0
  IFS=',' read -r -a out <<< "$value"
  for token in "${out[@]}"; do
    [[ "$token" == "${token//[[:space:]]/}" ]] || {
      echo "Whitespace is not allowed inside ${label} tokens: ${token}" >&2
      return 1
    }
    validate_token "$label" "$token"
  done
}

validate_inputs() {
  validate_username "$USERNAME"
  validate_version "$PHP_VERSION"
  validate_id UID "$UID"
  validate_id GID "$GID"
  validate_dependency_refs
  [[ "$MSMTP_FROM" != *$'\n'* && "$MSMTP_FROM" != *$'\r'* ]] || {
    echo "Invalid MSMTP_FROM" >&2
    return 1
  }
  parse_csv "$LINUX_PKG" LINUX_PKG LINUX_PACKAGES
  parse_csv "$LINUX_PKG_VERSIONED" LINUX_PKG_VERSIONED LINUX_PACKAGES_VERSIONED
  parse_csv "$PHP_EXT" PHP_EXT PHP_EXTENSIONS
  parse_csv "$PHP_EXT_VERSIONED" PHP_EXT_VERSIONED PHP_EXTENSIONS_VERSIONED
}

preflight() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "Run as root (inside Docker build)" >&2; return 1; }
  command -v apk >/dev/null 2>&1 || { echo "php-cli-setup requires Alpine apk" >&2; return 1; }
  [[ -d /usr/local/etc/php ]] || { echo "Missing /usr/local/etc/php; expected an official-style PHP image" >&2; return 1; }
  command -v getent >/dev/null 2>&1 || { echo "getent is required" >&2; return 1; }
  command -v mktemp >/dev/null 2>&1 || { echo "mktemp is required" >&2; return 1; }
  command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; return 1; }
  SCRIPTOMATIC_TMP_DIR="$(mktemp -d /tmp/scriptomatic-php.XXXXXX)"
  chmod 0700 "$SCRIPTOMATIC_TMP_DIR"
  TOOLSET_SUMS_FILE="${SCRIPTOMATIC_TMP_DIR}/toolset-SHA256SUMS"
}

download_file() {
  local url="$1" destination="$2"
  curl --fail --silent --show-error --location \
    --connect-timeout "$SCRIPTOMATIC_DOWNLOAD_CONNECT_TIMEOUT" \
    --max-time "$SCRIPTOMATIC_DOWNLOAD_MAX_TIME" \
    --retry "$SCRIPTOMATIC_DOWNLOAD_RETRIES" \
    --retry-delay 1 --retry-connrefused \
    "$url" -o "$destination"
  [[ -s "$destination" ]] || { echo "Downloaded file is empty: $url" >&2; return 1; }
}

install_remote_script() {
  local url="$1" destination="$2" shell_kind="$3" tmp staged
  tmp="$SCRIPTOMATIC_TMP_DIR/$(basename "$destination").download"
  staged="$(mktemp "$(dirname "$destination")/.scriptomatic.$(basename "$destination").XXXXXX")"
  download_file "$url" "$tmp"
  case "$shell_kind" in
    bash) bash -n "$tmp" ;;
    sh) sh -n "$tmp" ;;
    *) echo "Unknown shell kind: $shell_kind" >&2; return 1 ;;
  esac
  cat "$tmp" > "$staged"
  chmod 0755 "$staged"
  chown root:root "$staged"
  mv -f -- "$staged" "$destination"
}

ensure_toolset_checksums() {
  [[ -s "$TOOLSET_SUMS_FILE" ]] && return 0
  download_file "$TOOLSET_RELEASE_BASE_URL/SHA256SUMS" "$TOOLSET_SUMS_FILE"
}

install_toolset_script() {
  local tool="$1" destination="$2" expected actual tmp staged
  ensure_toolset_checksums
  expected="$(awk -v name="$tool" '$2 == name {print $1; exit}' "$TOOLSET_SUMS_FILE")"
  [[ "$expected" =~ ^[0-9A-Fa-f]{64}$ ]] || {
    echo "Toolset checksum entry missing or invalid for $tool in release $TOOLSET_REF" >&2
    return 1
  }

  tmp="$SCRIPTOMATIC_TMP_DIR/toolset-${tool}"
  download_file "$TOOLSET_RELEASE_BASE_URL/$tool" "$tmp"
  actual="$(sha256sum "$tmp" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || {
    echo "Toolset checksum verification failed for $tool in release $TOOLSET_REF" >&2
    return 1
  }
  bash -n "$tmp"

  staged="$(mktemp "$(dirname "$destination")/.scriptomatic.$(basename "$destination").XXXXXX")"
  cat "$tmp" > "$staged"
  chmod 0755 "$staged"
  chown root:root "$staged"
  mv -f -- "$staged" "$destination"
}

atomic_write() {
  local target="$1" mode="$2" tmp
  mkdir -p "$(dirname "$target")"
  tmp="$(mktemp "$(dirname "$target")/.scriptomatic.$(basename "$target").XXXXXX")"
  cat > "$tmp"
  chmod "$mode" "$tmp"
  chown root:root "$tmp"
  mv -f -- "$tmp" "$target"
}

install_os_and_php() {
  echo "👉 Installing base Alpine packages and PHP extensions…"
  apk update
  apk add --no-cache \
    curl git git-credential-libsecret bash shadow sudo dos2unix lsd \
    tzdata figlet ncurses musl-locales gawk ca-certificates msmtp jq zip \
    "${LINUX_PACKAGES[@]}" "${LINUX_PACKAGES_VERSIONED[@]}"

  local ipe="$SCRIPTOMATIC_TMP_DIR/install-php-extensions"
  download_file "$IPE_URL" "$ipe"
  sh -n "$ipe"
  chmod 0755 "$ipe"

  update-ca-certificates >/dev/null 2>&1 || true
  "$ipe" @composer "${PHP_EXTENSIONS[@]}" "${PHP_EXTENSIONS_VERSIONED[@]}"
  composer --no-interaction self-update --clean-backups

  local zz_conf="/usr/local/etc/php-fpm.d/zz-docker.conf"
  [[ -f "$zz_conf" ]] || { echo "Missing PHP-FPM config: $zz_conf" >&2; return 1; }
  sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' "$zz_conf"
  rm -rf /var/cache/apk/*
}

configure_fpm_includes_and_dirs() {
  echo "👉 Configuring PHP-FPM includes (/usr/local/etc/php-fpm.conf)…"
  local fpm_conf="/usr/local/etc/php-fpm.conf"
  [[ -f "$fpm_conf" ]] || { echo "Error: missing $fpm_conf" >&2; return 1; }

  line_in_file 'include=/usr/local/etc/php-fpm.d/*.conf' "$fpm_conf" || \
    printf '\n; Default pool include\ninclude=/usr/local/etc/php-fpm.d/*.conf\n' >> "$fpm_conf"
  line_in_file "include=${DOMAINS_DIR}/*.conf" "$fpm_conf" || \
    printf '\n; Extra pool dir mounted from host\ninclude=%s/*.conf\n' "$DOMAINS_DIR" >> "$fpm_conf"
}

configure_required_ini() {
  echo "👉 Writing PHP CA bundle ini…"
  atomic_write /usr/local/etc/php/conf.d/99-script-bundle.ini 0644 <<'INI'
openssl.cafile=/etc/ssl/certs/ca-certificates.crt
curl.cainfo=/etc/ssl/certs/ca-certificates.crt
sendmail_path="/usr/bin/msmtp -t"
INI
}

configure_msmtp() {
  echo "👉 Writing msmtp config (/etc/msmtprc)…"
  atomic_write /etc/msmtprc 0644 <<EOF_MSMTP
# Auto-generated
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
  echo "👉 Configuring Composer home (${COMPOSER_HOME_VERSIONED})…"
  atomic_write /etc/profile.d/composer-home.sh 0755 <<EOF_PROFILE
#!/bin/sh
export COMPOSER_HOME="${COMPOSER_HOME_VERSIONED}"
EOF_PROFILE
  if [[ -f "$BASHRC" ]] && ! line_in_file "export COMPOSER_HOME=\"${COMPOSER_HOME_VERSIONED}\"" "$BASHRC"; then
    printf '\nexport COMPOSER_HOME="%s"\n' "$COMPOSER_HOME_VERSIONED" >> "$BASHRC"
  fi
}

install_helper_scripts() {
  echo "👉 Installing helper scripts…"
  install_toolset_script gitx /usr/local/bin/gitx
  install_toolset_script chromacat /usr/local/bin/chromacat
  install_remote_script "$SCRIPTOMATIC_BASE_URL/banner.sh" /usr/local/bin/show-banner bash
  install_remote_script "$SCRIPTOMATIC_BASE_URL/docknotify.sh" /usr/local/bin/docknotify bash
  install_remote_script "$SCRIPTOMATIC_BASE_URL/php-entry.sh" /usr/local/bin/php-entry sh
  install_remote_script "$SCRIPTOMATIC_BASE_URL/alias-maker.sh" /usr/local/bin/alias-maker bash
}

set_banner_hook() {
  echo "👉 Setting global banner hook…"
  atomic_write /etc/profile.d/banner-hook.sh 0755 <<EOF_BANNER
#!/bin/sh
if [ -n "\$PS1" ] && [ -z "\${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "PHP ${PHP_VERSION}"
fi
EOF_BANNER
  atomic_write /etc/profile.d/git-config-global.sh 0755 <<'EOF_GIT'
#!/bin/sh
export GIT_CONFIG_GLOBAL=/git-config/.gitconfig
EOF_GIT
}

create_user() {
  echo "👉 Ensuring user ${USERNAME} (UID=${UID}, GID=${GID}) exists…"
  local grp uid_owner
  grp="$(group_by_gid "$GID" || true)"
  if [[ -z "$grp" ]]; then
    addgroup -g "$GID" "$USERNAME"
    grp="$USERNAME"
  fi

  if user_exists "$USERNAME"; then
    [[ "$(id -u "$USERNAME")" == "$UID" ]] || {
      echo "Existing user $USERNAME has UID $(id -u "$USERNAME"), expected $UID" >&2
      return 1
    }
  else
    uid_owner="$(user_by_uid "$UID" || true)"
    [[ -z "$uid_owner" ]] || {
      echo "UID $UID is already owned by $uid_owner" >&2
      return 1
    }
    adduser -D -u "$UID" -G "$grp" -h "$HOME_DIR" -s /bin/bash "$USERNAME"
  fi

  usermod -g "$grp" -s /bin/bash -d "$HOME_DIR" "$USERNAME" >/dev/null 2>&1 || true
  [[ "$(id -u "$USERNAME")" == "$UID" ]] || { echo "Failed to establish UID $UID" >&2; return 1; }
  [[ "$(id -g "$USERNAME")" == "$GID" ]] || { echo "Failed to establish GID $GID" >&2; return 1; }

  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USERNAME" > "/etc/sudoers.d/${USERNAME}"
  chmod 0440 "/etc/sudoers.d/${USERNAME}"
  visudo -cf "/etc/sudoers.d/${USERNAME}" >/dev/null

  mkdir -p "$COMPOSER_HOME_VERSIONED/vendor" /var/log/php-fpm "$DOMAINS_DIR" "$SOCK_DIR"
  : > "${DOMAINS_DIR}/00-empty.conf"
  chmod 0644 "${DOMAINS_DIR}/00-empty.conf"
  chown -R "$UID:$GID" "${HOME_DIR}/.composer" "$SOCK_DIR" /var/log/php-fpm
  chmod 0755 "$DOMAINS_DIR" "$SOCK_DIR" /var/log/php-fpm

  chown root:root /usr/local/bin/{gitx,chromacat,show-banner,docknotify,php-entry,alias-maker}
  chmod 0755 /usr/local/bin/{gitx,chromacat,show-banner,docknotify,php-entry,alias-maker}
}

configure_oh_my_bash() {
  echo "👉 Configuring Oh My Bash for ${USERNAME}…"
  if [[ ! -d "${HOME_DIR}/.oh-my-bash" ]]; then
    local installer="$SCRIPTOMATIC_TMP_DIR/oh-my-bash-install.sh"
    local user_installer
    download_file "$OHMB_URL" "$installer"
    bash -n "$installer"
    user_installer="$(mktemp "${HOME_DIR}/.scriptomatic-ohmybash.XXXXXX")"
    cat "$installer" > "$user_installer"
    chown "$UID:$GID" "$user_installer"
    chmod 0700 "$user_installer"
    run_as_user bash "$user_installer" --unattended
    rm -f -- "$user_installer"
  fi

  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"
  sed -i '
    s/^[[:space:]]*#\?[[:space:]]*OSH_THEME=.*/OSH_THEME="lambda"/
    s/^[[:space:]]*#\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/
    s/^[[:space:]]*#\?[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/
    /^[[:space:]]*#\?[[:space:]]*plugins=([[:space:]]*$/,/^[[:space:]]*)[[:space:]]*$/c\plugins=(git bashmarks colored-man-pages npm xterm)
  ' "$BASHRC"
}

add_banner_snippet() {
  local banner='if [ -n "$PS1" ] && [ -z "${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "PHP '"${PHP_VERSION}"'"
fi'
  if ! line_in_file 'show-banner "PHP' "$BASHRC"; then
    echo "👉 Adding banner snippet to .bashrc…"
    printf '\n%s\n' "$banner" >> "$BASHRC"
  fi
}

run_alias_maker() {
  echo "👉 Applying aliases via alias-maker…"
  run_as_user /usr/local/bin/alias-maker
}

validate_generated_config() {
  php --ini >/dev/null
  command -v php-fpm >/dev/null 2>&1 || { echo "php-fpm is required" >&2; return 1; }
  php-fpm -t >/dev/null 2>&1
}

main() {
  validate_inputs
  preflight
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
  validate_generated_config

  echo "✅ cli-setup complete for ${USERNAME}"
  rm -rf /var/cache/apk/*
  rm -f -- "$0"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
