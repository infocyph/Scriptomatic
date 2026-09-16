from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


def write(path, text):
    (ROOT / path).write_text(text)


def exact(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing expected block: {label}")
    return text.replace(old, new, 1)


def sub1(text, pattern, repl, label):
    out, count = re.subn(pattern, repl, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"expected one match for {label}, got {count}")
    return out


def main_file(path):
    return subprocess.check_output(["git", "show", f"origin/main:{path}"], cwd=ROOT, text=True)


# ---------------------------------------------------------------------------
# alias-maker: main already contains the intended aliases/functions and
# idempotent function block. Do not redesign the user's shell UX here.
# ---------------------------------------------------------------------------
write("bash/alias-maker.sh", main_file("bash/alias-maker.sh"))


# ---------------------------------------------------------------------------
# PHP bootstrap: preserve original public inputs/default behavior. Keep only
# agreed source refs plus internal hardening constants.
# ---------------------------------------------------------------------------
p = read("bash/php-cli-setup.sh")
old = '''LEGACY_UID_ENV="$(printenv UID 2>/dev/null || true)"
: "${SCRIPTOMATIC_UID:=${LEGACY_UID_ENV:-1000}}"
: "${SCRIPTOMATIC_GID:=${GID:-1000}}"
: "${LINUX_PKG:=}"
: "${LINUX_PKG_VERSIONED:=}"
: "${PHP_EXT:=}"
: "${PHP_EXT_VERSIONED:=}"
: "${MSMTP_FROM:=dev@localhost}"
: "${COMPOSER_VERSION:=2.10.3}"
: "${SCRIPTOMATIC_REF:=main}"
: "${SCRIPTOMATIC_BASE_URL:=https://raw.githubusercontent.com/infocyph/Scriptomatic}"
: "${TOOLSET_REF:=2.0}"
: "${TOOLSET_RELEASE_BASE_URL:=https://github.com/infocyph/Toolset/releases/download}"
: "${PHP_EXT_INSTALLER_VERSION:=2.11.12}"
: "${PHP_EXT_INSTALLER_SHA256:=7c133ae4b9490d912287188c62ea570729cfa74f0ea357e4be672ce696b4aa29}"
: "${PHP_EXT_INSTALLER_BASE_URL:=https://github.com/mlocati/docker-php-extension-installer/releases/download}"
: "${SCRIPTOMATIC_PASSWORDLESS_SUDO:=1}"
: "${SCRIPTOMATIC_OH_MY_BASH:=1}"
: "${OHMYBASH_REF:=abf846186ab0a8a41ec5888e827ece6277dfe446}"
: "${OHMYBASH_REPO_URL:=https://github.com/ohmybash/oh-my-bash.git}"
: "${DOWNLOAD_CONNECT_TIMEOUT:=5}"
: "${DOWNLOAD_MAX_TIME:=90}"
: "${DOWNLOAD_ATTEMPTS:=4}"
'''
new = '''LEGACY_UID_ENV="$(printenv UID 2>/dev/null || true)"
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
'''
p = exact(p, old, new, "php public knobs")
p = p.replace("SCRIPTOMATIC_UID", "TARGET_UID").replace("SCRIPTOMATIC_GID", "TARGET_GID")
p = sub1(p, r'\nvalidate_flag\(\) \{.*?\n\}\n', '\n', "php validate_flag")
for line in [
    '  validate_flag SCRIPTOMATIC_PASSWORDLESS_SUDO "$SCRIPTOMATIC_PASSWORDLESS_SUDO"\n',
    '  validate_flag SCRIPTOMATIC_OH_MY_BASH "$SCRIPTOMATIC_OH_MY_BASH"\n',
    '  [[ "$PHP_EXT_INSTALLER_VERSION" =~ ^[0-9]+([.][0-9]+){2}$ ]] || fatal "invalid PHP_EXT_INSTALLER_VERSION"\n',
    '  [[ "$PHP_EXT_INSTALLER_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || fatal "invalid PHP_EXT_INSTALLER_SHA256"\n',
    '  [[ -z "$COMPOSER_VERSION" || "$COMPOSER_VERSION" =~ ^[0-9]+([.][0-9]+){1,3}([.-][A-Za-z0-9._-]+)?$ ]] || fatal "invalid COMPOSER_VERSION"\n',
    '  validate_uint DOWNLOAD_CONNECT_TIMEOUT "$DOWNLOAD_CONNECT_TIMEOUT"\n',
    '  validate_uint DOWNLOAD_MAX_TIME "$DOWNLOAD_MAX_TIME"\n',
    '  validate_uint DOWNLOAD_ATTEMPTS "$DOWNLOAD_ATTEMPTS"\n',
]:
    p = p.replace(line, "")
p = sub1(
    p,
    r'install_php_extension_installer\(\) \{.*?\n\}\n\ninstall_toolset_helper\(\)',
    '''install_php_extension_installer() {
  local source="$WORKDIR/install-php-extensions"
  download "$IPE_URL" "$source"
  bash -n "$source"
  chmod 0755 "$source"
  printf '%s' "$source"
}

install_toolset_helper()''',
    "php extension installer",
)
p = sub1(
    p,
    r'  extensions=\("\$\{php_ext\[@\]\}" "\$\{php_ext_versioned\[@\]\}"\)\n.*?\n  if \[\[ -f /usr/local/etc/php-fpm.d/zz-docker.conf \]\]; then',
    '''  extensions=("${php_ext[@]}" "${php_ext_versioned[@]}")
  local installer
  installer="$(install_php_extension_installer)"
  "$installer" @composer "${extensions[@]}"

  if [[ -f /usr/local/etc/php-fpm.d/zz-docker.conf ]]; then''',
    "php composer/extensions",
)
p = sub1(
    p,
    r'  if \[\[ "\$SCRIPTOMATIC_PASSWORDLESS_SUDO" == 1 \]\]; then\n.*?\n  fi\n\n  mkdir -p',
    '''  printf '%s ALL=(ALL) NOPASSWD:ALL\\n' "$USERNAME" > "/etc/sudoers.d/${USERNAME}"
  chmod 0440 "/etc/sudoers.d/${USERNAME}"

  mkdir -p''',
    "php sudo default",
)
p = sub1(
    p,
    r'configure_oh_my_bash\(\) \{.*?\n\}\n\nadd_banner_snippet\(\)',
    '''configure_oh_my_bash() {
  printf '👉 Configuring Oh My Bash for %s…\\n' "$USERNAME"

  if [[ ! -d "${HOME_DIR}/.oh-my-bash" ]]; then
    local installer="$WORKDIR/oh-my-bash-install.sh"
    download "$OHMB_URL" "$installer"
    bash -n "$installer"
    run_as_user bash -s -- --unattended < "$installer"
  fi

  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"
  sed -i '
    s/^[[:space:]]*#\\?[[:space:]]*OSH_THEME=.*/OSH_THEME="lambda"/
    s/^[[:space:]]*#\\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/
    s/^[[:space:]]*#\\?[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/
    /^[[:space:]]*#\\?[[:space:]]*plugins=([[:space:]]*$/,/^[[:space:]]*)[[:space:]]*$/c\\plugins=(git bashmarks colored-man-pages npm xterm)
  ' "$BASHRC" || true
}

add_banner_snippet()''',
    "php oh-my-bash",
)
write("bash/php-cli-setup.sh", p)


# ---------------------------------------------------------------------------
# Node bootstrap: same rule. Preserve existing UID/GID, package/global inputs,
# npm update behavior and Oh My Bash/sudo defaults. No invented policy knobs.
# ---------------------------------------------------------------------------
n = read("bash/node-cli-setup.sh")
old = '''LEGACY_UID_ENV="$(printenv UID 2>/dev/null || true)"
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
'''
new = '''LEGACY_UID_ENV="$(printenv UID 2>/dev/null || true)"
TARGET_UID="${LEGACY_UID_ENV:-1000}"
TARGET_GID="${GID:-1000}"
: "${LINUX_PKG:=}"
: "${LINUX_PKG_VERSIONED:=}"
: "${NODE_GLOBAL:=}"
: "${NODE_GLOBAL_VERSIONED:=}"
: "${NODE_LOG_DIR:=/var/log/node-app}"
: "${SCRIPTOMATIC_REF:=main}"
: "${TOOLSET_REF:=2.0}"

SCRIPTOMATIC_BASE_URL="https://raw.githubusercontent.com/infocyph/Scriptomatic"
TOOLSET_RELEASE_BASE_URL="https://github.com/infocyph/Toolset/releases/download"
OHMB_URL="https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh"
DOWNLOAD_CONNECT_TIMEOUT=5
DOWNLOAD_MAX_TIME=90
DOWNLOAD_ATTEMPTS=4
'''
n = exact(n, old, new, "node public knobs")
n = n.replace("SCRIPTOMATIC_UID", "TARGET_UID").replace("SCRIPTOMATIC_GID", "TARGET_GID")
n = sub1(n, r'\nvalidate_flag\(\) \{.*?\n\}\n', '\n', "node validate_flag")
for line in [
    '  validate_flag SCRIPTOMATIC_REPRODUCIBLE "$SCRIPTOMATIC_REPRODUCIBLE"\n',
    '  validate_flag SCRIPTOMATIC_PASSWORDLESS_SUDO "$SCRIPTOMATIC_PASSWORDLESS_SUDO"\n',
    '  validate_flag SCRIPTOMATIC_OH_MY_BASH "$SCRIPTOMATIC_OH_MY_BASH"\n',
    '  [[ -z "$NPM_VERSION" || "$NPM_VERSION" =~ ^[0-9]+([.][0-9]+){1,3}(-[A-Za-z0-9._-]+)?$ ]] || fatal "NPM_VERSION must be an exact numeric version"\n',
    '  validate_uint DOWNLOAD_CONNECT_TIMEOUT "$DOWNLOAD_CONNECT_TIMEOUT"\n',
    '  validate_uint DOWNLOAD_MAX_TIME "$DOWNLOAD_MAX_TIME"\n',
    '  validate_uint DOWNLOAD_ATTEMPTS "$DOWNLOAD_ATTEMPTS"\n',
]:
    n = n.replace(line, "")
# Keep array-safe execution, but don't invent exact-version policy.
n = sub1(
    n,
    r'      npm-name\).*?\n        ;;\n      npm-versioned\).*?\n        ;;',
    '''      npm)
        [[ "$token" != -* && "$token" =~ ^[^[:space:]]+$ ]] || fatal "unsafe npm package token: $token"
        ;;''',
    "node npm token policy",
)
n = n.replace('parse_csv "$NODE_GLOBAL" npm-name globals', 'parse_csv "$NODE_GLOBAL" npm globals')
n = n.replace('parse_csv "$NODE_GLOBAL_VERSIONED" npm-versioned versioned_globals', 'parse_csv "$NODE_GLOBAL_VERSIONED" npm versioned_globals')
n = re.sub(r'  if \[\[ "\$SCRIPTOMATIC_REPRODUCIBLE" == 1 && \$\{#globals\[@\]\} -gt 0 \]\]; then\n    fatal .*?\n  fi\n\n', '', n)
n = re.sub(r'  if \[\[ -n "\$NPM_VERSION" \]\]; then\n.*?\n  fi\n\n', "  printf '👉 Updating npm…\\n'\n  npm install -g npm@latest || npm install -g npm@next || true\n\n", n, count=1, flags=re.S)
n = sub1(
    n,
    r'  if \[\[ "\$SCRIPTOMATIC_PASSWORDLESS_SUDO" == 1 \]\]; then\n.*?\n  fi\n\n  mkdir -p',
    '''  printf '%s ALL=(ALL) NOPASSWD:ALL\\n' "$USERNAME" > "/etc/sudoers.d/${USERNAME}"
  chmod 0440 "/etc/sudoers.d/${USERNAME}"

  mkdir -p''',
    "node sudo default",
)
n = sub1(
    n,
    r'configure_oh_my_bash\(\) \{.*?\n\}\n\nadd_banner_snippet\(\)',
    '''configure_oh_my_bash() {
  printf '👉 Configuring Oh My Bash for %s…\\n' "$USERNAME"

  if [[ ! -d "${HOME_DIR}/.oh-my-bash" ]]; then
    local installer="$WORKDIR/oh-my-bash-install.sh"
    download "$OHMB_URL" "$installer"
    bash -n "$installer"
    run_as_user bash -s -- --unattended < "$installer"
  fi

  [[ -f "$BASHRC" ]] || run_as_user touch "$BASHRC"
  sed -i '
    s/^[[:space:]]*#\\?[[:space:]]*OSH_THEME=.*/OSH_THEME="lambda"/
    s/^[[:space:]]*#\\?[[:space:]]*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/
    s/^[[:space:]]*#\\?[[:space:]]*plugins=(.*)/plugins=(git bashmarks colored-man-pages npm xterm)/
    /^[[:space:]]*#\\?[[:space:]]*plugins=([[:space:]]*$/,/^[[:space:]]*)[[:space:]]*$/c\\plugins=(git bashmarks colored-man-pages npm xterm)
  ' "$BASHRC" || true
}

add_banner_snippet()''',
    "node oh-my-bash",
)
write("bash/node-cli-setup.sh", n)


# ---------------------------------------------------------------------------
# Runtime entrypoints: preserve existing public/default behavior. Remove only
# newly invented policy knobs; retain concrete CA-state and double-run fixes.
# ---------------------------------------------------------------------------
node_entry = read("bash/node-entry.sh")
for line in [
    ': "${NODE_AUTO_INSTALL:=1}"\n',
    ': "${NODE_ALLOW_LOCKFILE_FALLBACK:=1}"\n',
    ': "${ROOTCA_DEST:=/usr/local/share/ca-certificates/rootCA.crt}"\n',
    ': "${ROOTCA_REQUIRED:=0}"\n',
    'validate_flag NODE_AUTO_INSTALL "$NODE_AUTO_INSTALL"\n',
    'validate_flag NODE_ALLOW_LOCKFILE_FALLBACK "$NODE_ALLOW_LOCKFILE_FALLBACK"\n',
    'validate_flag ROOTCA_REQUIRED "$ROOTCA_REQUIRED"\n',
    '  [ "$NODE_AUTO_INSTALL" = 1 ] || return 0\n',
    '    [ "$NODE_ALLOW_LOCKFILE_FALLBACK" = 1 ] || return 1\n',
]:
    node_entry = node_entry.replace(line, "")
# There are three lockfile fallback checks; remove any remaining copies.
node_entry = node_entry.replace('    [ "$NODE_ALLOW_LOCKFILE_FALLBACK" = 1 ] || return 1\n', '')
node_entry = node_entry.replace('"$ROOTCA_DEST"', '"/usr/local/share/ca-certificates/rootCA.crt"')
node_entry = node_entry.replace('[ "$ROOTCA_REQUIRED" = 1 ] && return 1\n    return 0', 'return 0')
node_entry = node_entry.replace('[ "$ROOTCA_REQUIRED" = 1 ] && return 1\n  fi', ':\n  fi')
write("bash/node-entry.sh", node_entry)

php_entry = read("bash/php-entry.sh")
php_entry = php_entry.replace('ROOTCA_DEST="${ROOTCA_DEST:-/usr/local/share/ca-certificates/rootCA.crt}"\n', '')
php_entry = php_entry.replace('ROOTCA_REQUIRED="${ROOTCA_REQUIRED:-0}"\n', '')
php_entry = php_entry.replace('"$ROOTCA_DEST"', '"/usr/local/share/ca-certificates/rootCA.crt"')
php_entry = php_entry.replace('[ "$ROOTCA_REQUIRED" = "1" ] && return 1\n    return 0', 'return 0')
php_entry = php_entry.replace('[ "$ROOTCA_REQUIRED" = "1" ] && return 1\n      return 0', 'return 0')
php_entry = php_entry.replace('[ "$ROOTCA_REQUIRED" = "1" ] && return 1\n    fi', ':\n    fi')
write("bash/php-entry.sh", php_entry)


# ---------------------------------------------------------------------------
# Certbot: keep original fixed service names and 12h infinite renewal policy.
# Only correct exact container detection and remove docker TTY allocation.
# ---------------------------------------------------------------------------
write("bash/certbot-hook.sh", '''#!/usr/bin/env bash

container_running() {
  [[ "$(docker container inspect --format '{{.State.Running}}' "$1" 2>/dev/null || true)" == "true" ]]
}

if container_running NGINX; then
  echo "Reloading Nginx..."
  docker exec NGINX nginx -s reload
fi

if container_running APACHE; then
  echo "Reloading Apache..."
  docker exec APACHE apachectl graceful
fi
''')
write("bash/certbot-renew.sh", main_file("bash/certbot-renew.sh"))


# ---------------------------------------------------------------------------
# Mongo: preserve the exact rs0/member topology. Keep only readiness,
# idempotency and modern-shell compatibility as implementation fixes.
# ---------------------------------------------------------------------------
write("bash/mongo-replica.sh", '''#!/usr/bin/env bash
set -Eeuo pipefail

MONGO_URI="mongodb://127.0.0.1:27017"
MONGO_READY_TIMEOUT_SECONDS=60
MONGO_READY_INTERVAL_SECONDS=2
MONGO_INIT_TIMEOUT_SECONDS=60

log() { printf 'mongo-replica: %s\\n' "$*" >&2; }
fatal() { log "$*"; exit 1; }

if command -v mongosh >/dev/null 2>&1; then
  MONGO_SHELL=mongosh
elif command -v mongo >/dev/null 2>&1; then
  MONGO_SHELL=mongo
else
  fatal "mongosh or mongo is required"
fi

mongo_eval() {
  "$MONGO_SHELL" --quiet "$MONGO_URI" --eval "$1"
}

deadline=$((SECONDS + MONGO_READY_TIMEOUT_SECONDS))
until mongo_eval 'quit(db.adminCommand({ping:1}).ok === 1 ? 0 : 1)' >/dev/null 2>&1; do
  (( SECONDS < deadline )) || fatal "MongoDB did not become ready within ${MONGO_READY_TIMEOUT_SECONDS}s"
  sleep "$MONGO_READY_INTERVAL_SECONDS"
done

check_script='try { const cfg=rs.conf(); const desired=["mongo-primary:27017","mongo-secondary1:27017","mongo-secondary2:27017"]; if (cfg._id !== "rs0" || !cfg.members || cfg.members.length !== 3) quit(42); for (let i=0;i<3;i++){ if (cfg.members[i]._id !== i || cfg.members[i].host !== desired[i]) quit(42); } quit(0); } catch (e) { const msg=String((e && (e.codeName || e.message)) || e); const code=(e && e.code) || 0; if (code === 94 || /NotYetInitialized|no replset config|not yet initialized/i.test(msg)) quit(3); print(msg); quit(43); }'
set +e
mongo_eval "$check_script" >/dev/null 2>&1
state=$?
set -e

case "$state" in
  0)
    log "replica set already initialized"
    exit 0
    ;;
  3)
    echo "Initiating Replica Set..."
    mongo_eval 'const result=rs.initiate({_id:"rs0",members:[{_id:0,host:"mongo-primary:27017"},{_id:1,host:"mongo-secondary1:27017"},{_id:2,host:"mongo-secondary2:27017"}]}); if (!result || result.ok !== 1) { printjson(result); quit(1); }' >/dev/null
    ;;
  42)
    fatal "existing replica-set topology conflicts with Scriptomatic rs0 topology"
    ;;
  *)
    fatal "unable to inspect replica-set state"
    ;;
esac

deadline=$((SECONDS + MONGO_INIT_TIMEOUT_SECONDS))
until mongo_eval "$check_script" >/dev/null 2>&1; do
  (( SECONDS < deadline )) || fatal "replica set did not converge within ${MONGO_INIT_TIMEOUT_SECONDS}s"
  sleep "$MONGO_READY_INTERVAL_SECONDS"
done
''')


# Tests: remove assertions for interfaces that no longer exist, and keep
# behavior/bug regression coverage.
sec = read("tests/security-audit.sh")
sec = sec.replace('assert_absent \'npm@latest|npm@next\' "Node setup must not float npm implicitly" "$ROOT/bash/node-cli-setup.sh"\n', '')
sec = sec.replace('assert_absent \'NODE_LOG_ENABLED:=1|NODE_KEEPALIVE_ON_FAIL:=1|NODE_AUTO_INSTALL:=1\' "Node runtime mutation/convenience must not be default-on" "$ROOT/bash/node-entry.sh"\n', '')
write("tests/security-audit.sh", sec)

# Remove tests for opt-out/policy knobs introduced during hardening.
for path in ["tests/php-bootstrap.sh", "tests/node-bootstrap.sh", "tests/node-entry.sh", "tests/php-entry.sh", "tests/certbot.sh", "tests/mongo-replica.sh"]:
    text = read(path)
    text = re.sub(r'(?ms)^.*(?:COMPOSER_VERSION|PHP_EXT_INSTALLER_VERSION|SCRIPTOMATIC_PASSWORDLESS_SUDO|SCRIPTOMATIC_OH_MY_BASH|NPM_VERSION|SCRIPTOMATIC_REPRODUCIBLE|NODE_AUTO_INSTALL|NODE_ALLOW_LOCKFILE_FALLBACK|ROOTCA_REQUIRED|CERTBOT_NGINX_CONTAINER|CERTBOT_APACHE_CONTAINER|CERTBOT_RELOAD_TIMEOUT_SECONDS|CERTBOT_RENEW_|MONGO_RS_NAME|MONGO_MEMBERS|MONGO_READY_|MONGO_INIT_|MONGO_SHELL).*?\n(?=pass |$)', '', text)
    write(path, text)

# Guard against accidental reintroduction of the unsolicited public knobs.
for path in ["bash/php-cli-setup.sh", "bash/node-cli-setup.sh", "bash/node-entry.sh", "bash/php-entry.sh", "bash/certbot-hook.sh", "bash/certbot-renew.sh", "bash/mongo-replica.sh"]:
    text = read(path)
    forbidden = [
        "COMPOSER_VERSION", "PHP_EXT_INSTALLER_VERSION", "PHP_EXT_INSTALLER_SHA256",
        "NPM_VERSION", "SCRIPTOMATIC_REPRODUCIBLE", "SCRIPTOMATIC_PASSWORDLESS_SUDO",
        "SCRIPTOMATIC_OH_MY_BASH", "NODE_AUTO_INSTALL", "NODE_ALLOW_LOCKFILE_FALLBACK",
        "ROOTCA_REQUIRED", "ROOTCA_DEST", "CERTBOT_NGINX_CONTAINER",
        "CERTBOT_APACHE_CONTAINER", "CERTBOT_RENEW_MAX_FAILURES", "MONGO_RS_NAME",
        "MONGO_MEMBERS", "MONGO_SHELL=",
    ]
    hits = [name for name in forbidden if name in text]
    if hits:
        raise SystemExit(f"{path}: unsolicited public knobs remain: {hits}")

print("scope-preservation source cleanup applied")
