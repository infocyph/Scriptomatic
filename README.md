# Scriptomatic

Scriptomatic is Infocyph's shared shell-script and runtime-bootstrap repository. Its primary consumers are Docker images and development/service containers, especially `infocyph/LocalDevStack`.

Scriptomatic is not a versioned CLI suite. Reusable scripts live on `main`; downstream consumers may select an immutable commit when they need reproducibility.

## Source and dependency policy

Default Scriptomatic source:

```text
SCRIPTOMATIC_REF=main
SCRIPTOMATIC_BASE_URL=https://raw.githubusercontent.com/infocyph/Scriptomatic
```

For reproducible Docker builds, set `SCRIPTOMATIC_REF` to a commit SHA. All sibling Scriptomatic helpers fetched by a bootstrap script use that same selected ref.

Toolset is a separate released dependency. Scriptomatic consumes Toolset through the stable release contract:

```text
TOOLSET_REF=2.0
TOOLSET_RELEASE_BASE_URL=https://github.com/infocyph/Toolset/releases/download
```

Toolset executables are not fetched from mutable `main`/`master`.

## Container-first contract

The runtime/bootstrap scripts are designed around container semantics while preserving the established LocalDevStack developer experience:

- PHP setup targets Alpine official-PHP-image conventions.
- Node setup targets Alpine official Node image conventions.
- build/bootstrap mutation runs as root; normal PHP/Node runtime runs as the configured non-root developer user.
- shared executables under `/usr/local/bin` stay root-owned and mode `0755`.
- trusted developer-container sudo and Oh My Bash remain enabled by default for backward compatibility; both can be explicitly disabled.
- Node runtime logging, automatic dependency installation/fallback, and keepalive remain enabled by default; each has an explicit opt-out.
- runtime entrypoints preserve direct-command `exec` semantics, while compatibility fallbacks remain available for the development workflow.
- mounted root-CA handling is content-aware and idempotent.
- automation helpers never require an interactive TTY.
- service-to-service defaults use Docker/container DNS names rather than static IP addresses.

## Script inventory

| Script | Shell | Role | Main mutation / privilege | Network | LocalDevStack relevance |
| --- | --- | --- | --- | --- | --- |
| `bash/php-cli-setup.sh` | Bash | PHP image bootstrap | root; packages/users/PHP/FPM/profile config | HTTPS | critical PHP build path |
| `bash/php-entry.sh` | POSIX sh | PHP runtime entrypoint | optional mounted CA refresh | no | critical PHP runtime path |
| `bash/node-cli-setup.sh` | Bash | Node image bootstrap | root; packages/users/npm/profile config | HTTPS/npm | critical Node build path |
| `bash/node-entry.sh` | POSIX sh | Node runtime entrypoint | optional CA/dependency install | optional | critical Node runtime path |
| `bash/alias-maker.sh` | Bash | developer-shell aliases | user `.bashrc` managed block | no | shell UX |
| `bash/banner.sh` | Bash | presentation | none | no | shell UX; non-critical |
| `bash/docknotify.sh` | Bash | optional container notification transport | none | TCP | optional LocalDevStack notification integration |
| `bash/owners.sh` | Bash | repository ownership analysis | none | no | standalone utility |
| `bash/certbot-hook.sh` | Bash | post-renew service reload | Docker socket/container exec | Docker daemon | service container/helper |
| `bash/certbot-renew.sh` | Bash | Certbot foreground renewal loop | Certbot state | ACME | service container/helper |
| `bash/mongo-replica.sh` | Bash | Mongo replica bootstrap | replica-set state | Mongo | database bootstrap/helper |

Detailed public behavior is documented in [`docs/script-contracts.md`](docs/script-contracts.md). Security boundaries are documented in [`docs/security-review.md`](docs/security-review.md). The LocalDevStack integration boundary is documented in [`docs/localdevstack-consumer-contract.md`](docs/localdevstack-consumer-contract.md).

## PHP bootstrap

Typical Docker build invocation:

```bash
SCRIPTOMATIC_REF=main \
TOOLSET_REF=2.0 \
bash /usr/local/bin/cli-setup.sh dockery 8.4
```

The established development-container defaults remain:

```text
SCRIPTOMATIC_PASSWORDLESS_SUDO=1
SCRIPTOMATIC_OH_MY_BASH=1
COMPOSER_VERSION=2.10.3
```

Set the sudo or Oh My Bash flag to `0` for a stricter image. Composer remains present by default, but is now pinned instead of performing the old floating self-update; provide another exact `COMPOSER_VERSION` to override it.

Other important inputs include:

```text
SCRIPTOMATIC_UID
SCRIPTOMATIC_GID
LINUX_PKG
LINUX_PKG_VERSIONED
PHP_EXT
PHP_EXT_VERSIONED
MSMTP_FROM
PHP_EXT_INSTALLER_VERSION
PHP_EXT_INSTALLER_SHA256
```

## Node bootstrap

Typical Docker build invocation:

```bash
SCRIPTOMATIC_REF=main \
TOOLSET_REF=2.0 \
bash /usr/local/bin/cli-setup.sh dockery "$(node -v | sed 's/^v//')"
```

Important Node inputs include:

```text
SCRIPTOMATIC_UID
SCRIPTOMATIC_GID
LINUX_PKG
LINUX_PKG_VERSIONED
NODE_GLOBAL
NODE_GLOBAL_VERSIONED
NPM_VERSION
SCRIPTOMATIC_REPRODUCIBLE
NODE_LOG_DIR
```

`SCRIPTOMATIC_PASSWORDLESS_SUDO=1` and `SCRIPTOMATIC_OH_MY_BASH=1` remain the developer-container defaults. `NPM_VERSION` is intentionally not floated to `latest`; unset means keep the npm supplied by the selected Node image, while an exact version can be requested explicitly.

The Node entrypoint preserves the historical development defaults:

```text
NODE_LOG_ENABLED=1
NODE_KEEPALIVE_ON_FAIL=1
NODE_AUTO_INSTALL=1
NODE_ALLOW_LOCKFILE_FALLBACK=1
```

Set any of these to `0` for stricter/production-like behavior. Direct container arguments are preferred. `NODE_CMD` remains a trusted shell-expression compatibility escape hatch.

## Banner presentation

The interactive banner preserves the established Scriptomatic presentation: centered `INFOCYPH` figlet output, the original three-row description box, the full rotating credit list, and the original ChromaCat box-style pool. Hardening only adds graceful plain-output fallback for non-TTY/`NO_COLOR`/missing-or-failing presentation dependencies.

## Service helpers

### Certbot

`certbot-hook.sh` performs exact Docker container inspection and bounded non-interactive reloads. Defaults:

```text
CERTBOT_NGINX_CONTAINER=NGINX
CERTBOT_APACHE_CONTAINER=APACHE
CERTBOT_RELOAD_TIMEOUT_SECONDS=20
```

Missing or stopped optional web-server containers are skipped, preserving the original “reload if running” behavior. An actual Docker-inspection error or a reload failure is reported as failure.

`certbot-renew.sh` is designed to run as a foreground service-container process. It supports configurable interval/jitter, clean `SIGTERM`/`SIGINT` shutdown, and diagnostics/backoff. The compatibility default is unlimited renewal retries (`CERTBOT_RENEW_MAX_FAILURES=0`); a positive threshold is available when operators want repeated failures to terminate the container.

### Mongo replica bootstrap

`mongo-replica.sh` prefers `mongosh`, with legacy `mongo` supported as an available/explicit fallback. Defaults preserve the original replica identity/topology while replacing the fixed startup sleep with bounded readiness:

```text
MONGO_RS_NAME=rs0
MONGO_MEMBERS=mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017
MONGO_URI=mongodb://127.0.0.1:27017
```

The script initializes only an uninitialized replica set, accepts an already matching topology, and fails on a conflicting existing topology.

## LocalDevStack integration

Normal LocalDevStack development may follow Scriptomatic `main`. Reproducible/rollback builds should pass an immutable commit through `SCRIPTOMATIC_REF` and propagate that same ref into the bootstrap script.

LocalDevStack remains responsible for image composition, Docker networks/service names, mounted CA/config volumes, and choosing when stricter overrides are desired. Scriptomatic's defaults preserve the existing trusted developer-container behavior unless explicitly overridden.

## Validation

Permanent CI covers:

- Bash/POSIX syntax and ShellCheck;
- compatibility defaults that are relied on by LocalDevStack;
- PHP Alpine bootstrap and repeated/idempotent execution;
- Node Alpine bootstrap, existing-UID reuse and fresh-user paths;
- runtime entrypoint behavior;
- original banner/output contracts plus hardened fallback behavior;
- shared utility integration;
- Certbot/Mongo service-helper fixtures;
- repository-wide security audit;
- aggregate CI gate.
