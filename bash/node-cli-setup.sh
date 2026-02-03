#!/usr/bin/env bash
# node-cli-setup.sh USERNAME NODE_VERSION
set -euo pipefail

#####################################################################
# Arguments & paths
#####################################################################
USERNAME="${1:?username required}"
NODE_VERSION="${2:?node-version required}"

HOME_DIR="/home/${USERNAME}"
BASHRC="${HOME_DIR}/.bashrc"

# Build-time ENV knobs (fall back to empty/defaults)
: "${UID:=1000}"
: "${GID:=1000}"
: "${LINUX_PKG:=}"
: "${LINUX_PKG_VERSIONED:=}"
: "${NODE_GLOBAL:=}"
: "${NODE_GLOBAL_VERSIONED:=}"

OHMB_URL="https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh"

#####################################################################
# Helper utilities
#####################################################################
user_exists() { getent passwd "$1" >/dev/null 2>&1; }
line_in_file() { grep -qF "$1" "$2" 2>/dev/null; }
run_as_user() { sudo -u "$USERNAME" -H -- "$@"; }

user_by_uid() { getent passwd "$1" 2>/dev/null | cut -d: -f1; }
group_by_gid() { getent group "$1" 2>/dev/null | cut -d: -f1; }

#####################################################################
# 1. Base OS packages
#####################################################################
install_os() {
  echo "👉 Installing base Alpine packages…"
  apk update
  apk add --no-cache \
    curl git bash shadow sudo tzdata figlet ncurses musl-locales gawk ca-certificates \
    ${LINUX_PKG//,/ } ${LINUX_PKG_VERSIONED//,/ }

  mkdir -p /usr/local/share/ca-certificates
  update-ca-certificates

  # Keep layers small
  rm -rf /var/cache/apk/* /tmp/* /var/tmp/*
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
    "https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/docknotify.sh|/usr/local/bin/docknotify"
    "https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/git-default.sh|/usr/local/bin/git-default"
    "https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/node-entryt.sh|/usr/local/bin/node-entry"
  ) dests=() url dst pair

  for pair in "${helpers[@]}"; do
    IFS='|' read -r url dst <<<"$pair"
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
  show-banner "Node ${NODE_VERSION}"
fi
EOF
  chmod +x /etc/profile.d/banner-hook.sh
}

#####################################################################
# 4. Create (or sync) non-root user with sudo rights
#    NOTE: node:<ver>-alpine often has 'node' user with UID=1000.
#          We reuse/rename that user instead of failing.
#####################################################################
create_user() {
  echo "👉 Ensuring user ${USERNAME} (UID=${UID}, GID=${GID}) exists…"

  # Ensure group exists (by numeric GID). If missing, create it.
  local grp
  grp="$(group_by_gid "$GID" || true)"
  if [[ -z "$grp" ]]; then
    addgroup -g "$GID" "$USERNAME"
    grp="$USERNAME"
  fi

  # Case A: desired username already exists
  if user_exists "$USERNAME"; then
    # Make sure it has a bash shell and correct home (best-effort)
    usermod -s /bin/bash "$USERNAME" >/dev/null 2>&1 || true
    local cur_home
    cur_home="$(getent passwd "$USERNAME" | cut -d: -f6)"
    if [[ "$cur_home" != "$HOME_DIR" ]]; then
      mkdir -p "$HOME_DIR"
      usermod -d "$HOME_DIR" -m "$USERNAME" >/dev/null 2>&1 || true
    fi
    usermod -g "$grp" "$USERNAME" >/dev/null 2>&1 || true

    # Case B: UID already taken (common: 'node' user has UID=1000)
  else
    local owner
    owner="$(user_by_uid "$UID" || true)"
    if [[ -n "$owner" ]]; then
      echo "👉 UID ${UID} is owned by '${owner}'. Reusing by renaming to '${USERNAME}'…"

      # Rename user to desired username
      usermod -l "$USERNAME" "$owner"

      # If the old user's group name matches, rename it too (best-effort)
      if getent group "$owner" >/dev/null 2>&1; then
        local ogid
        ogid="$(getent group "$owner" | cut -d: -f3)"
        if [[ "$ogid" == "$GID" ]]; then
          groupmod -n "$USERNAME" "$owner" >/dev/null 2>&1 || true
          grp="$USERNAME"
        fi
      fi

      # Ensure home + shell + primary group
      mkdir -p "$HOME_DIR"
      usermod -d "$HOME_DIR" -m "$USERNAME" >/dev/null 2>&1 || true
      usermod -s /bin/bash "$USERNAME" >/dev/null 2>&1 || true
      usermod -g "$grp" "$USERNAME" >/dev/null 2>&1 || true
    else
      # Case C: brand new user
      adduser -D -u "$UID" -G "$grp" -h "$HOME_DIR" -s /bin/bash "$USERNAME"
    fi
  fi

  # Sudo without password (needed for dev shells)
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/"${USERNAME}"
  chmod 0440 /etc/sudoers.d/"${USERNAME}"

  # Node caches / global prefix (avoid root-owned globals)
  mkdir -p \
    "${HOME_DIR}/.npm" \
    "${HOME_DIR}/.cache" \
    "${HOME_DIR}/.npm-global"

  chown -R "${USERNAME}:${grp}" "${HOME_DIR}"

  # Fix ownership of helper scripts & banner hook
  chown root:root /etc/profile.d/banner-hook.sh
  chown "${USERNAME}:${grp}" /usr/local/bin/{show-banner,gitx,chromacat,docknotify} 2>/dev/null || true
}

#####################################################################
# 5. Node tooling (corepack + safe global installs)
#####################################################################
configure_node() {
  echo "👉 Configuring Node tooling…"

  # Enable corepack for pnpm/yarn (non-fatal)
  corepack enable >/dev/null 2>&1 || true

  # Persist npm global prefix and PATH in .bashrc (user-owned)
  run_as_user bash -lc "touch '$BASHRC'"

  local l1='export NPM_CONFIG_PREFIX="$HOME/.npm-global"'
  local l2='export PATH="$HOME/.npm-global/bin:$PATH"'
  line_in_file "$l1" "$BASHRC" || echo "$l1" >>"$BASHRC"
  line_in_file "$l2" "$BASHRC" || echo "$l2" >>"$BASHRC"

  # Optional global packages (comma-separated)
  if [[ -n "${NODE_GLOBAL//[[:space:]]/}" || -n "${NODE_GLOBAL_VERSIONED//[[:space:]]/}" ]]; then
    echo "👉 Installing global Node packages…"
    run_as_user bash -lc "npm i -g ${NODE_GLOBAL//,/ } ${NODE_GLOBAL_VERSIONED//,/ }"
  fi
}

#####################################################################
# 6. Oh-My-Bash & .bashrc tweaks
#####################################################################
configure_oh_my_bash() {
  echo "👉 Configuring Oh My Bash for ${USERNAME}…"

  if [[ ! -d "${HOME_DIR}/.oh-my-bash" ]]; then
    run_as_user bash -c "curl -fsSL '$OHMB_URL' | bash -s -- --unattended"
  fi

  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"

  sed -i '
    s/^[[:space:]]*#\?[[:space:]]*OSH_THEME=.*/OSH_THEME="lambda"/
    s/^[[:space:]]*#\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/
    s/^[[:space:]]*#\?[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/
    /^[[:space:]]*#\?[[:space:]]*plugins=([[:space:]]*$/,/^[[:space:]]*)[[:space:]]*$/c\plugins=(git bashmarks colored-man-pages npm xterm)
  ' "$BASHRC" || true
}

#####################################################################
# 7. Banner snippet inside user’s .bashrc
#####################################################################
add_banner_snippet() {
  local banner='if [ -n "$PS1" ] && [ -z "${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "Node '"${NODE_VERSION}"'"
fi'

  if ! line_in_file 'show-banner "Node' "$BASHRC"; then
    echo "👉 Adding banner snippet to .bashrc…"
    printf "\n%s\n" "$banner" >>"$BASHRC"
  fi
}

#####################################################################
# 8. Handy aliases
#####################################################################
ensure_aliases() {
  echo "👉 Adding handy aliases…"
  local aliases=(
    'alias ll="ls -la"'
  )
  local a
  for a in "${aliases[@]}"; do
    line_in_file "$a" "$BASHRC" || echo "$a" >>"$BASHRC"
  done
}

#####################################################################
# 9. Orchestrate everything
#####################################################################
main() {
  [[ $EUID -eq 0 ]] || { echo "Run as root (inside Docker build)"; exit 1; }

  install_os
  install_helper_scripts
  set_banner_hook
  create_user
  configure_node
  configure_oh_my_bash
  add_banner_snippet
  ensure_aliases

  echo "✅ node cli-setup complete for ${USERNAME}"
  rm -f -- "$0"
}

main "$@"
