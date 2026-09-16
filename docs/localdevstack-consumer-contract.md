# LocalDevStack Consumer Contract

This document records the integration boundary between `infocyph/Scriptomatic` and `infocyph/LocalDevStack` without redefining Scriptomatic's existing behavior.

## Source selection

Normal development may follow:

```text
SCRIPTOMATIC_REF=main
TOOLSET_REF=2.0
```

For a reproducible LocalDevStack build, `SCRIPTOMATIC_REF` may be an accepted Scriptomatic commit SHA. The same ref is then used when PHP/Node bootstrap scripts retrieve sibling Scriptomatic helpers.

The current LocalDevStack planning branch still bootstraps PHP/Node from `Scriptomatic/master`; its later Dockerfile implementation should migrate that to the selected `SCRIPTOMATIC_REF`. Toolset helpers should use stable `2.0`, not Toolset `main`.

## Existing UID / GID contract

Do not rename the existing build inputs. PHP/Node setup continues to consume:

```text
UID
GID
```

along with the existing package/runtime variables defined by the Dockerfiles. Scriptomatic handles Bash's UID special-variable behavior internally; LocalDevStack does not need a new `SCRIPTOMATIC_UID`/`SCRIPTOMATIC_GID` interface.

## PHP development image

The established PHP image behavior remains:

- Alpine official PHP/FPM base;
- Composer installed through `install-php-extensions @composer`;
- passwordless sudo for the development user;
- Oh My Bash with the existing `lambda` theme/plugins;
- PHP/FPM, msmtp, banner, aliases and Composer-home setup;
- non-root runtime through `php-entry`.

LocalDevStack does not need to pass Composer-version, PHP-extension-installer-version, sudo-mode, Oh-My-Bash-mode or root-CA-strictness variables because Scriptomatic does not expose those interfaces.

## Node development image

The established Node image behavior remains:

- Alpine official Node base;
- reuse/rename of the upstream UID-1000 account when needed;
- passwordless sudo;
- Oh My Bash and aliases;
- user npm prefix/cache;
- `npm install -g npm@latest || npm install -g npm@next || true` during bootstrap;
- optional `NODE_GLOBAL` / `NODE_GLOBAL_VERSIONED` packages;
- non-root runtime through `node-entry`.

The Node entrypoint retains existing logging, automatic dependency installation/fallback, `NODE_CMD`, host/port and keepalive behavior. LocalDevStack does not need new auto-install/lockfile-fallback/npm-version policy variables.

## Root CA

Both entrypoints keep the existing mounted CA input:

```text
ROOTCA_PATH
```

System installation remains best-effort and uses `/usr/local/share/ca-certificates/rootCA.crt`. Scriptomatic now compares content instead of relying on `/tmp/.rootca_installed`, so LocalDevStack does not need a new CA state/strictness interface.

## Shell/banner behavior

LocalDevStack developer shells keep the existing Oh My Bash, aliases and Scriptomatic banner. The banner retains its centered INFOCYPH figlet, three-row description box, rotating credits and ChromaCat styles; fallback behavior only prevents presentation failures from breaking non-TTY/basic environments.

## Notification behavior

`docknotify` continues to use the existing LocalDevStack defaults:

```text
NOTIFY_HOST=SERVER_TOOLS
NOTIFY_TCP_PORT=9901
DOCKNOTIFY_STRICT=0
```

The service remains optional/best-effort by default. The hardening fix is protocol correctness, not a new notification policy.

## Certbot

`certbot-hook.sh` continues to target fixed `NGINX` and `APACHE` containers and reload only when running. LocalDevStack does not need container-name/timeout configuration variables from Scriptomatic.

`certbot-renew.sh` remains the existing infinite loop with a 12-hour sleep.

Docker socket exposure remains a LocalDevStack orchestration concern and should stay in the relevant control/service container.

## Mongo

`mongo-replica.sh` continues to own the same fixed topology it had before:

```text
rs0
mongo-primary:27017
mongo-secondary1:27017
mongo-secondary2:27017
```

LocalDevStack does not need new Mongo topology environment variables from Scriptomatic. The script only gains readiness/idempotency/conflict handling.

## Downstream Dockerfile migration

When LocalDevStack reaches its implementation phase, PHP and Node Dockerfiles should replace the hard-coded `Scriptomatic/master` bootstrap URL with an explicit ref, while keeping their existing `UID`, `GID`, package and runtime inputs.

Conceptually:

```dockerfile
ARG SCRIPTOMATIC_REF=main
ARG TOOLSET_REF=2.0
```

Fetch `php-cli-setup.sh` / `node-cli-setup.sh` from that Scriptomatic ref, then invoke them exactly as today with `USERNAME` and the runtime version. The bootstrap script itself receives the Docker `UID`/`GID` environment naturally; no renamed identity interface is required.

LocalDevStack continues to own Compose profiles, networks, mounts, container/service names and image composition. Scriptomatic stays a reusable script repository rather than absorbing LocalDevStack orchestration policy.
