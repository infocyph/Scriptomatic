#!/usr/bin/env bash
# cli-setup.sh  USERNAME  PHP_VERSION
set -euo pipefail

## ── Args & paths ────────────────────────────────────────────────
USERNAME="${1:?username required}"
PHP_VERSION="${2:?php-version required}"
HOME_DIR="/home/${USERNAME}"
BASHRC="${HOME_DIR}/.bashrc"
OHMB_URL="https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh"

## ── Helpers ─────────────────────────────────────────────────────
user_exists()      { getent passwd "$1" >/dev/null; }
ohmb_installed()   { [[ -d "${HOME_DIR}/.oh-my-bash" ]]; }
line_in_file()     { grep -qF "$1" "$2"; }
run_as_user()      { sudo -u "$USERNAME" -H -- "$@"; }

## ── 1. Theme, plugins, auto-update ──────────────────────────────
configure_oh_my_bash() {
  echo "Configuring Oh My Bash for ${USERNAME}…"

  # Install Oh My Bash once (runs as the target user, not root)
  if ! ohmb_installed; then
    run_as_user bash -c "curl -fsSL '$OHMB_URL' | bash -s -- --unattended"
  fi

  # Ensure .bashrc exists
  [[ -f $BASHRC ]] || sudo -u "$USERNAME" touch "$BASHRC"

  # One-pass sed — handles single-line **and** multi-line plugins arrays
  sed -i '
    s/^[[:space:]]*#\?[[:space:]]*OSH_THEME=.*/OSH_THEME="lambda"/
    s/^[[:space:]]*#\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/
    s/^[[:space:]]*#\?[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/
    /^[[:space:]]*#\?[[:space:]]*plugins=([[:space:]]*$/,/^[[:space:]]*)[[:space:]]*$/c\plugins=(git bashmarks colored-man-pages npm xterm)
  ' "$BASHRC"
}

## ── 2. Banner snippet ───────────────────────────────────────────
add_banner_snippet() {
  local banner='if [ -n "$PS1" ] && [ -z "${BANNER_SHOWN-}" ]; then
  export BANNER_SHOWN=1
  show-banner "PHP '"${PHP_VERSION}"'"
fi'

  if ! line_in_file 'show-banner "PHP' "$BASHRC"; then
    echo "Adding banner snippet…"
    printf "\n%s\n" "$banner" >> "$BASHRC"
  fi
}

## ── 3. Handy aliases ────────────────────────────────────────────
ensure_aliases() {
  echo "Adding handy aliases…"
  local aliases=(
    'alias ll="ls -la"'
  )
  for alias_cmd in "${aliases[@]}"; do
    line_in_file "$alias_cmd" "$BASHRC" || echo "$alias_cmd" >> "$BASHRC"
  done
}

## ── 4. Orchestrate & ownership fix ─────────────────────────────
main() {
  user_exists "$USERNAME" || { echo "User $USERNAME not found"; exit 1; }

  configure_oh_my_bash
  add_banner_snippet
  ensure_aliases

  # Make sure the target user owns their ~/.bashrc after root edits
  chown "$USERNAME:$USERNAME" "$BASHRC"

  echo "cli-setup complete for $USERNAME"

  rm -f -- "$0"              # self-destruct after success
}

main "$@"
