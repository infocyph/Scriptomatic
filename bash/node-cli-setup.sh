#!/usr/bin/env bash
# node-cli-setup.sh USERNAME NODE_VERSION
set -Eeuo pipefail
shopt -s extglob

USERNAME="${1:?username required}"
NODE_VERSION="${2:?node-version required}"

LEGACY_UID_ENV="$(printenv UID 2>/dev/null || true)"
: "${SCRIPTOMATIC_UID:=${LEGACY_UID_ENV:-1000}}"
: "${SCRIPTOMATIC_GID:=${GID:-1000}}"
: "${LINUX_PKG:=}"
: "${LINUX_PKG_VERSIONED:=}"
: "${NODE_GLOBAL:=}"
: "${NODE_GLOBAL_VERSIONED:=}"
: "${NODE_LOG_DIR:=/var/log/node-app}"
: "${NPM_VERSION:=}"
: "${SCRIPTOMATIC_REPRODUCIBLE:=0}"
: "${SCRIPTOMATIC_REF:=main}"
: "${SCRIPTOMATIC_BASE_URL:=https://raw.githubusercontent.com/infocyph/Scriptomatic}"
: "${TOOLSET_REF:=2.0}"
: "${TOOLSET_RELEASE_BASE_URL:=https://github.com/infocyph/Toolset/releases/download}"
: "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}"
: "${SCRIPTOMATIC_OH_MY_BASH:=1}"
: "${OHMYBASH_REF:=abf846186ab0a8a41ec5888e827ece6277dfe446}"
: "${OHMYBASH_REPO_URL:=https://github.com/ohmybash/oh-my-bash.git}"
: "${DOWNLOAD_CONNECT_TIMEOUT:=5}"
: "${DOWNLOAD_MAX_TIME:=90}"
: "${DOWNLOAD_ATTEMPTS:=4}"

HOME_DIR="/home/${USERNAME}"
BASHRC="${HOME_DIR}/.bashrc"
WORKDIR=""

cleanup() {
  [[ -z "${WORKDIR:-}" ]] || rm -rf -- "$WORKDIR"
}
trap cleanup EXIT INT TERM HUP

fatal() {
  printf 'node-cli-setup: %s\n' "$*" >&2
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

validate_flag() {
  local name="$1" value="$2"
  [[ "$value" == 0 || "$value" == 1 ]] || fatal "$name must be 0 or 1"
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
      npm-name)
        [[ "$token" =~ ^(@[A-Za-z0-9._-]+/)?[A-Za-z0-9._-]+$ ]] || fatal "unsafe npm package name: $token"
        ;;
      npm-versioned)
        if [[ "$token" =~ ^[A-Za-z0-9._-]+@[0-9]+([.][0-9]+){0,3}(-[A-Za-z0-9._-]+)?$ ]] ||
           [[ "$token" =~ ^@[A-Za-z0-9._-]+/[A-Za-z0-9._-]+@[0-9]+([.][0-9]+){0,3}(-[A-Za-z0-9._-]+)?$ ]]; then
          :
        else
          fatal "NODE_GLOBAL_VERSIONED requires an exact package version: $token"
        fi
        ;;
      *) fatal "internal error: unknown CSV kind $kind" ;;
    esac
    out_ref+=("$token")
  done
}

validate_inputs() {
  [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}\$?$ ]] || fatal "invalid Linux username: $USERNAME"
  [[ "$NODE_VERSION" =~ ^[0-9]+([.][0-9]+){0,2}([_-][A-Za-z0-9._-]+)?$ ]] || fatal "invalid Node version: $NODE_VERSION"
  validate_uint SCRIPTOMATIC_UID "$SCRIPTOMATIC_UID"
  validate_uint SCRIPTOMATIC_GID "$SCRIPTOMATIC_GID"
  validate_flag SCRIPTOMATIC_REPRODUCIBLE "$SCRIPTOMATIC_REPRODUCIBLE"
  validate_flag SCRIPTOMATIC_PASSWORDLESS_SUDO "$SCRIPTOMATIC_PASSWORDLESS_SUDO"
  validate_flag SCRIPTOMATIC_OH_MY_BASH "$SCRIPTOMATIC_OH_MY_BASH"
  [[ -z "$NPM_VERSION" || "$NPM_VERSION" =~ ^[0-9]+([.][0-9]+){1,3}(-[A-Za-z0-9._-]+)?$ ]] || fatal "NPM_VERSION must be an exact numeric version"
  [[ "$NODE_LOG_DIR" == /* && "$NODE_LOG_DIR" != *$'\n'* && "$NODE_LOG_DIR" != *$'\r'* ]] || fatal "NODE_LOG_DIR must be an absolute one-line path"
  [[ "$SCRIPTOMATIC_REF" =~ ^[A-Za-z0-9._/-]+$ ]] || fatal "invalid SCRIPTOMATIC_REF"
  [[ "$TOOLSET_REF" =~ ^[A-Za-z0-9._-]+$ ]] || fatal "invalid TOOLSET_REF"
  validate_uint DOWNLOAD_CONNECT_TIMEOUT "$DOWNLOAD_CONNECT_TIMEOUT"
  validate_uint DOWNLOAD_MAX_TIME "$DOWNLOAD_MAX_TIME"
  validate_uint DOWNLOAD_ATTEMPTS "$DOWNLOAD_ATTEMPTS"
}

require_capabilities() {
  command -v apk >/dev/null 2>&1 || fatal "apk is required; node-cli-setup supports Alpine Node images"
  command -v node >/dev/null 2>&1 || fatal "node is required"
  command -v npm >/dev/null 2>&1 || fatal "npm is required"
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
user_by_uid() { getent passwd "$1" 2>/dev/null | cut -d: -f1; }
group_by_gid() { getent group "$1" 2>/dev/null | cut -d: -f1; }
line_in_file() { grep -qF -- "$1" "$2" 2>/dev/null; }
run_as_user() { sudo -u "$USERNAME" -H -- "$@"; }

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
    node-entry.sh) sh -n "$file" ;;
    *) bash -n "$file" ;;
  esac
  atomic_install "$file" "$dest" 0755
}

install_os() {
  local -a linux_pkg=() linux_pkg_versioned=()
  parse_csv "$LINUX_PKG" package linux_pkg
  parse_csv "$LINUX_PKG_VERSIONED" package linux_pkg_versioned
  apk add --no-cache \
    curl git git-credential-libsecret bash dos2unix shadow sudo tzdata \
    figlet ncurses musl-locales gawk ca-certificates jq zip lsd \
    "${linux_pkg[@]}" "${linux_pkg_versioned[@]}"
  update-ca-certificates >/dev/null 2>&1 || true
}

install_helper_scripts() {
  install_toolset_helper gitx /usr/local/bin/gitx
  install_toolset_helper chromacat /usr/local/bin/chromacat
  install_scriptomatic_helper banner.sh /usr/local/bin/show-banner
  install_scriptomatic_helper docknotify.sh /usr/local/bin/docknotify
  install_scriptomatic_helper node-entry.sh /usr/local/bin/node-entry
  install_scriptomatic_helper alias-maker.sh /usr/local/bin/alias-maker
  chown root:root /usr/local/bin/gitx /usr/local/bin/chromacat /usr/local/bin/show-banner \
    /usr/local/bin/docknotify /usr/local/bin/node-entry /usr/local/bin/alias-maker
  chmod 0755 /usr/local/bin/gitx /usr/local/bin/chromacat /usr/local/bin/show-banner \
    /usr/local/bin/docknotify /usr/local/bin/node-entry /usr/local/bin/alias-maker
}

set_banner_hook() {
  atomic_write /etc/profile.d/banner-hook.sh 0755 <<EOF_BANNER
#!/bin/sh
if [ -n "\$PS1" ] && [ -z "\${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "Node ${NODE_VERSION}" || true
fi
EOF_BANNER
  atomic_write /etc/profile.d/git-config-global.sh 0644 <<'EOF_GIT'
#!/bin/sh
export GIT_CONFIG_GLOBAL=/git-config/.gitconfig
EOF_GIT
}

create_user() {
  local group_name owner old_owner current_uid current_home
  group_name="$(group_by_gid "$SCRIPTOMATIC_GID" || true)"
  if [[ -z "$group_name" ]]; then
    addgroup -g "$SCRIPTOMATIC_GID" "$USERNAME"
    group_name="$USERNAME"
  fi

  if user_exists "$USERNAME"; then
    current_uid="$(getent passwd "$USERNAME" | cut -d: -f3)"
    [[ "$current_uid" == "$SCRIPTOMATIC_UID" ]] || fatal "existing user $USERNAME has UID $current_uid, expected $SCRIPTOMATIC_UID"
  else
    owner="$(user_by_uid "$SCRIPTOMATIC_UID" || true)"
    if [[ -n "$owner" ]]; then
      old_owner="$owner"
      if [[ "$old_owner" != "$USERNAME" ]] && getent group "$old_owner" >/dev/null 2>&1; then
        if [[ "$(getent group "$old_owner" | cut -d: -f3)" == "$SCRIPTOMATIC_GID" ]] && ! getent group "$USERNAME" >/dev/null 2>&1; then
          groupmod -n "$USERNAME" "$old_owner"
          group_name="$USERNAME"
        fi
      fi
      usermod -l "$USERNAME" "$old_owner"
    else
      adduser -D -u "$SCRIPTOMATIC_UID" -G "$group_name" -h "$HOME_DIR" -s /bin/bash "$USERNAME"
    fi
  fi

  current_home="$(getent passwd "$USERNAME" | cut -d: -f6)"
  if [[ "$current_home" != "$HOME_DIR" ]]; then
    usermod -d "$HOME_DIR" -m "$USERNAME"
  fi
  usermod -s /bin/bash "$USERNAME"
  usermod -g "$group_name" "$USERNAME"

  local passwd_line final_uid final_gid final_home final_shell
  passwd_line="$(getent passwd "$USERNAME")"
  IFS=: read -r _ _ final_uid final_gid _ final_home final_shell <<< "$passwd_line"
  [[ "$final_uid" == "$SCRIPTOMATIC_UID" ]] || fatal "final UID mismatch for $USERNAME"
  [[ "$final_gid" == "$SCRIPTOMATIC_GID" ]] || fatal "final GID mismatch for $USERNAME"
  [[ "$final_home" == "$HOME_DIR" ]] || fatal "final home mismatch for $USERNAME"
  [[ "$final_shell" == /bin/bash ]] || fatal "final shell mismatch for $USERNAME"

  if [[ "$SCRIPTOMATIC_PASSWORDLESS_SUDO" == 1 ]]; then
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USERNAME" > "/etc/sudoers.d/${USERNAME}"
    chmod 0440 "/etc/sudoers.d/${USERNAME}"
  else
    rm -f -- "/etc/sudoers.d/${USERNAME}"
  fi

  mkdir -p "$HOME_DIR/.npm" "$HOME_DIR/.cache" "$HOME_DIR/.npm-global" "$NODE_LOG_DIR"
  chown -R "$SCRIPTOMATIC_UID:$SCRIPTOMATIC_GID" "$HOME_DIR" "$NODE_LOG_DIR"
}

configure_node() {
  local -a globals=() versioned_globals=() all_globals=()
  parse_csv "$NODE_GLOBAL" npm-name globals
  parse_csv "$NODE_GLOBAL_VERSIONED" npm-versioned versioned_globals
  if [[ "$SCRIPTOMATIC_REPRODUCIBLE" == 1 && ${#globals[@]} -gt 0 ]]; then
    fatal "SCRIPTOMATIC_REPRODUCIBLE=1 requires NODE_GLOBAL_VERSIONED exact packages"
  fi

  if [[ -n "$NPM_VERSION" ]]; then
    npm install -g -- "npm@${NPM_VERSION}"
    [[ "$(npm --version)" == "$NPM_VERSION" ]] || fatal "npm version did not resolve to requested $NPM_VERSION"
  fi

  if command -v corepack >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1 || printf 'node-cli-setup: corepack enable was unavailable; continuing\n' >&2
  fi

  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"
  local line
  for line in \
    'export NPM_CONFIG_PREFIX="$HOME/.npm-global"' \
    'export NPM_CONFIG_CACHE="$HOME/.npm"' \
    'export PATH="$HOME/.npm-global/bin:$PATH"' \
    'export GIT_CONFIG_GLOBAL="/git-config/.gitconfig"'; do
    line_in_file "$line" "$BASHRC" || printf '%s\n' "$line" >> "$BASHRC"
  done

  all_globals=("${globals[@]}" "${versioned_globals[@]}")
  if (( ${#all_globals[@]} > 0 )); then
    run_as_user env \
      NPM_CONFIG_PREFIX="$HOME_DIR/.npm-global" \
      NPM_CONFIG_CACHE="$HOME_DIR/.npm" \
      npm install -g -- "${all_globals[@]}"
  fi
  chown -R "$SCRIPTOMATIC_UID:$SCRIPTOMATIC_GID" "$HOME_DIR/.npm" "$HOME_DIR/.cache" "$HOME_DIR/.npm-global"
}

configure_oh_my_bash() {
  [[ "$SCRIPTOMATIC_OH_MY_BASH" == 1 ]] || return 0
  command -v git >/dev/null 2>&1 || fatal "git is required for Oh My Bash"

  if [[ ! -d "$HOME_DIR/.oh-my-bash" ]]; then
    local clone_dir="$WORKDIR/oh-my-bash"
    git clone --quiet --no-checkout "$OHMYBASH_REPO_URL" "$clone_dir"
    git -C "$clone_dir" checkout --quiet --detach "$OHMYBASH_REF"
    rm -rf -- "$clone_dir/.git"
    mv -- "$clone_dir" "$HOME_DIR/.oh-my-bash"
    chown -R "$SCRIPTOMATIC_UID:$SCRIPTOMATIC_GID" "$HOME_DIR/.oh-my-bash"
  fi

  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"
  if [[ -f "$HOME_DIR/.oh-my-bash/templates/bashrc.osh-template" && ! -s "$BASHRC" ]]; then
    run_as_user cp "$HOME_DIR/.oh-my-bash/templates/bashrc.osh-template" "$BASHRC"
  fi

  sed -i \
    -e 's/^[[:space:]]*#\?[[:space:]]*OSH_THEME=.*/OSH_THEME="lambda"/' \
    -e 's/^[[:space:]]*#\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/' \
    "$BASHRC" || true

  if grep -qE '^[[:space:]]*plugins=\(' "$BASHRC"; then
    sed -i 's/^[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/' "$BASHRC"
  else
    printf '\nplugins=(git bashmarks colored-man-pages npm xterm)\n' >> "$BASHRC"
  fi
}

add_banner_snippet() {
  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"
  if ! line_in_file 'show-banner "Node' "$BASHRC"; then
    cat >> "$BASHRC" <<EOF_BASHRC

if [ -n "\$PS1" ] && [ -z "\${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "Node ${NODE_VERSION}" || true
fi
EOF_BASHRC
  fi
  chown "$SCRIPTOMATIC_UID:$SCRIPTOMATIC_GID" "$BASHRC"
}

run_alias_maker() {
  run_as_user /usr/local/bin/alias-maker
}

main() {
  [[ $EUID -eq 0 ]] || fatal "run as root inside the Node image build"
  validate_inputs
  require_capabilities
  WORKDIR="$(mktemp -d /tmp/scriptomatic-node.XXXXXX)"
  chmod 0700 "$WORKDIR"

  install_os
  install_helper_scripts
  set_banner_hook
  create_user
  configure_oh_my_bash
  configure_node
  add_banner_snippet
  run_alias_maker

  rm -rf -- /var/cache/apk/*
  printf '✅ node cli-setup complete for %s\n' "$USERNAME"
}

main "$@"
