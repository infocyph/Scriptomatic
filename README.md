# Scriptomatic

Scriptomatic is Infocyph's shared shell-script/bootstrap repository. Its main use is inside Docker development and service containers, especially `infocyph/LocalDevStack`.

Scriptomatic itself does not need a tag/release lifecycle. `main` is the normal source. A downstream build may pin an exact commit through `SCRIPTOMATIC_REF` when it wants a reproducible snapshot.

## Source contract

Two source selectors are intentionally supported by the PHP/Node setup scripts:

```text
SCRIPTOMATIC_REF=main
TOOLSET_REF=2.0
```

Sibling Scriptomatic helpers are fetched from the selected Scriptomatic ref. Toolset helpers (`gitx`, `chromacat`) are fetched from Toolset's stable `2.0` release and verified with that release's `SHA256SUMS`.

These selectors do not change the rest of Scriptomatic's established bootstrap behavior.

## Existing Docker bootstrap inputs

PHP setup keeps the existing inputs:

```text
USERNAME argument
PHP_VERSION argument
UID
GID
LINUX_PKG
LINUX_PKG_VERSIONED
PHP_EXT
PHP_EXT_VERSIONED
MSMTP_FROM
```

Node setup keeps the existing inputs:

```text
USERNAME argument
NODE_VERSION argument
UID
GID
LINUX_PKG
LINUX_PKG_VERSIONED
NODE_GLOBAL
NODE_GLOBAL_VERSIONED
NODE_LOG_DIR
```

No Composer-version, PHP-extension-installer-version, npm-version, reproducibility-mode, sudo-mode, or Oh-My-Bash-mode configuration API is added.

## PHP bootstrap behavior

`bash/php-cli-setup.sh` continues to target Alpine official PHP/FPM images and keeps the existing LocalDevStack developer-container behavior:

- installs the existing base/package inputs;
- obtains `install-php-extensions` from its existing `releases/latest` URL;
- installs Composer through `install-php-extensions @composer` together with requested PHP extensions;
- creates the non-root development user with the existing `UID` / `GID` inputs;
- enables passwordless sudo as before;
- installs and configures Oh My Bash with the existing `lambda` theme/plugins;
- configures PHP/FPM, msmtp, Composer home, banner hook and aliases;
- installs Scriptomatic helpers and Toolset helpers.

Hardening underneath that behavior includes bounded downloads, array-safe package/extension invocation, private temporary files, root-owned shared executables, same-ref Scriptomatic helper retrieval, Toolset `2.0` checksum verification, idempotent FPM includes and configuration validation. Broad `/tmp/*` cleanup and setup-script self-deletion are removed.

## Node bootstrap behavior

`bash/node-cli-setup.sh` keeps the existing developer workflow:

- Alpine Node image assumptions;
- reuse/rename of the upstream UID-1000 `node` account when appropriate;
- passwordless sudo;
- Oh My Bash with the existing theme/plugins;
- `npm install -g npm@latest || npm install -g npm@next || true` at build time;
- the existing user npm cache/global prefix;
- optional `NODE_GLOBAL` and `NODE_GLOBAL_VERSIONED` packages;
- banner and aliases.

Hardening adds validated/array-safe inputs, verified final UID/GID/home/shell state, same-ref Scriptomatic helpers, Toolset `2.0` checksum verification, private temporary files and root-owned shared executables without introducing a new npm/versioning policy.

## Runtime entrypoints

### PHP

`bash/php-entry.sh` still performs best-effort mounted root-CA installation and finally:

```sh
exec docker-php-entrypoint "$@"
```

The old `/tmp/.rootca_installed` marker is replaced by content comparison so a changed mounted CA can be refreshed. The public CA input remains `ROOTCA_PATH`; the system destination remains the existing `/usr/local/share/ca-certificates/rootCA.crt`.

### Node

`bash/node-entry.sh` preserves the existing defaults and inputs, including:

```text
NODE_LOG_ENABLED=1
NODE_LOG_DIR=/var/log/node-app
NODE_KEEPALIVE_ON_FAIL=1
HOST=0.0.0.0
PORT=3000
NPM_AUDIT=0
NPM_FUND=0
NODE_CMD
ROOTCA_PATH
```

Automatic dependency installation and the existing npm/pnpm/yarn fallback behavior remain automatic; no new enable/disable policy variables are added.

Two concrete runtime defects are corrected:

- mounted root-CA refresh is content-aware instead of using a stale global `/tmp` marker;
- a successful generic `npm run dev` compatibility attempt is not executed a second time.

## Other scripts

- `alias-maker.sh` keeps the aliases/functions from `main` and their existing repeatable behavior.
- `banner.sh` keeps the INFOCYPH figlet layout, original three-row description box, rotating credits and ChromaCat box-style pool. It only gains graceful plain output when presentation dependencies/TTY capabilities are unavailable.
- `docknotify.sh` keeps the existing host/port/token/source/timeout/urgency interface and best-effort default. The protocol's terminating newline is now actually transmitted and token/protocol separators are handled safely.
- `owners.sh` keeps the original human `file owners...` output shape while using NUL-safe Git filename enumeration.
- `certbot-hook.sh` keeps fixed `NGINX` / `APACHE` targets and reload-if-running semantics. It now uses exact container inspection and non-interactive `docker exec`.
- `certbot-renew.sh` remains the original 12-hour infinite renewal loop.
- `mongo-replica.sh` keeps the original `rs0` topology (`mongo-primary`, `mongo-secondary1`, `mongo-secondary2`). The fixed 10-second startup sleep is replaced by readiness/idempotency checks and `mongosh` is preferred with legacy `mongo` fallback.

## Validation

Permanent CI checks syntax/ShellCheck, PHP and Node Alpine bootstrap, entrypoints, shared utilities, Certbot/Mongo behavior and concrete security/correctness hazards. Tests intentionally avoid inventing configuration interfaces merely to make the fixtures easier to control.

See:

- [`docs/script-contracts.md`](docs/script-contracts.md)
- [`docs/security-review.md`](docs/security-review.md)
- [`docs/localdevstack-consumer-contract.md`](docs/localdevstack-consumer-contract.md)
