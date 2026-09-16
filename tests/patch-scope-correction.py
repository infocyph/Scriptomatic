#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, got {count}: {old!r}")
    p.write_text(text.replace(old, new, 1))


# PHP setup: preserve the historical dev-container defaults, but keep the
# pinned/verified/atomic implementation introduced by hardening.
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
replace(
    "bash/php-cli-setup.sh",
    "  printf 'php-cli-setup complete for %s\\n' \"$USERNAME\"",
    "  printf '✅ cli-setup complete for %s\\n' \"$USERNAME\"",
)

# Node setup: keep immutable downloads/input validation, but preserve the
# original developer-shell defaults. npm itself remains upstream/pinned unless
# an explicit NPM_VERSION is supplied; floating npm@latest was a real build
# reproducibility problem rather than a UX preference.
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
replace(
    "bash/node-cli-setup.sh",
    """  create_user
  configure_node
  configure_oh_my_bash
  add_banner_snippet
""",
    """  create_user
  configure_oh_my_bash
  configure_node
  add_banner_snippet
""",
)
replace(
    "bash/node-cli-setup.sh",
    "  printf 'node-cli-setup complete for %s\\n' \"$USERNAME\"",
    "  printf '✅ node cli-setup complete for %s\\n' \"$USERNAME\"",
)

# Security audit: secure implementation remains mandatory, but historical
# dev-container convenience defaults are no longer treated as vulnerabilities.
replace(
    "tests/security-audit.sh",
    "assert_absent 'NODE_LOG_ENABLED:=1|NODE_KEEPALIVE_ON_FAIL:=1|NODE_AUTO_INSTALL:=1' \"Node runtime mutation/convenience must not be default-on\" \"$ROOT/bash/node-entry.sh\"\n",
    "",
)
insert_anchor = "assert_absent 'npm@latest|npm@next' \"Node setup must not float npm implicitly\" \"$ROOT/bash/node-cli-setup.sh\"\n"
p = ROOT / "tests/security-audit.sh"
text = p.read_text()
if insert_anchor not in text:
    raise SystemExit("security audit compatibility anchor missing")
compat = insert_anchor + """grep -qF ': \"${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}\"' \"$ROOT/bash/php-cli-setup.sh\" || fail \"PHP developer-container sudo default drifted\"
grep -qF ': \"${SCRIPTOMATIC_OH_MY_BASH:=1}\"' \"$ROOT/bash/php-cli-setup.sh\" || fail \"PHP Oh My Bash default drifted\"
grep -qF ': \"${COMPOSER_VERSION:=2.10.3}\"' \"$ROOT/bash/php-cli-setup.sh\" || fail \"PHP Composer default drifted\"
grep -qF ': \"${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}\"' \"$ROOT/bash/node-cli-setup.sh\" || fail \"Node developer-container sudo default drifted\"
grep -qF ': \"${SCRIPTOMATIC_OH_MY_BASH:=1}\"' \"$ROOT/bash/node-cli-setup.sh\" || fail \"Node Oh My Bash default drifted\"
for preserved in 'NODE_LOG_ENABLED:=1' 'NODE_KEEPALIVE_ON_FAIL:=1' 'NODE_AUTO_INSTALL:=1' 'NODE_ALLOW_LOCKFILE_FALLBACK:=1'; do
  grep -qF \"$preserved\" \"$ROOT/bash/node-entry.sh\" || fail \"Node compatibility default drifted: $preserved\"
done
"""
p.write_text(text.replace(insert_anchor, compat, 1))

# Bootstrap integration fixtures intentionally disable network-heavy optional
# UX pieces, but they must assert that production defaults preserve old behavior.
for path, anchor, addition in [
    (
        "tests/php-bootstrap.sh",
        'command -v apk >/dev/null 2>&1 || fail "apk missing"\n',
        '''command -v apk >/dev/null 2>&1 || fail "apk missing"\ngrep -qF ': "${COMPOSER_VERSION:=2.10.3}"' "$ROOT/bash/php-cli-setup.sh" || fail "Composer compatibility default"\ngrep -qF ': "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}"' "$ROOT/bash/php-cli-setup.sh" || fail "PHP sudo compatibility default"\ngrep -qF ': "${SCRIPTOMATIC_OH_MY_BASH:=1}"' "$ROOT/bash/php-cli-setup.sh" || fail "PHP Oh My Bash compatibility default"\n''',
    ),
    (
        "tests/node-bootstrap.sh",
        '[[ -f /etc/alpine-release ]] || fail "node bootstrap integration expects Alpine fixture"\n',
        '''[[ -f /etc/alpine-release ]] || fail "node bootstrap integration expects Alpine fixture"\ngrep -qF ': "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}"' "$ROOT/bash/node-cli-setup.sh" || fail "Node sudo compatibility default"\ngrep -qF ': "${SCRIPTOMATIC_OH_MY_BASH:=1}"' "$ROOT/bash/node-cli-setup.sh" || fail "Node Oh My Bash compatibility default"\n''',
    ),
]:
    p = ROOT / path
    text = p.read_text()
    if anchor not in text:
        raise SystemExit(f"{path}: test anchor missing")
    p.write_text(text.replace(anchor, addition, 1))

# Documentation corrections.
replacements = {
    "README.md": [
        (
            '`SCRIPTOMATIC_PASSWORDLESS_SUDO=1` is appropriate only for an explicitly trusted development container that needs non-root runtime CA/bootstrap operations. The default is disabled.',
            '`SCRIPTOMATIC_PASSWORDLESS_SUDO=1` remains the compatibility default because these scripts build trusted LocalDevStack developer containers. Set it to `0` explicitly for images that do not need runtime sudo/CA bootstrap.',
        ),
        (
            '`COMPOSER_VERSION` is optional and exact. When unset, Scriptomatic does not perform an implicit Composer self-update.',
            '`COMPOSER_VERSION` defaults to the pinned stable `2.10.3`, preserving Composer availability without the old floating self-update. Supply another exact version to override it.',
        ),
        (
            'NODE_LOG_ENABLED=0\nNODE_KEEPALIVE_ON_FAIL=0\nNODE_AUTO_INSTALL=0\nNODE_ALLOW_LOCKFILE_FALLBACK=0',
            'NODE_LOG_ENABLED=1\nNODE_KEEPALIVE_ON_FAIL=1\nNODE_AUTO_INSTALL=1\nNODE_ALLOW_LOCKFILE_FALLBACK=1',
        ),
        (
            'Direct container arguments are preferred. `NODE_CMD` remains only a trusted shell-expression compatibility escape hatch.',
            'These defaults preserve the original LocalDevStack developer-container ergonomics. Set any of them to `0` for stricter/production-like behavior. Direct container arguments are preferred; `NODE_CMD` remains only a trusted shell-expression compatibility escape hatch.',
        ),
    ],
    "docs/script-contracts.md": [
        ('passwordless sudo is opt-in and intended for trusted development containers.', 'passwordless sudo defaults on for backward-compatible trusted development containers and can be explicitly disabled with `SCRIPTOMATIC_PASSWORDLESS_SUDO=0`.'),
        ('NODE_LOG_ENABLED=0\nNODE_KEEPALIVE_ON_FAIL=0\nNODE_AUTO_INSTALL=0\nNODE_ALLOW_LOCKFILE_FALLBACK=0', 'NODE_LOG_ENABLED=1\nNODE_KEEPALIVE_ON_FAIL=1\nNODE_AUTO_INSTALL=1\nNODE_ALLOW_LOCKFILE_FALLBACK=1'),
        ('Runtime dependency installation is explicit. Strict lockfile installs do not silently fall back to mutable installs unless `NODE_ALLOW_LOCKFILE_FALLBACK=1` is explicitly set.', 'Runtime dependency installation and lockfile fallback remain enabled by default for LocalDevStack compatibility; set `NODE_AUTO_INSTALL=0` and/or `NODE_ALLOW_LOCKFILE_FALLBACK=0` for strict images.'),
        ('CERTBOT_RENEW_MAX_FAILURES=5', 'CERTBOT_RENEW_MAX_FAILURES=0'),
        ('the default failure threshold exits non-zero rather than looping silently forever;\n- `CERTBOT_RENEW_MAX_FAILURES=0` is an explicit request for unlimited retries;', 'the compatibility default `CERTBOT_RENEW_MAX_FAILURES=0` keeps retrying with diagnostics/backoff;\n- setting a positive threshold makes repeated failures terminate the container;'),
    ],
    "docs/security-review.md": [
        ('passwordless sudo is opt-in and intended for trusted developer containers only.', 'passwordless sudo remains enabled by default for backward-compatible trusted developer containers; `SCRIPTOMATIC_PASSWORDLESS_SUDO=0` explicitly disables it for stricter images.'),
        ('NODE_LOG_ENABLED=0\nNODE_KEEPALIVE_ON_FAIL=0\nNODE_AUTO_INSTALL=0\nNODE_ALLOW_LOCKFILE_FALLBACK=0', 'NODE_LOG_ENABLED=1\nNODE_KEEPALIVE_ON_FAIL=1\nNODE_AUTO_INSTALL=1\nNODE_ALLOW_LOCKFILE_FALLBACK=1'),
        ('Node defaults avoid hidden runtime mutation:', 'Node defaults preserve existing LocalDevStack developer ergonomics; each convenience can be explicitly disabled for stricter images:'),
        ('exits after the default repeated-failure threshold rather than silently masking an indefinitely broken renewal path.', 'keeps the original unlimited retry behavior by default while emitting diagnostics/backoff; operators can set a positive failure threshold when they want container termination.'),
    ],
    "docs/localdevstack-consumer-contract.md": [
        ('SCRIPTOMATIC_PASSWORDLESS_SUDO=0', 'SCRIPTOMATIC_PASSWORDLESS_SUDO=1'),
        ('For a trusted LocalDevStack developer container, build with:\n\n```text\nSCRIPTOMATIC_PASSWORDLESS_SUDO=1\n```\n\nIf LocalDevStack does not need runtime CA mutation, leave the default `0`.', 'The compatibility default remains `1` because LocalDevStack historically provides sudo-capable developer shells. If a particular image does not need runtime CA mutation or sudo, explicitly set `SCRIPTOMATIC_PASSWORDLESS_SUDO=0`.'),
        ('NODE_LOG_ENABLED=0\nNODE_KEEPALIVE_ON_FAIL=0\nNODE_AUTO_INSTALL=0\nNODE_ALLOW_LOCKFILE_FALLBACK=0', 'NODE_LOG_ENABLED=1\nNODE_KEEPALIVE_ON_FAIL=1\nNODE_AUTO_INSTALL=1\nNODE_ALLOW_LOCKFILE_FALLBACK=1'),
        ('no implicit runtime dependency installation unless `NODE_AUTO_INSTALL=1` is explicitly requested;\n- strict lockfile behavior unless `NODE_ALLOW_LOCKFILE_FALLBACK=1` is explicitly requested.', 'the historical automatic dependency-install/fallback behavior by default, with `NODE_AUTO_INSTALL=0` / `NODE_ALLOW_LOCKFILE_FALLBACK=0` available for strict images.'),
    ],
}

for path, reps in replacements.items():
    p = ROOT / path
    text = p.read_text()
    for old, new in reps:
        if old not in text:
            raise SystemExit(f"{path}: documentation anchor missing: {old!r}")
        text = text.replace(old, new, 1)
    p.write_text(text)

print("scope correction patch applied")
