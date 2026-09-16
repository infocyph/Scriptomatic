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
- runtime entrypoints end in `exec` of the selected application process;
- Docker stdout/stderr is the default logging channel;
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
COMPOSER_VERSION
SCRIPTOMATIC_PASSWORDLESS_SUDO=0|1
SCRIPTOMATIC_OH_MY_BASH=0|1
PHP_EXT_INSTALLER_VERSION / PHP_EXT_INSTALLER_SHA256
SCRIPTOMATIC_REF / SCRIPTOMATIC_BASE_URL
TOOLSET_REF / TOOLSET_RELEASE_BASE_URL
```

Behavior:

- validates privileged inputs and package/extension tokens before mutation;
- requires the Alpine/PHP-image capability set rather than pretending to be distro-generic;
- preserves Composer unless an exact `COMPOSER_VERSION` is requested;
- uses the pinned/verified PHP-extension installer;
- installs Toolset `gitx`/`chromacat` from the stable Toolset release;
- installs Scriptomatic sibling helpers from the same `SCRIPTOMATIC_REF`;
- generates and validates PHP/FPM configuration;
- leaves shared executables root-owned;
- passwordless sudo is opt-in and intended for trusted development containers.

Exit: non-zero on invalid input, dependency/integrity failure, user/config failure, or PHP/FPM validation failure.

## `php-entry.sh`

Purpose: transparent wrapper around `docker-php-entrypoint` plus optional mounted root-CA refresh.

Environment:

```text
ROOTCA_PATH
ROOTCA_DEST
ROOTCA_REQUIRED=0|1
```

Unchanged CA content is not reinstalled. When CA mutation requires privilege, the runtime must have the configured capability (for LocalDevStack trusted dev containers this commonly means explicit passwordless sudo at build time). The final application path is:

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
SCRIPTOMATIC_PASSWORDLESS_SUDO=0|1
SCRIPTOMATIC_REF / SCRIPTOMATIC_BASE_URL
TOOLSET_REF / TOOLSET_RELEASE_BASE_URL
```

Behavior:

- validates package/global-package input;
- preserves useful upstream UID reuse/rename behavior and verifies final identity/home/shell/ownership;
- preserves the image's npm unless an exact `NPM_VERSION` is requested;
- reproducible mode rejects unversioned requested global packages;
- installs Toolset and sibling Scriptomatic helpers using the shared source contract;
- leaves shared helpers root-owned.

## `node-entry.sh`

Purpose: select and `exec` one Node application command.

Defaults:

```text
NODE_LOG_ENABLED=0
NODE_KEEPALIVE_ON_FAIL=0
NODE_AUTO_INSTALL=0
NODE_ALLOW_LOCKFILE_FALLBACK=0
```

Direct container arguments are preferred. `NODE_CMD` is a trusted shell-expression compatibility escape hatch and must not be populated from untrusted input.

Runtime dependency installation is explicit. Strict lockfile installs do not silently fall back to mutable installs unless `NODE_ALLOW_LOCKFILE_FALLBACK=1` is explicitly set.

A failed application normally terminates the container; keepalive-on-failure is opt-in only.

## `alias-maker.sh`

Purpose: manage Scriptomatic's alias block in the target user's `.bashrc`.

Contract: repeated execution is idempotent; managed replacement is atomic; unrelated user content is preserved; optional-tool aliases degrade cleanly.

## `banner.sh`

Purpose: optional interactive presentation.

Contract: missing/failing `figlet` or `chromacat`, non-TTY operation, `NO_COLOR`, Unicode, and empty descriptions all degrade to safe plain output. Banner failure must never make shell startup fail.

## `docknotify.sh`

Purpose: best-effort LocalDevStack/container notification transport.

Defaults:

```text
NOTIFY_HOST=SERVER_TOOLS
NOTIFY_TCP_PORT=9901
DOCKNOTIFY_STRICT=0
```

Protocol fields are sanitized/capped and sent as one tab-separated line with a trailing newline. `NOTIFY_TOKEN` is never printed in failure diagnostics. Send failure is ignored by default and becomes fatal only with `DOCKNOTIFY_STRICT=1`.

## `owners.sh`

Purpose: repository ownership analysis.

Dependencies: `git`, `git-fame`.

Contract: Git path enumeration is NUL-safe. Machine-readable output is stable TSV so filenames containing spaces/special characters are not split by the shell.

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
- exact `docker container inspect` identity is used;
- an absent optional target is skipped;
- an existing but stopped target fails;
- reload is non-interactive (`docker exec`, never `-t`/`-it`);
- reload is bounded by timeout;
- reload failure propagates non-zero.

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
CERTBOT_RENEW_MAX_FAILURES=5
CERTBOT_RENEW_ONCE=0
```

Contract:

- `SIGTERM`/`SIGINT` interrupt sleep and stop cleanly;
- successful cycles reset the consecutive-failure count;
- failed cycles are diagnosed;
- the default failure threshold exits non-zero rather than looping silently forever;
- `CERTBOT_RENEW_MAX_FAILURES=0` is an explicit request for unlimited retries;
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

`mongosh` is preferred. Legacy `mongo` is accepted only when explicitly selected or when it is the only available shell.

Member endpoints are deliberately Docker-DNS-friendly and validated before mutation. The connection URI is separately configurable because the bootstrap script may execute inside the primary container (`127.0.0.1`) or from another service container (Docker DNS URI).

State contract:

- wait for ping readiness with a finite deadline;
- matching existing topology -> success/no mutation;
- uninitialized replica set -> initiate requested topology, then wait for convergence;
- conflicting existing replica-set name/member order/hosts -> fail rather than reconciling implicitly;
- unexpected inspection errors -> fail with diagnostics.

## LocalDevStack boundary

Scriptomatic owns script behavior. LocalDevStack owns image composition, build args, mounted files, network/service names, Docker socket exposure, notification service availability, and choosing trusted development options.

The downstream handoff is documented in [`localdevstack-consumer-contract.md`](localdevstack-consumer-contract.md).
