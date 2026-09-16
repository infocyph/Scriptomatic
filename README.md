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

The runtime/bootstrap scripts are designed around container semantics:

- PHP setup targets Alpine official-PHP-image conventions.
- Node setup targets Alpine official Node image conventions.
- build/bootstrap mutation runs as root; normal PHP/Node runtime runs as the configured non-root developer user.
- shared executables under `/usr/local/bin` stay root-owned and mode `0755`.
- application logging defaults to Docker stdout/stderr rather than hidden file logging.
- runtime entrypoints preserve final `exec` semantics so container exit codes and signals reach the application.
- mounted root-CA handling is content-aware and idempotent.
- automation helpers never require an interactive TTY.
- service-to-service defaults use Docker/container DNS names rather than static IP addresses.

LocalDevStack may explicitly enable trusted development conveniences such as passwordless sudo. Scriptomatic does not silently enable them.

## Script inventory

| Script | Shell | Role | Main mutation / privilege | Network | LocalDevStack relevance |
| --- | --- | --- | --- | --- | --- |
| `bash/php-cli-setup.sh` | Bash | PHP image bootstrap | root; packages/users/PHP/FPM/profile config | HTTPS | critical PHP build path |
| `bash/php-entry.sh` | POSIX sh | PHP runtime entrypoint | optional mounted CA refresh | no | critical PHP runtime path |
| `bash/node-cli-setup.sh` | Bash | Node image bootstrap | root; packages/users/npm/profile config | HTTPS/npm | critical Node build path |
| `bash/node-entry.sh` | POSIX sh | Node runtime entrypoint | optional CA/dependency install by explicit policy | optional | critical Node runtime path |
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
SCRIPTOMATIC_PASSWORDLESS_SUDO=1 \
bash /usr/local/bin/cli-setup.sh dockery 8.4
```

`SCRIPTOMATIC_PASSWORDLESS_SUDO=1` is appropriate only for an explicitly trusted development container that needs non-root runtime CA/bootstrap operations. The default is disabled.

Other important inputs include:

```text
SCRIPTOMATIC_UID
SCRIPTOMATIC_GID
LINUX_PKG
LINUX_PKG_VERSIONED
PHP_EXT
PHP_EXT_VERSIONED
MSMTP_FROM
COMPOSER_VERSION
SCRIPTOMATIC_OH_MY_BASH
PHP_EXT_INSTALLER_VERSION
PHP_EXT_INSTALLER_SHA256
```

`COMPOSER_VERSION` is optional and exact. When unset, Scriptomatic does not perform an implicit Composer self-update.

## Node bootstrap

Typical Docker build invocation:

```bash
SCRIPTOMATIC_REF=main \
TOOLSET_REF=2.0 \
SCRIPTOMATIC_PASSWORDLESS_SUDO=1 \
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

The entrypoint defaults to:

```text
NODE_LOG_ENABLED=0
NODE_KEEPALIVE_ON_FAIL=0
NODE_AUTO_INSTALL=0
NODE_ALLOW_LOCKFILE_FALLBACK=0
```

Direct container arguments are preferred. `NODE_CMD` remains only a trusted shell-expression compatibility escape hatch.

## Service helpers

### Certbot

`certbot-hook.sh` performs exact Docker container inspection and bounded non-interactive reloads. Defaults:

```text
CERTBOT_NGINX_CONTAINER=NGINX
CERTBOT_APACHE_CONTAINER=APACHE
CERTBOT_RELOAD_TIMEOUT_SECONDS=20
```

An absent optional target is skipped. A configured container that exists but is stopped, or whose reload command fails, makes the hook fail.

`certbot-renew.sh` is designed to run as a foreground service-container process. It supports configurable interval/jitter, clean `SIGTERM`/`SIGINT` shutdown, and a failure threshold so repeated ACME failures do not remain silent forever.

### Mongo replica bootstrap

`mongo-replica.sh` prefers `mongosh`, with legacy `mongo` supported only as an available/explicit fallback. Defaults use Docker-DNS member endpoints:

```text
MONGO_RS_NAME=rs0
MONGO_MEMBERS=mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017
MONGO_URI=mongodb://127.0.0.1:27017
```

The script polls readiness with a bounded timeout, initializes only an uninitialized replica set, accepts an already matching topology, and fails on a conflicting existing topology.

## LocalDevStack integration

Normal LocalDevStack development may follow Scriptomatic `main`. Reproducible/rollback builds should pass an immutable commit through `SCRIPTOMATIC_REF` and propagate that same ref into the bootstrap script.

LocalDevStack remains responsible for image composition, Docker networks/service names, mounted CA/config volumes, and choosing when trusted development conveniences are enabled. Those orchestration concerns are intentionally not hard-coded into Scriptomatic.

## Validation

Permanent CI covers:

- Bash/POSIX syntax and ShellCheck;
- PHP Alpine bootstrap and repeated/idempotent execution;
- Node Alpine bootstrap, existing-UID reuse and fresh-user paths;
- runtime entrypoint exit/signal behavior;
- shared utility integration;
- Certbot/Mongo service-helper fixtures;
- repository-wide security audit;
- aggregate CI gate.
