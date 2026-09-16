# Script Contracts

This document defines the stable behavioral boundaries for Scriptomatic scripts. The primary execution environment is inside Docker containers; `infocyph/LocalDevStack` is the main downstream consumer, but its orchestration remains outside Scriptomatic.

## Shared source/download contract

Scriptomatic itself follows `main` by default:

```text
SCRIPTOMATIC_REF=main
SCRIPTOMATIC_BASE_URL=https://raw.githubusercontent.com/infocyph/Scriptomatic
```

A reproducible consumer should set `SCRIPTOMATIC_REF` to an immutable commit SHA. Every sibling helper fetched by a bootstrap script uses that same selected ref.

Toolset is consumed through its stable released artifact contract:

```text
TOOLSET_REF=2.0
TOOLSET_RELEASE_BASE_URL=https://github.com/infocyph/Toolset/releases/download
```

Toolset helpers are checksum-verified. Remote executable acquisition uses finite connection/operation timeouts, retry, private temporary storage, syntax validation, and atomic installation where practical.

## Container-wide invariants

- build/bootstrap mutation runs as root;
- application runtime is non-root where the PHP/Node images select a developer user;
- `/usr/local/bin` helpers stay `root:root` and mode `0755`;
- automation does not require a TTY;
- direct runtime commands use `exec` so exit codes/signals remain container-visible;
- compatibility-oriented developer conveniences remain defaults where LocalDevStack historically relied on them, but have explicit opt-outs;
- service endpoints should use Docker DNS/container/service names rather than static IP addresses;
- root-CA refresh is content-aware and repeatable;
- temporary data is private/owned; scripts do not broadly clear shared `/tmp` trees or delete themselves.

## `php-cli-setup.sh`

Purpose: build-time bootstrap for Alpine official-PHP-image layouts.

Invocation:

```text
bash php-cli-setup.sh USERNAME PHP_VERSION
```

Privilege: root required.

Important environment:

```text
SCRIPTOMATIC_UID / SCRIPTOMATIC_GID
LINUX_PKG / LINUX_PKG_VERSIONED
PHP_EXT / PHP_EXT_VERSIONED
MSMTP_FROM
COMPOSER_VERSION=2.10.3
SCRIPTOMATIC_PASSWORDLESS_SUDO=1
SCRIPTOMATIC_OH_MY_BASH=1
PHP_EXT_INSTALLER_VERSION / PHP_EXT_INSTALLER_SHA256
SCRIPTOMATIC_REF / SCRIPTOMATIC_BASE_URL
TOOLSET_REF / TOOLSET_RELEASE_BASE_URL
```

Behavior:

- validates privileged inputs and package/extension tokens before mutation;
- requires the Alpine/PHP-image capability set rather than pretending to be distro-generic;
- preserves Composer as a default developer tool, now pinned to `2.10.3` rather than floating through self-update;
- permits another exact `COMPOSER_VERSION` override;
- uses the pinned/verified PHP-extension installer;
- installs Toolset `gitx`/`chromacat` from stable Toolset `2.0`;
- installs Scriptomatic sibling helpers from the same `SCRIPTOMATIC_REF`;
- generates and validates PHP/FPM configuration;
- leaves shared executables root-owned;
- preserves passwordless sudo and Oh My Bash as trusted-development defaults; set either flag to `0` to opt out;
- preserves the original Oh My Bash `lambda` theme and plugin set (`git bashmarks colored-man-pages npm xterm`) while using an immutable upstream ref.

Exit: non-zero on invalid input, dependency/integrity failure, user/config failure, or PHP/FPM validation failure.

## `php-entry.sh`

Purpose: transparent wrapper around `docker-php-entrypoint` plus optional mounted root-CA refresh.

Environment:

```text
ROOTCA_PATH
ROOTCA_DEST
ROOTCA_REQUIRED=0|1
```

Unchanged CA content is not reinstalled. The default remains best-effort, matching the old entrypoint behavior; `ROOTCA_REQUIRED=1` makes failure explicit. The final application path is:

```sh
exec docker-php-entrypoint "$@"
```

so exit codes/signals are preserved.

## `node-cli-setup.sh`

Purpose: build-time bootstrap for Alpine official Node images.

Invocation:

```text
bash node-cli-setup.sh USERNAME NODE_VERSION
```

Privilege: root required.

Important environment:

```text
SCRIPTOMATIC_UID / SCRIPTOMATIC_GID
LINUX_PKG / LINUX_PKG_VERSIONED
NODE_GLOBAL / NODE_GLOBAL_VERSIONED
NPM_VERSION
SCRIPTOMATIC_REPRODUCIBLE=0|1
NODE_LOG_DIR
SCRIPTOMATIC_PASSWORDLESS_SUDO=1
SCRIPTOMATIC_OH_MY_BASH=1
SCRIPTOMATIC_REF / SCRIPTOMATIC_BASE_URL
TOOLSET_REF / TOOLSET_RELEASE_BASE_URL
```

Behavior:

- validates package/global-package input;
- preserves useful upstream UID reuse/rename behavior and verifies final identity/home/shell/ownership;
- preserves sudo and Oh My Bash as the LocalDevStack developer defaults with explicit opt-outs;
- preserves the original `lambda` Oh My Bash theme/plugin set via an immutable pinned upstream ref;
- intentionally does **not** float npm to `latest`; unset `NPM_VERSION` keeps the npm supplied by the chosen Node image, while an exact version may be requested;
- reproducible mode rejects unversioned requested global packages;
- installs Toolset and sibling Scriptomatic helpers using the shared source contract;
- leaves shared helpers root-owned.

## `node-entry.sh`

Purpose: preserve the established LocalDevStack developer-entrypoint behavior while making command selection and CA handling safer.

Compatibility defaults:

```text
NODE_LOG_ENABLED=1
NODE_KEEPALIVE_ON_FAIL=1
NODE_AUTO_INSTALL=1
NODE_ALLOW_LOCKFILE_FALLBACK=1
```

All four behaviors can be explicitly disabled with `0` for stricter/production-like images.

Direct container arguments are preferred and are `exec`'d. `NODE_CMD` is a trusted shell-expression compatibility escape hatch and keeps the historical `HOSTNAME` / `NUXT_HOST` / `NUXT_PORT` environment injection.

When dependency installation is enabled, lockfile-strict installation is tried first and the historical mutable fallback remains enabled by default. Set `NODE_ALLOW_LOCKFILE_FALLBACK=0` to make lockfile failure strict.

The generic `dev` path preserves the old two-form fallback intent but fixes the old accidental double execution of a successful dev command.

When no runnable app starts, keepalive remains enabled by default for developer containers; set `NODE_KEEPALIVE_ON_FAIL=0` to fail instead.

## `alias-maker.sh`

Purpose: manage Scriptomatic's established alias set in the target user's `.bashrc`.

Contract: alias names/semantics are preserved; repeated execution is idempotent, managed replacement is atomic, unrelated user content is preserved, and optional-tool aliases degrade cleanly.

## `banner.sh`

Purpose: preserve Scriptomatic's established interactive presentation.

Contract:

- retains centered `INFOCYPH` figlet output;
- retains the original three-row description box;
- retains the full rotating credit list;
- retains the full original ChromaCat box-style list;
- adds graceful plain fallback when `figlet`/`chromacat` is unavailable, ChromaCat fails, output is non-TTY, or `NO_COLOR` is set;
- presentation failure never makes shell startup fail.

Hardening must not redesign the banner.

## `docknotify.sh`

Purpose: best-effort LocalDevStack/container notification transport.

Defaults:

```text
NOTIFY_HOST=SERVER_TOOLS
NOTIFY_TCP_PORT=9901
DOCKNOTIFY_STRICT=0
```

The original first-two-positional-arguments behavior is preserved; additional positional arguments remain ignored. Invalid optional timeout/urgency/length/strict tuning values fall back to the historical defaults instead of making notification fatal. Host/port validity and token protocol separators remain hard validation boundaries.

Protocol fields are sanitized/capped and sent as one tab-separated line with a real trailing newline. `NOTIFY_TOKEN` is never printed in failure diagnostics. Send failure is ignored by default and becomes fatal only with `DOCKNOTIFY_STRICT=1`.

## `owners.sh`

Purpose: repository ownership analysis.

Dependencies: `git`, `git-fame`.

Contract: Git path enumeration is NUL-safe internally, but the established human-facing output remains one row per file in the original shape:

```text
filename owner1 owner2 ...
```

No TSV header or output-format redesign is introduced. Tabs/newlines in unusual filenames are escaped only enough to keep one logical file per displayed row.

## `certbot-hook.sh`

Purpose: Certbot deploy hook that reloads optional web-server containers.

Environment:

```text
CERTBOT_NGINX_CONTAINER=NGINX
CERTBOT_APACHE_CONTAINER=APACHE
CERTBOT_RELOAD_TIMEOUT_SECONDS=20
```

Contract:

- requires Docker CLI/socket access and `timeout`;
- exact `docker container inspect` identity is used instead of substring matching;
- absent or stopped optional targets are skipped, preserving the original “reload if running” behavior;
- reload is non-interactive (`docker exec`, never `-t`/`-it`);
- reload is bounded by timeout;
- actual Docker inspection errors and reload failures propagate non-zero.

An empty configured container name disables that target.

## `certbot-renew.sh`

Purpose: foreground Certbot renewal service loop suitable for a container/supervisor process.

Environment:

```text
CERTBOT_BIN=certbot
CERTBOT_DEPLOY_HOOK=/usr/local/bin/reload-services
CERTBOT_RENEW_INTERVAL_SECONDS=43200
CERTBOT_RENEW_JITTER_SECONDS=0
CERTBOT_RENEW_FAILURE_BACKOFF_SECONDS=60
CERTBOT_RENEW_MAX_FAILURES=0
CERTBOT_RENEW_ONCE=0
```

Contract:

- `SIGTERM`/`SIGINT` interrupt sleep and stop cleanly;
- successful cycles reset the consecutive-failure count;
- failed cycles are diagnosed and back off;
- the compatibility default `CERTBOT_RENEW_MAX_FAILURES=0` keeps retrying indefinitely as the old loop did;
- setting a positive failure threshold explicitly opts into container termination after repeated failures;
- `CERTBOT_RENEW_ONCE=1` supports deterministic one-cycle execution/testing.

## `mongo-replica.sh`

Purpose: initialize/validate a Mongo replica set after bounded readiness.

Defaults:

```text
MONGO_URI=mongodb://127.0.0.1:27017
MONGO_RS_NAME=rs0
MONGO_MEMBERS=mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017
MONGO_READY_TIMEOUT_SECONDS=60
MONGO_READY_INTERVAL_SECONDS=2
MONGO_INIT_TIMEOUT_SECONDS=60
MONGO_SHELL=
```

The original `rs0`/three-member topology defaults are preserved. `mongosh` is preferred, with legacy `mongo` retained as a compatibility fallback.

Hardening replaces only unsafe lifecycle behavior: fixed startup sleep becomes bounded readiness, matching existing topology is idempotent success, uninitialized topology is initiated once, and conflicting existing topology fails rather than being rewritten implicitly.

## LocalDevStack boundary

Scriptomatic owns script behavior. LocalDevStack owns image composition, build args, mounted files, network/service names, Docker socket exposure, notification service availability, and choosing stricter overrides when desired.

The downstream handoff is documented in [`localdevstack-consumer-contract.md`](localdevstack-consumer-contract.md).
