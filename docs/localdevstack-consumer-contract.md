# LocalDevStack Consumer Contract

This document records the integration boundary between `infocyph/Scriptomatic` and `infocyph/LocalDevStack`.

Scriptomatic owns reusable bootstrap/runtime script behavior. LocalDevStack owns image composition, Compose profiles, networks, service/container names, mounted files, Docker socket exposure, and whether stricter overrides are enabled.

## Source selection

Normal development may follow Scriptomatic `main`:

```text
SCRIPTOMATIC_REF=main
```

A reproducible LocalDevStack build should use the exact Scriptomatic commit it was validated against:

```text
SCRIPTOMATIC_REF=<40-character-commit-sha>
```

The selected value must be passed into `php-cli-setup.sh` / `node-cli-setup.sh` so every sibling Scriptomatic helper is fetched from the same ref.

Toolset remains independently pinned through:

```text
TOOLSET_REF=2.0
```

Do not fetch Toolset executables from a mutable branch.

## Current downstream migration identified during hardening

The LocalDevStack planning branch `plan/docker-ecosystem-bottom-up` currently contains PHP and Node Dockerfiles that bootstrap from:

```text
https://raw.githubusercontent.com/infocyph/Scriptomatic/master/...
```

That is incompatible with the hardened source contract and the repository's canonical `main` branch.

The downstream implementation phase should replace the hard-coded remote `ADD` with an explicit `SCRIPTOMATIC_REF` build argument and a bounded fetch, then propagate the same ref into the setup script.

Recommended shape:

```dockerfile
ARG SCRIPTOMATIC_REF=main
ARG SCRIPTOMATIC_BASE_URL=https://raw.githubusercontent.com/infocyph/Scriptomatic
ARG TOOLSET_REF=2.0

RUN apk add --no-cache bash curl ca-certificates && \
    curl --fail --location --silent --show-error \
      --connect-timeout 5 --max-time 90 --retry 3 \
      "${SCRIPTOMATIC_BASE_URL}/${SCRIPTOMATIC_REF}/bash/php-cli-setup.sh" \
      -o /usr/local/bin/cli-setup.sh && \
    SCRIPTOMATIC_REF="${SCRIPTOMATIC_REF}" \
    SCRIPTOMATIC_BASE_URL="${SCRIPTOMATIC_BASE_URL}" \
    TOOLSET_REF="${TOOLSET_REF}" \
    SCRIPTOMATIC_UID="${UID}" \
    SCRIPTOMATIC_GID="${GID}" \
    bash /usr/local/bin/cli-setup.sh "${USERNAME}" "${PHP_VERSION}"
```

Use the analogous Node bootstrap path for `node-cli-setup.sh`.

The exact LocalDevStack Dockerfile implementation remains a LocalDevStack responsibility; the contract above is what Scriptomatic guarantees.

## UID / GID handoff

Current setup scripts continue to accept Docker build ARG-style `UID`/`GID` values for compatibility, but new downstream Dockerfiles should pass the explicit names:

```text
SCRIPTOMATIC_UID
SCRIPTOMATIC_GID
```

This avoids ambiguity with Bash's readonly `UID` shell variable and makes the privileged identity boundary obvious.

## Trusted development defaults

Scriptomatic was written for trusted LocalDevStack developer containers. Hardening therefore preserves these historical defaults instead of silently changing the development experience:

```text
SCRIPTOMATIC_PASSWORDLESS_SUDO=1
SCRIPTOMATIC_OH_MY_BASH=1
```

If a particular image does not need runtime sudo/CA mutation or the Oh My Bash developer shell, explicitly set the relevant flag to `0`.

PHP also keeps Composer available by default, now pinned through:

```text
COMPOSER_VERSION=2.10.3
```

This removes the old floating self-update without removing Composer from existing builds.

`ROOTCA_REQUIRED=1` should be used only when failure to install/update a mounted CA must make container startup fail. The default CA path remains best-effort.

## Shell behavior

Scriptomatic helpers installed under `/usr/local/bin` are standalone executables with their own shebangs.

LocalDevStack may open:

```text
bash
sh
sh -l
```

The existing Bash developer-shell behavior, including Oh My Bash, aliases and the Scriptomatic banner, is preserved. Presentation failure is non-critical. Non-login `sh` is not required to source Bash-specific profile configuration. Application entrypoints do not depend on interactive shell startup.

## Banner behavior

The banner remains part of the developer-shell identity and retains its original visual contract:

- centered INFOCYPH figlet;
- three-row description box;
- full rotating credit set;
- original ChromaCat box-style pool.

The hardening change is fallback-only: non-TTY, `NO_COLOR`, missing `figlet`, or missing/failing `chromacat` produces readable plain output rather than redesigning the banner.

## PHP container contract

LocalDevStack PHP images should provide:

- official Alpine PHP image conventions;
- Bash for `php-cli-setup.sh`;
- network access during image bootstrap for selected Scriptomatic/Toolset/extension assets;
- writable PHP/FPM system configuration during the root build step;
- non-root runtime after setup;
- mounted root CA only when required;
- `/usr/local/bin/php-entry` as the runtime entrypoint when using Scriptomatic entrypoint behavior.

The setup script validates PHP/FPM configuration before completing.

## Node container contract

LocalDevStack Node images should provide:

- official Alpine Node image conventions;
- Bash for `node-cli-setup.sh`;
- the selected `NODE_VERSION` from the actual image runtime;
- non-root runtime after setup;
- a writable configured Node log directory when default file logging is used.

The established Node runtime defaults remain:

```text
NODE_LOG_ENABLED=1
NODE_KEEPALIVE_ON_FAIL=1
NODE_AUTO_INSTALL=1
NODE_ALLOW_LOCKFILE_FALLBACK=1
```

LocalDevStack can opt into stricter behavior by setting any of these to `0`. Direct container command arguments remain preferred over `NODE_CMD`.

`NPM_VERSION` no longer floats to `latest`; unset means use the npm version supplied by the selected Node image, while an exact version may be specified when needed.

## Notification contract

`docknotify` defaults intentionally match the LocalDevStack tools/notification service convention:

```text
NOTIFY_HOST=SERVER_TOOLS
NOTIFY_TCP_PORT=9901
DOCKNOTIFY_STRICT=0
```

The payload is one tab-separated newline-terminated record:

```text
TOKEN<TAB>TIMEOUT_MS<TAB>URGENCY<TAB>SOURCE<TAB>TITLE<TAB>BODY<LF>
```

The notification service is optional. Application startup must not depend on it unless strict mode is explicitly enabled. Optional timeout/urgency/length tuning keeps the historical permissive fallback behavior.

## Service/Docker DNS contract

Scriptomatic does not embed LocalDevStack static network addresses.

Service helper defaults use names such as:

```text
NGINX
APACHE
SERVER_TOOLS
mongo-primary
mongo-secondary1
mongo-secondary2
```

LocalDevStack may override names, but should keep service-to-service communication on Docker DNS rather than `172.x` address assumptions.

`mongo-replica.sh` separates `MONGO_URI` (where the shell connects) from `MONGO_MEMBERS` (the replica-set-advertised Docker-DNS endpoints), allowing execution either inside the primary Mongo container or from another service container.

Current LocalDevStack Mongo remains a single-node profile; Scriptomatic's replica defaults are therefore a reusable future/optional contract rather than something hard-coded into the current compose topology.

## Certbot control behavior

`certbot-hook.sh` requires Docker CLI/socket access because it reloads Nginx/Apache containers. Do not mount/expose the Docker socket to unrelated PHP/Node application containers merely for this helper.

The hook preserves the historical “reload if running” semantics: absent or stopped optional target containers are skipped. Exact inspection, no-TTY execution, reload timeout, and actual reload-failure reporting are hardening improvements.

`certbot-renew.sh` preserves unlimited retries by default (`CERTBOT_RENEW_MAX_FAILURES=0`) while adding signal-aware shutdown and backoff/diagnostics. A positive threshold is an explicit downstream choice.

## Downstream validation checklist

Before LocalDevStack adopts a new Scriptomatic commit, validate:

1. PHP image builds with explicit `SCRIPTOMATIC_REF`/`TOOLSET_REF` and configured UID/GID.
2. Default PHP image still contains Composer, sudo-capable developer shell, Oh My Bash, aliases and the original banner presentation.
3. Node image builds through both upstream UID-1000 reuse and any configured fresh-user path.
4. Default Node entrypoint still logs, auto-installs/falls back, and keeps an unrunnable developer container alive; strict opt-outs also work.
5. PHP and direct Node runtime commands propagate process exits/signals.
6. mounted root CA refresh works under the preserved sudo policy.
7. `bash`, `sh`, and `sh -l` remain usable for their intended roles.
8. `docknotify` reaches `SERVER_TOOLS:9901` when enabled and remains harmless when absent.
9. Certbot/Mongo helpers use configured container/service names and Docker DNS.
10. no LocalDevStack Dockerfile still downloads Scriptomatic from `master` or Toolset from a mutable branch.
