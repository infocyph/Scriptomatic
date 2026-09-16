#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{path}: expected one match, got {n}: {old!r}")
    p.write_text(text.replace(old, new, 1))

# PHP: historical LocalDevStack defaults, hardened implementation.
replace("bash/php-cli-setup.sh", ': "${COMPOSER_VERSION:=}"', ': "${COMPOSER_VERSION:=2.10.3}"')
replace("bash/php-cli-setup.sh", ': "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=0}"', ': "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}"')
replace("bash/php-cli-setup.sh", ': "${SCRIPTOMATIC_OH_MY_BASH:=0}"', ': "${SCRIPTOMATIC_OH_MY_BASH:=1}"')
replace(
    "bash/php-cli-setup.sh",
    """  sed -i \\
    -e 's/^[[:space:]]*#\\?[[:space:]]*OSH_THEME=.*/OSH_THEME=\"lambda\"/' \\
    -e 's/^[[:space:]]*#\\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE=\"true\"/' \\
    \"$BASHRC\" || true
""",
    """  sed -i \\
    -e 's/^[[:space:]]*#\\?[[:space:]]*OSH_THEME=.*/OSH_THEME=\"lambda\"/' \\
    -e 's/^[[:space:]]*#\\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE=\"true\"/' \\
    \"$BASHRC\" || true

  if grep -qE '^[[:space:]]*plugins=\\(' \"$BASHRC\"; then
    sed -i 's/^[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/' \"$BASHRC\"
  else
    printf '\\nplugins=(git bashmarks colored-man-pages npm xterm)\\n' >> \"$BASHRC\"
  fi
""",
)
replace("bash/php-cli-setup.sh", "  printf 'php-cli-setup complete for %s\\n' \"$USERNAME\"", "  printf '✅ cli-setup complete for %s\\n' \"$USERNAME\"")

# Node setup: preserve shell UX/sudo defaults; keep reproducible npm policy.
replace("bash/node-cli-setup.sh", ': "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=0}"', ': "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}"')
replace("bash/node-cli-setup.sh", ': "${SCRIPTOMATIC_OH_MY_BASH:=0}"', ': "${SCRIPTOMATIC_OH_MY_BASH:=1}"')
replace(
    "bash/node-cli-setup.sh",
    """configure_oh_my_bash() {
  [[ \"$SCRIPTOMATIC_OH_MY_BASH\" == 1 ]] || return 0
  [[ -d \"$HOME_DIR/.oh-my-bash\" ]] && return 0
  command -v git >/dev/null 2>&1 || fatal \"git is required for Oh My Bash\"
  local clone_dir=\"$WORKDIR/oh-my-bash\"
  git clone --quiet --no-checkout \"$OHMYBASH_REPO_URL\" \"$clone_dir\"
  git -C \"$clone_dir\" checkout --quiet --detach \"$OHMYBASH_REF\"
  rm -rf -- \"$clone_dir/.git\"
  mv -- \"$clone_dir\" \"$HOME_DIR/.oh-my-bash\"
  chown -R \"$SCRIPTOMATIC_UID:$SCRIPTOMATIC_GID\" \"$HOME_DIR/.oh-my-bash\"
}
""",
    """configure_oh_my_bash() {
  [[ \"$SCRIPTOMATIC_OH_MY_BASH\" == 1 ]] || return 0
  command -v git >/dev/null 2>&1 || fatal \"git is required for Oh My Bash\"

  if [[ ! -d \"$HOME_DIR/.oh-my-bash\" ]]; then
    local clone_dir=\"$WORKDIR/oh-my-bash\"
    git clone --quiet --no-checkout \"$OHMYBASH_REPO_URL\" \"$clone_dir\"
    git -C \"$clone_dir\" checkout --quiet --detach \"$OHMYBASH_REF\"
    rm -rf -- \"$clone_dir/.git\"
    mv -- \"$clone_dir\" \"$HOME_DIR/.oh-my-bash\"
    chown -R \"$SCRIPTOMATIC_UID:$SCRIPTOMATIC_GID\" \"$HOME_DIR/.oh-my-bash\"
  fi

  [[ -f \"$BASHRC\" ]] || run_as_user touch \"$BASHRC\"
  if [[ -f \"$HOME_DIR/.oh-my-bash/templates/bashrc.osh-template\" && ! -s \"$BASHRC\" ]]; then
    run_as_user cp \"$HOME_DIR/.oh-my-bash/templates/bashrc.osh-template\" \"$BASHRC\"
  fi

  sed -i \\
    -e 's/^[[:space:]]*#\\?[[:space:]]*OSH_THEME=.*/OSH_THEME=\"lambda\"/' \\
    -e 's/^[[:space:]]*#\\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE=\"true\"/' \\
    \"$BASHRC\" || true

  if grep -qE '^[[:space:]]*plugins=\\(' \"$BASHRC\"; then
    sed -i 's/^[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/' \"$BASHRC\"
  else
    printf '\\nplugins=(git bashmarks colored-man-pages npm xterm)\\n' >> \"$BASHRC\"
  fi
}
""",
)
replace("bash/node-cli-setup.sh", "  create_user\n  configure_node\n  configure_oh_my_bash\n  add_banner_snippet\n", "  create_user\n  configure_oh_my_bash\n  configure_node\n  add_banner_snippet\n")
replace("bash/node-cli-setup.sh", "  printf 'node-cli-setup complete for %s\\n' \"$USERNAME\"", "  printf '✅ node cli-setup complete for %s\\n' \"$USERNAME\"")

# Security checks should enforce hardening without redefining historical UX policy.
replace(
    "tests/security-audit.sh",
    "assert_absent 'NODE_LOG_ENABLED:=1|NODE_KEEPALIVE_ON_FAIL:=1|NODE_AUTO_INSTALL:=1' \"Node runtime mutation/convenience must not be default-on\" \"$ROOT/bash/node-entry.sh\"\n",
    "",
)
anchor = "assert_absent 'npm@latest|npm@next' \"Node setup must not float npm implicitly\" \"$ROOT/bash/node-cli-setup.sh\"\n"
p = ROOT / "tests/security-audit.sh"
text = p.read_text()
if anchor not in text:
    raise SystemExit("security audit anchor missing")
addition = anchor + """grep -qF ': \"${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}\"' \"$ROOT/bash/php-cli-setup.sh\" || fail \"PHP developer sudo default drifted\"
grep -qF ': \"${SCRIPTOMATIC_OH_MY_BASH:=1}\"' \"$ROOT/bash/php-cli-setup.sh\" || fail \"PHP Oh My Bash default drifted\"
grep -qF ': \"${COMPOSER_VERSION:=2.10.3}\"' \"$ROOT/bash/php-cli-setup.sh\" || fail \"PHP Composer default drifted\"
grep -qF ': \"${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}\"' \"$ROOT/bash/node-cli-setup.sh\" || fail \"Node developer sudo default drifted\"
grep -qF ': \"${SCRIPTOMATIC_OH_MY_BASH:=1}\"' \"$ROOT/bash/node-cli-setup.sh\" || fail \"Node Oh My Bash default drifted\"
for preserved in 'NODE_LOG_ENABLED:=1' 'NODE_KEEPALIVE_ON_FAIL:=1' 'NODE_AUTO_INSTALL:=1' 'NODE_ALLOW_LOCKFILE_FALLBACK:=1'; do
  grep -qF \"$preserved\" \"$ROOT/bash/node-entry.sh\" || fail \"Node compatibility default drifted: $preserved\"
done
"""
p.write_text(text.replace(anchor, addition, 1))

# Integration fixtures disable network-heavy UX pieces but assert production defaults.
replace(
    "tests/php-bootstrap.sh",
    'command -v apk >/dev/null 2>&1 || fail "apk missing"\n',
    'command -v apk >/dev/null 2>&1 || fail "apk missing"\n'
    'grep -qF \'${COMPOSER_VERSION:=2.10.3}\' "$ROOT/bash/php-cli-setup.sh" || fail "Composer compatibility default"\n'
    'grep -qF \'${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}\' "$ROOT/bash/php-cli-setup.sh" || fail "PHP sudo compatibility default"\n'
    'grep -qF \'${SCRIPTOMATIC_OH_MY_BASH:=1}\' "$ROOT/bash/php-cli-setup.sh" || fail "PHP Oh My Bash compatibility default"\n',
)
replace(
    "tests/node-bootstrap.sh",
    '[[ -f /etc/alpine-release ]] || fail "node bootstrap integration expects Alpine fixture"\n',
    '[[ -f /etc/alpine-release ]] || fail "node bootstrap integration expects Alpine fixture"\n'
    'grep -qF \'${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}\' "$ROOT/bash/node-cli-setup.sh" || fail "Node sudo compatibility default"\n'
    'grep -qF \'${SCRIPTOMATIC_OH_MY_BASH:=1}\' "$ROOT/bash/node-cli-setup.sh" || fail "Node Oh My Bash compatibility default"\n',
)

print("strict scope-correction source patch applied")
