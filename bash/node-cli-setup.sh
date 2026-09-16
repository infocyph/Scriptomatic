#!/usr/bin/env bash
# node-cli-setup.sh USERNAME NODE_VERSION
set -euo pipefail

USERNAME="${1:?username required}"
NODE_VERSION="${2:?node-version required}"
HOME_DIR="/home/${USERNAME}"
BASHRC="${HOME_DIR}/.bashrc"

: "${UID:=1000}"
: "${GID:=1000}"
: "${LINUX_PKG:=}"
: "${LINUX_PKG_VERSIONED:=}"
: "${NODE_GLOBAL:=}"
: "${NODE_GLOBAL_VERSIONED:=}"
: "${NODE_LOG_DIR:=/var/log/node-app}"
: "${SCRIPTOMATIC_REF:=main}"
: "${SCRIPTOMATIC_DOWNLOAD_CONNECT_TIMEOUT:=10}"
: "${SCRIPTOMATIC_DOWNLOAD_MAX_TIME:=120}"
: "${SCRIPTOMATIC_DOWNLOAD_RETRIES:=3}"

OHMB_URL="https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh"
SCRIPTOMATIC_BASE_URL="https://raw.githubusercontent.com/infocyph/Scriptomatic/${SCRIPTOMATIC_REF}/bash"
TOOLSET_INSTALLER_URL="https://github.com/infocyph/Toolset/releases/latest/download/install.sh"
SCRIPTOMATIC_TMP_DIR=""

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
  if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 0 || value > 2147483647 )); then
    echo "Invalid ${label}: ${value}" >&2
    return 1
  fi
}

validate_version() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+){0,3}([+._-][A-Za-z0-9._-]+)?$ ]] || {
    echo "Invalid Node version: $1" >&2
    return 1
  }
}

validate_scriptomatic_ref() {
  [[ "$SCRIPTOMATIC_REF" == main || "$SCRIPTOMATIC_REF" =~ ^[0-9A-Fa-f]{40}$ ]] || {
    echo "Invalid SCRIPTOMATIC_REF: use main or a full 40-character commit SHA" >&2
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
  validate_version "$NODE_VERSION"
  validate_id UID "$UID"
  validate_id GID "$GID"
  validate_scriptomatic_ref
  [[ "$NODE_LOG_DIR" == /* && "$NODE_LOG_DIR" != *$'\n'* && "$NODE_LOG_DIR" != *'/../'* && "$NODE_LOG_DIR" != */.. ]] || {
    echo "Invalid NODE_LOG_DIR: $NODE_LOG_DIR" >&2
    return 1
  }
  parse_csv "$LINUX_PKG" LINUX_PKG LINUX_PACKAGES
  parse_csv "$LINUX_PKG_VERSIONED" LINUX_PKG_VERSIONED LINUX_PACKAGES_VERSIONED
  parse_csv "$NODE_GLOBAL" NODE_GLOBAL NODE_GLOBAL_PACKAGES
  parse_csv "$NODE_GLOBAL_VERSIONED" NODE_GLOBAL_VERSIONED NODE_GLOBAL_PACKAGES_VERSIONED
}

preflight() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "Run as root (inside Docker build)" >&2; return 1; }
  command -v apk >/dev/null 2>&1 || { echo "node-cli-setup requires Alpine apk" >&2; return 1; }
  command -v node >/dev/null 2>&1 || { echo "node executable is required" >&2; return 1; }
  command -v npm >/dev/null 2>&1 || { echo "npm executable is required" >&2; return 1; }
  command -v getent >/dev/null 2>&1 || { echo "getent is required" >&2; return 1; }
  command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required by the Toolset installer" >&2; return 1; }
  command -v install >/dev/null 2>&1 || { echo "install is required by the Toolset installer" >&2; return 1; }
  SCRIPTOMATIC_TMP_DIR="$(mktemp -d /tmp/scriptomatic-node.XXXXXX)"
  chmod 0700 "$SCRIPTOMATIC_TMP_DIR"
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

install_toolset_scripts() {
  local installer="$SCRIPTOMATIC_TMP_DIR/toolset-install.sh"
  download_file "$TOOLSET_INSTALLER_URL" "$installer"
  bash -n "$installer"
  bash "$installer" --prefix /usr/local/bin gitx chromacat
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

install_os() {
  echo "👉 Installing base Alpine packages…"
  apk update
  apk add --no-cache \
    curl git git-credential-libsecret bash dos2unix shadow sudo tzdata \
    figlet ncurses musl-locales gawk ca-certificates jq zip lsd \
    "${LINUX_PACKAGES[@]}" "${LINUX_PACKAGES_VERSIONED[@]}"
  mkdir -p /usr/local/share/ca-certificates
  update-ca-certificates
  rm -rf /var/cache/apk/*
}

install_helper_scripts() {
  echo "👉 Installing helper scripts…"
  install_toolset_scripts
  install_remote_script "$SCRIPTOMATIC_BASE_URL/banner.sh" /usr/local/bin/show-banner bash
  install_remote_script "$SCRIPTOMATIC_BASE_URL/docknotify.sh" /usr/local/bin/docknotify bash
  install_remote_script "$SCRIPTOMATIC_BASE_URL/node-entry.sh" /usr/local/bin/node-entry sh
  install_remote_script "$SCRIPTOMATIC_BASE_URL/alias-maker.sh" /usr/local/bin/alias-maker bash
}

set_banner_hook() {
  echo "👉 Setting global banner hook…"
  atomic_write /etc/profile.d/banner-hook.sh 0755 <<EOF_BANNER
#!/bin/sh
if [ -n "\$PS1" ] && [ -z "\${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "Node ${NODE_VERSION}"
fi
EOF_BANNER
  atomic_write /etc/profile.d/git-config-global.sh 0755 <<'EOF_GIT'
#!/bin/sh
export GIT_CONFIG_GLOBAL=/git-config/.gitconfig
EOF_GIT
}

move_user_home() {
  local user="$1" current_home desired_home="$2"
  current_home="$(getent passwd "$user" | cut -d: -f6)"
  [[ "$current_home" == "$desired_home" ]] && return 0

  if [[ ! -e "$desired_home" ]]; then
    usermod -d "$desired_home" -m "$user"
    return 0
  fi

  [[ -d "$desired_home" ]] || {
    echo "Cannot set home for $user: $desired_home exists and is not a directory" >&2
    return 1
  }
  usermod -d "$desired_home" "$user"
}

create_user() {
  echo "👉 Ensuring user ${USERNAME} (UID=${UID}, GID=${GID}) exists…"
  local grp owner
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
    move_user_home "$USERNAME" "$HOME_DIR"
    usermod -s /bin/bash -g "$grp" "$USERNAME"
  else
    owner="$(user_by_uid "$UID" || true)"
    if [[ -n "$owner" ]]; then
      echo "👉 UID ${UID} is owned by '${owner}'. Reusing by renaming to '${USERNAME}'…"
      usermod -l "$USERNAME" "$owner"
      if getent group "$owner" >/dev/null 2>&1; then
        local owner_gid
        owner_gid="$(getent group "$owner" | cut -d: -f3)"
        if [[ "$owner_gid" == "$GID" && "$owner" != "$USERNAME" ]]; then
          if ! getent group "$USERNAME" >/dev/null 2>&1; then
            groupmod -n "$USERNAME" "$owner"
            grp="$USERNAME"
          fi
        fi
      fi
      move_user_home "$USERNAME" "$HOME_DIR"
      usermod -s /bin/bash -g "$grp" "$USERNAME"
    else
      adduser -D -u "$UID" -G "$grp" -h "$HOME_DIR" -s /bin/bash "$USERNAME"
    fi
  fi

  [[ "$(id -u "$USERNAME")" == "$UID" ]] || { echo "Failed to establish UID $UID" >&2; return 1; }
  [[ "$(id -g "$USERNAME")" == "$GID" ]] || { echo "Failed to establish GID $GID" >&2; return 1; }
  [[ "$(getent passwd "$USERNAME" | cut -d: -f6)" == "$HOME_DIR" ]] || { echo "Failed to establish home $HOME_DIR" >&2; return 1; }
  [[ "$(getent passwd "$USERNAME" | cut -d: -f7)" == /bin/bash ]] || { echo "Failed to establish bash shell" >&2; return 1; }

  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USERNAME" > "/etc/sudoers.d/${USERNAME}"
  chmod 0440 "/etc/sudoers.d/${USERNAME}"
  visudo -cf "/etc/sudoers.d/${USERNAME}" >/dev/null

  mkdir -p "${HOME_DIR}/.npm" "${HOME_DIR}/.cache" "${HOME_DIR}/.npm-global" "$NODE_LOG_DIR"
  chown -R "$USERNAME:$grp" "$HOME_DIR" "$NODE_LOG_DIR"

  chown root:root /usr/local/bin/{gitx,chromacat,show-banner,docknotify,node-entry,alias-maker}
  chmod 0755 /usr/local/bin/{gitx,chromacat,show-banner,docknotify,node-entry,alias-maker}
}

ensure_bashrc_line() {
  local line="$1"
  line_in_file "$line" "$BASHRC" || printf '%s\n' "$line" >> "$BASHRC"
}

ensure_node_profile() {
  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"
  ensure_bashrc_line 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"'
  ensure_bashrc_line 'export NPM_CONFIG_CACHE="$HOME/.npm"'
  ensure_bashrc_line 'export PATH="$HOME/.npm-global/bin:$PATH"'
  ensure_bashrc_line 'export GIT_CONFIG_GLOBAL="/git-config/.gitconfig"'
}

configure_node() {
  echo "👉 Configuring Node tooling…"
  corepack enable >/dev/null 2>&1 || true

  echo "👉 Updating npm…"
  if ! npm install -g npm@latest; then
    echo "node-cli-setup: npm@latest update failed; trying npm@next" >&2
    npm install -g npm@next || echo "node-cli-setup: npm update failed; keeping bundled npm" >&2
  fi

  local grp
  grp="$(group_by_gid "$GID" || echo "$USERNAME")"
  chown -R "$USERNAME:$grp" "${HOME_DIR}/.npm" "${HOME_DIR}/.cache" "${HOME_DIR}/.npm-global"
  ensure_node_profile

  if (( ${#NODE_GLOBAL_PACKAGES[@]} + ${#NODE_GLOBAL_PACKAGES_VERSIONED[@]} > 0 )); then
    echo "👉 Installing global Node packages…"
    run_as_user env \
      NPM_CONFIG_PREFIX="${HOME_DIR}/.npm-global" \
      NPM_CONFIG_CACHE="${HOME_DIR}/.npm" \
      npm install -g "${NODE_GLOBAL_PACKAGES[@]}" "${NODE_GLOBAL_PACKAGES_VERSIONED[@]}"
  fi
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
  ' "$BASHRC" || true
}

add_banner_snippet() {
  local banner='if [ -n "$PS1" ] && [ -z "${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "Node '"${NODE_VERSION}"'"
fi'
  if ! line_in_file 'show-banner "Node' "$BASHRC"; then
    echo "👉 Adding banner snippet to .bashrc…"
    printf '\n%s\n' "$banner" >> "$BASHRC"
  fi
}

run_alias_maker() {
  echo "👉 Applying aliases via alias-maker…"
  run_as_user /usr/local/bin/alias-maker
}

main() {
  validate_inputs
  preflight
  install_os
  install_helper_scripts
  set_banner_hook
  create_user
  configure_node
  configure_oh_my_bash
  ensure_node_profile
  add_banner_snippet
  run_alias_maker

  echo "✅ node cli-setup complete for ${USERNAME}"
  rm -rf /var/cache/apk/*
  rm -f -- "$0"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
