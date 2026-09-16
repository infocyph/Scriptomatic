# Script Contracts

This document defines the stable behavioral boundaries for Scriptomatic scripts. Scriptomatic itself follows `main`; consumers that require an immutable snapshot can set `SCRIPTOMATIC_REF` to a commit SHA.

## Shared download contract

Build/bootstrap scripts use bounded `curl` downloads with finite connect/operation timeouts and retry. Downloaded scripts are syntax-validated before installation. Toolset helpers are fetched from the exact stable Toolset release selected by `TOOLSET_REF` (default `2.0`) and verified against Toolset `SHA256SUMS`.

Scriptomatic sibling helpers are fetched from:

```text
${SCRIPTOMATIC_BASE_URL}/${SCRIPTOMATIC_REF}/bash/<script>
```

Default values:

```text
SCRIPTOMATIC_REF=main
SCRIPTOMATIC_BASE_URL=https://raw.githubusercontent.com/infocyph/Scriptomatic
TOOLSET_REF=2.0
TOOLSET_RELEASE_BASE_URL=https://github.com/infocyph/Toolset/releases/download
```

## `php-cli-setup.sh`

Purpose: build-time bootstrap for supported Alpine official-PHP-image layouts.

Invocation:

```text
bash php-cli-setup.sh USERNAME PHP_VERSION
```

Privilege: must run as root.

Important environment inputs:

- `SCRIPTOMATIC_UID` / `SCRIPTOMATIC_GID` (default 1000; legacy exported `UID`/`GID` remain accepted where applicable)
- `LINUX_PKG`, `LINUX_PKG_VERSIONED`
- `PHP_EXT`, `PHP_EXT_VERSIONED`
- `MSMTP_FROM`
- `COMPOSER_VERSION` (unset means preserve an existing Composer; no implicit self-update)
- `SCRIPTOMATIC_PASSWORDLESS_SUDO=0|1` (default `0`)
- `SCRIPTOMATIC_OH_MY_BASH=0|1` (default `0`)
- `PHP_EXT_INSTALLER_VERSION` / `PHP_EXT_INSTALLER_SHA256`
- shared Scriptomatic/Toolset ref/base-URL inputs

Mutations: Alpine packages, target user/home, PHP/FPM configuration, msmtp/profile files, `/usr/local/bin` helper installation.

Shared `/usr/local/bin` executables remain root-owned mode `0755`.

## `php-entry.sh`

Purpose: transparent wrapper around `docker-php-entrypoint` with optional mounted CA installation.

Environment:

- `ROOTCA_PATH`
- `ROOTCA_DEST`
- `ROOTCA_REQUIRED=0|1`

CA installation is content-aware: unchanged CA content is not reinstalled. The final process is always `exec docker-php-entrypoint "$@"` after bootstrap succeeds/skips.

## `node-cli-setup.sh` / `node-entry.sh`

These remain under active hardening. The target contract is: immutable Toolset consumption, same-ref Scriptomatic helpers, exact optional npm policy, verified user identity, stdout/stderr-first runtime behavior, explicit dependency-install/keepalive policy, and one final `exec` process.

## Shared utilities

`alias-maker.sh` mutates only the selected user's `.bashrc` and must remain idempotent.

`banner.sh` is presentation-only; presentation failure must not prevent an interactive runtime from starting.

`docknotify.sh` is best-effort by default; strict failure is opt-in.

`owners.sh` is a standalone repository-analysis utility and is not part of the critical LocalDevStack contract unless a downstream consumer explicitly adopts it.

## Server helpers

`certbot-hook.sh`, `certbot-renew.sh`, and `mongo-replica.sh` are server/service helpers. They are not LocalDevStack-critical by default and are hardened/tested independently.
