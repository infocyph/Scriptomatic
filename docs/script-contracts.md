# Script Contracts

This document records the current public contract of each Scriptomatic script. `main` is the canonical distribution branch; commit-SHA pinning is an optional consumer choice.

## `php-cli-setup.sh`

- **Shell:** Bash.
- **Invocation:** `php-cli-setup.sh USERNAME PHP_VERSION`.
- **Environment:** `UID`, `GID`, `LINUX_PKG`, `LINUX_PKG_VERSIONED`, `PHP_EXT`, `PHP_EXT_VERSIONED`, `MSMTP_FROM`, plus optional download timeout knobs prefixed `SCRIPTOMATIC_DOWNLOAD_`.
- **Privileges:** root; creates/configures a non-root developer account with the existing passwordless-sudo behavior.
- **Environment assumption:** Alpine-based official-style PHP/FPM image with `/usr/local/etc/php` and PHP-FPM configuration paths.
- **Network:** Alpine repositories, `mlocati/docker-php-extension-installer`, Composer self-update, Toolset `main`, Scriptomatic `main`, and Oh My Bash.
- **Filesystem:** package installation; PHP/FPM configuration; `/etc/msmtprc`; `/etc/profile.d`; developer home; `/usr/local/bin` helpers; sudoers file.
- **Hardening:** remote helper downloads are bounded, staged, checked for non-empty content and syntax where applicable, then installed atomically.
- **Exit:** non-zero on required setup failure; removes its executing setup-file path at successful completion, preserving the existing bootstrap behavior.

## `php-entry.sh`

- **Shell:** POSIX `sh`.
- **Invocation:** used as a wrapper around `docker-php-entrypoint`.
- **Environment:** `ROOTCA_PATH`, optional `SCRIPTOMATIC_ROOTCA_STAMP`.
- **Behavior:** best-effort local CA installation when readable, using a content fingerprint to avoid stale successful state, then transparent `exec docker-php-entrypoint "$@"`.
- **Privileges:** uses direct root operations when root, otherwise sudo when available.

## `node-cli-setup.sh`

- **Shell:** Bash.
- **Invocation:** `node-cli-setup.sh USERNAME NODE_VERSION`.
- **Environment:** `UID`, `GID`, `LINUX_PKG`, `LINUX_PKG_VERSIONED`, `NODE_GLOBAL`, `NODE_GLOBAL_VERSIONED`, `NODE_LOG_DIR`, plus optional download timeout knobs prefixed `SCRIPTOMATIC_DOWNLOAD_`.
- **Privileges:** root; preserves passwordless sudo for the resulting developer account.
- **Environment assumption:** Alpine-based official-style Node image.
- **UID behavior:** if the requested UID is already occupied by the upstream Node account, that account is reused/renamed to the requested user.
- **Network:** Alpine repositories, npm update, optional npm global packages, Toolset `main`, Scriptomatic `main`, and Oh My Bash.
- **Filesystem:** packages; developer user/home; npm cache/global prefix; `/usr/local/bin` helpers; `/etc/profile.d`; sudoers.
- **Hardening:** package/global-package data is argv-safe and helper downloads are bounded, staged and syntax-checked before installation.

## `node-entry.sh`

- **Shell:** POSIX `sh`.
- **Invocation:** direct command arguments override all auto-detection.
- **Environment:** `APP_DIR`, `NODE_LOG_ENABLED`, `NODE_LOG_DIR`, `NODE_ACCESS_LOG_FILE`, `NODE_ERROR_LOG_FILE`, `NODE_ACCESS_LOG`, `NODE_ERROR_LOG`, `NODE_KEEPALIVE_ON_FAIL`, `ROOTCA_PATH`, `HOST`, `PORT`, `NPM_AUDIT`, `NPM_FUND`, `NODE_CMD`, npm cache variables.
- **Behavior:** optional CA setup, optional dependency install, framework-aware `dev`, `start`, `server.js`, `index.js`, then the existing keepalive fallback.
- **Generic dev fallback:** attempts `npm run dev -- --host ... --port ...`, then plain `npm run dev` only if the first attempt fails; a successful trial is not executed a second time.
- **Process semantics:** direct commands and selected final framework/start/server commands use `exec`; trial children receive shutdown signals.
- **Trust boundary:** `NODE_CMD` intentionally remains a trusted shell expression and therefore must come from trusted configuration.

## `alias-maker.sh`

- **Shell:** Bash.
- **Filesystem:** edits `${HOME}/.bashrc` and maintains the marked `scriptomatic-utils` function block.
- **Dependencies:** Bash, optional runtime commands referenced by aliases/functions (`lsd`, Git, `dos2unix`, sudo, npm, Composer/PHP).
- **Behavior:** preserves the current alias names and helper functions.
- **Hardening:** managed-block replacement is idempotent and same-directory/atomic; Git file handling used by EOL helpers is NUL-safe.

## `banner.sh`

- **Shell:** Bash.
- **Dependencies:** `figlet` and `chromacat` provide the full presentation.
- **Behavior:** when presentation dependencies are usable, renders the INFOCYPH heading, random credit, random ChromaCat box style, and description.
- **Fallback:** missing/failed presentation dependencies, non-TTY output, or `NO_COLOR` degrade to plain output instead of making shell/runtime startup fail.
- **Role:** presentation only; consumers must not make their primary service correctness depend on banner rendering.

## `docknotify.sh`

- **Shell:** Bash.
- **Invocation:** `docknotify [-H host] [-p port] [-t ms] [-u low|normal|critical] [-s source] <title> <body>`.
- **Environment:** `NOTIFY_HOST`, `NOTIFY_TCP_PORT`, `NOTIFY_TOKEN`, `NOTIFY_SOURCE`, `NOTIFY_TITLE_MAX`, `NOTIFY_BODY_MAX`, `DOCKNOTIFY_STRICT`.
- **Dependency:** `nc`.
- **Wire contract:** sends one newline-terminated tab-separated record. Token, source, title and body are normalized to a single line before sending.
- **Secrets:** notification tokens are never included in send-failure diagnostics.
- **Failure:** best-effort by default; strict mode returns non-zero on send failure.

## `certbot-hook.sh`

- **Shell:** Bash.
- **Dependencies:** Docker CLI/socket access.
- **Behavior:** reloads the expected `NGINX` and `APACHE` containers only when their exact container state is running.
- **Automation:** uses non-interactive `docker exec`; absent containers are skipped, while a detected-container reload failure returns non-zero.

## `certbot-renew.sh`

- **Shell:** Bash.
- **Dependencies:** Certbot and an executable reload hook.
- **Environment:** `CERTBOT_RENEW_INTERVAL` (default `12h`), `CERTBOT_DEPLOY_HOOK` (default `/usr/local/bin/reload-services`), and `CERTBOT_RENEW_ONCE` (default `0`, useful for bounded execution/tests).
- **Behavior:** runs `certbot renew --quiet --deploy-hook <hook>`, then repeats after the configured interval; the established default remains 12 hours.
- **Shutdown:** INT/TERM stop the recurring loop cleanly.

## `mongo-replica.sh`

- **Shell:** Bash.
- **Dependency:** prefers `mongosh`, with legacy `mongo` fallback.
- **Environment:** `MONGO_REPLICA_SET_NAME`, `MONGO_PRIMARY_HOST`, `MONGO_SECONDARY1_HOST`, `MONGO_SECONDARY2_HOST`, `MONGO_READY_ATTEMPTS`, `MONGO_READY_DELAY`.
- **Defaults:** replica set `rs0` with `mongo-primary:27017`, `mongo-secondary1:27017`, and `mongo-secondary2:27017`.
- **Readiness:** performs bounded ping polling rather than a fixed startup sleep.
- **State:** matching topology is an idempotent success; conflicting topology fails; only Mongo's not-yet-initialized state proceeds to `rs.initiate`.
- **Trust boundary:** replica-set/member override values are validated before being interpolated into Mongo shell JavaScript.

## `owners.sh`

- **Shell:** Bash.
- **Dependencies:** Git and `git fame`/git-fame.
- **Behavior:** reports tracked files and author email ownership where line-of-code distribution meets the existing threshold.
- **Path handling:** tracked filenames are consumed from `git ls-files -z`, preserving spaces and shell-sensitive characters.
