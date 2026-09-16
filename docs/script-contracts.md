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
- **Exit:** non-zero on required setup failure; removes its executing setup-file path at successful completion, preserving the existing bootstrap behavior.

## `php-entry.sh`

- **Shell:** POSIX `sh`.
- **Invocation:** used as a wrapper around `docker-php-entrypoint`.
- **Environment:** `ROOTCA_PATH`.
- **Behavior:** best-effort local CA installation when readable, then transparent `exec docker-php-entrypoint "$@"`.
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

## `node-entry.sh`

- **Shell:** POSIX `sh`.
- **Invocation:** direct command arguments override all auto-detection.
- **Environment:** `APP_DIR`, `NODE_LOG_ENABLED`, `NODE_LOG_DIR`, `NODE_ACCESS_LOG_FILE`, `NODE_ERROR_LOG_FILE`, `NODE_ACCESS_LOG`, `NODE_ERROR_LOG`, `NODE_KEEPALIVE_ON_FAIL`, `ROOTCA_PATH`, `HOST`, `PORT`, `NPM_AUDIT`, `NPM_FUND`, `NODE_CMD`, npm cache variables.
- **Behavior:** optional CA setup, optional dependency install, framework-aware `dev`, `start`, `server.js`, `index.js`, then existing keepalive fallback.
- **Trust boundary:** `NODE_CMD` intentionally remains a shell expression and therefore must come from trusted configuration.

## `alias-maker.sh`

- **Shell:** Bash.
- **Filesystem:** edits `${HOME}/.bashrc` and maintains the marked `scriptomatic-utils` function block.
- **Dependencies:** Bash, optional runtime commands referenced by aliases/functions (`lsd`, Git, `dos2unix`, sudo, npm, Composer/PHP).
- **Behavior:** preserves the current alias names and helper functions.

## `banner.sh`

- **Shell:** Bash.
- **Dependencies:** `figlet` and `chromacat` for the current full presentation.
- **Behavior:** renders the INFOCYPH heading, random credit, random ChromaCat box style, and description.
- **Role:** presentation only; consumers must not make their primary service correctness depend on banner rendering.

## `docknotify.sh`

- **Shell:** Bash.
- **Invocation:** `docknotify [-H host] [-p port] [-t ms] [-u low|normal|critical] [-s source] <title> <body>`.
- **Environment:** `NOTIFY_HOST`, `NOTIFY_TCP_PORT`, `NOTIFY_TOKEN`, `NOTIFY_SOURCE`, `NOTIFY_TITLE_MAX`, `NOTIFY_BODY_MAX`, `DOCKNOTIFY_STRICT`.
- **Dependency:** `nc`.
- **Failure:** best-effort by default; strict mode returns non-zero on send failure.

## `certbot-hook.sh`

- **Shell:** Bash.
- **Dependencies:** Docker CLI/socket access.
- **Behavior:** reloads the expected `NGINX` and `APACHE` containers when present.

## `certbot-renew.sh`

- **Shell:** Bash.
- **Dependencies:** Certbot and the reload hook.
- **Behavior:** runs `certbot renew --quiet --deploy-hook /usr/local/bin/reload-services`, then sleeps 12 hours, indefinitely.

## `mongo-replica.sh`

- **Shell:** Bash.
- **Dependency:** current Mongo shell expected by the deployment.
- **Behavior:** initializes `rs0` with `mongo-primary:27017`, `mongo-secondary1:27017`, and `mongo-secondary2:27017` after the existing startup delay.

## `owners.sh`

- **Shell:** Bash.
- **Dependencies:** Git and `git fame`/git-fame.
- **Behavior:** reports tracked files and author email ownership where line-of-code distribution meets the existing threshold.
