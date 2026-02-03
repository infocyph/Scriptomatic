#!/usr/bin/env bash
# cli-setup.sh   USERNAME  PHP_VERSION
set -euo pipefail

#####################################################################
# Arguments & paths
#####################################################################
USERNAME="${1:?username required}"
PHP_VERSION="${2:?php-version required}"

HOME_DIR="/home/${USERNAME}"
BASHRC="${HOME_DIR}/.bashrc"

# Build-time ENV knobs (fall back to empty/defaults)
: "${UID:=1000}"
: "${GID:=1000}"
: "${LINUX_PKG:=}"
: "${LINUX_PKG_VERSIONED:=}"
: "${PHP_EXT:=}"
: "${PHP_EXT_VERSIONED:=}"

OHMB_URL="https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh"
IPE_URL="https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions"

#####################################################################
# Helper utilities
#####################################################################
user_exists() { getent passwd "$1" >/dev/null; }
line_in_file() { grep -qF "$1" "$2"; }
run_as_user() { sudo -u "$USERNAME" -H -- "$@"; }

#####################################################################
# 1. Base OS packages & PHP extensions
#####################################################################
install_os_and_php() {
  echo "👉 Installing base Alpine packages and PHP extensions…"
  apk update
  apk add --no-cache \
    curl git bash shadow sudo tzdata figlet ncurses musl-locales gawk ca-certificates \
    ${LINUX_PKG//,/ } ${LINUX_PKG_VERSIONED//,/ }

  if [[ ! -x /usr/local/bin/install-php-extensions ]]; then
    curl -fsSL "$IPE_URL" -o /usr/local/bin/install-php-extensions
    chmod +x /usr/local/bin/install-php-extensions
  fi

  mkdir -p /usr/local/share/ca-certificates
  install-php-extensions @composer ${PHP_EXT//,/ } ${PHP_EXT_VERSIONED//,/ }
  composer --no-interaction self-update --clean-backups

  # Ensure FPM listens on 0.0.0.0:9000
  sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /usr/local/etc/php-fpm.d/zz-docker.conf

  # Clean apk cache to keep layers small
  rm -rf /usr/local/bin/install-php-extensions /var/cache/apk/* /tmp/* /var/tmp/*
}

#####################################################################
# 2. Drop helper scripts
#####################################################################
install_helper_scripts() {
  echo "👉 Installing helper scripts…"
  local helpers=(
    "https://raw.githubusercontent.com/infocyph/Toolset/main/Git/gitx|/usr/local/bin/gitx"
    "https://raw.githubusercontent.com/infocyph/Toolset/main/ChromaCat/chromacat|/usr/local/bin/chromacat"
    "https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/banner.sh|/usr/local/bin/show-banner"
    "https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/git-default.sh|/usr/local/bin/git-default"
    "https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/docknotify.sh|/usr/local/bin/docknotify"
    "https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/php-entry.sh|/usr/local/bin/php-entry"
  ) dests=() url dst pair
  for pair in "${helpers[@]}"; do
    IFS='|' read -r url dst <<< "$pair"
    curl -fsSL "$url" -o "$dst"
    dests+=("$dst")
  done
  chmod +x "${dests[@]}"
}

#####################################################################
# 3. Banner hook executed for every interactive shell
#####################################################################
set_banner_hook() {
  echo "👉 Setting global banner hook…"
  mkdir -p /etc/profile.d
  cat >/etc/profile.d/banner-hook.sh <<EOF
#!/bin/sh
if [ -n "\$PS1" ] && [ -z "\${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "PHP ${PHP_VERSION}"
fi
EOF
  chmod +x /etc/profile.d/banner-hook.sh
}

#####################################################################
# 4. Create (or sync) non-root user with sudo rights
#####################################################################
create_user() {
  echo "👉 Ensuring user ${USERNAME} (UID=${UID}, GID=${GID}) exists…"

  # Ensure group
  getent group "${GID}" >/dev/null || addgroup -g "${GID}" "${USERNAME}"

  # Ensure user
  if ! user_exists "${USERNAME}"; then
    adduser -D -u "${UID}" -G "$(getent group "${GID}" | cut -d: -f1)" \
      -h "${HOME_DIR}" -s /bin/bash "${USERNAME}"
  fi

  # Sudo without password
  apk add --no-cache sudo
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/"${USERNAME}"
  chmod 0440 /etc/sudoers.d/"${USERNAME}"

  # Composer cache dir + ownership
  mkdir -p "${HOME_DIR}/.composer/vendor"
  chown -R "${USERNAME}:${USERNAME}" "${HOME_DIR}"

  # Fix ownership of helper scripts & banner hook
  chown root:root /etc/profile.d/banner-hook.sh
  chown "${USERNAME}:${USERNAME}" /usr/local/bin/{cli-setup.sh,show-banner,gitx,chromacat}
}

#####################################################################
# 5. Oh-My-Bash & .bashrc tweaks (from previous version)
#####################################################################
configure_oh_my_bash() {
  echo "👉 Configuring Oh My Bash for ${USERNAME}…"

  # Install Oh-My-Bash for the user if absent
  if [[ ! -d "${HOME_DIR}/.oh-my-bash" ]]; then
    run_as_user bash -c "curl -fsSL '$OHMB_URL' | bash -s -- --unattended"
  fi

  [[ -f $BASHRC ]] || run_as_user touch "$BASHRC"

  sed -i '
    s/^[[:space:]]*#\?[[:space:]]*OSH_THEME=.*/OSH_THEME="lambda"/
    s/^[[:space:]]*#\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/
    s/^[[:space:]]*#\?[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/
    /^[[:space:]]*#\?[[:space:]]*plugins=([[:space:]]*$/,/^[[:space:]]*)[[:space:]]*$/c\plugins=(git bashmarks colored-man-pages npm xterm)
  ' "$BASHRC"
}

#####################################################################
# 6. Banner snippet inside user’s .bashrc
#####################################################################
add_banner_snippet() {
  local banner='if [ -n "$PS1" ] && [ -z "${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "PHP '"${PHP_VERSION}"'"
fi'

  if ! line_in_file 'show-banner "PHP' "$BASHRC"; then
    echo "👉 Adding banner snippet to .bashrc…"
    printf "\n%s\n" "$banner" >>"$BASHRC"
  fi
}

#####################################################################
# 7. Handy aliases (original style)
#####################################################################
ensure_aliases() {
  echo "👉 Adding handy aliases…"
  local aliases=(
    'alias ll="ls -la"'
    )
  for alias_cmd in "${aliases[@]}"; do
    line_in_file "$alias_cmd" "$BASHRC" || echo "$alias_cmd" >>"$BASHRC"
  done
}

#####################################################################
# 8. Orchestrate everything
#####################################################################
main() {
  [[ $EUID -eq 0 ]] || {
    echo "Run as root (inside Docker build)"
    exit 1
  }

  install_os_and_php
  install_helper_scripts
  set_banner_hook
  create_user
  configure_oh_my_bash
  add_banner_snippet
  ensure_aliases

  echo "✅ cli-setup complete for ${USERNAME}"
  rm -f -- "$0"
}

main "$@"
