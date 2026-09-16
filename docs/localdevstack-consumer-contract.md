# LocalDevStack Consumer Contract

This document records the integration boundary between `infocyph/Scriptomatic` and `infocyph/LocalDevStack`.

Scriptomatic owns reusable bootstrap/runtime script behavior. LocalDevStack owns image composition, Compose profiles, networks, service/container names, mounted files, Docker socket exposure, and whether trusted-development conveniences are enabled.

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

## Trusted development sudo / root CA

PHP and Node LocalDevStack runtime containers normally run as the non-root developer user. When a root CA is mounted and must be copied into the system trust store at container startup, the entrypoint needs a privilege path.

For a trusted LocalDevStack developer container, build with:

```text
SCRIPTOMATIC_PASSWORDLESS_SUDO=1
```

If LocalDevStack does not need runtime CA mutation, leave the default `0`.

`ROOTCA_REQUIRED=1` should be used only when failure to install/update the mounted CA must make container startup fail. The default remains best-effort.

## Shell behavior

Scriptomatic helpers installed under `/usr/local/bin` are standalone executables with their own shebangs.

LocalDevStack may open:

```text
bash
sh
sh -l
```

The banner/profile hook is login/interactive presentation and is non-critical. Non-login `sh` is not required to source Bash-specific profile configuration. The application entrypoints do not depend on interactive shell startup.

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
- stdout/stderr-first application logging;
- no implicit runtime dependency installation unless `NODE_AUTO_INSTALL=1` is explicitly requested;
- strict lockfile behavior unless `NODE_ALLOW_LOCKFILE_FALLBACK=1` is explicitly requested.

Direct container command arguments are preferred over `NODE_CMD`.

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

The notification service is optional. Application startup must not depend on it unless strict mode is explicitly enabled.

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

`mongo-replica.sh` separates `MONGO_URI` (where the shell connects) from `MONGO_MEMBERS` (the replica-set-advertised Docker-DNS endpoints), allowing execution either inside the primary Mongo container or from a helper container.

## Docker socket/control-plane boundary

`certbot-hook.sh` requires Docker CLI/socket access because it reloads Nginx/Apache containers. Do not mount/expose the Docker socket to unrelated PHP/Node application containers merely for this helper.

Keep Docker-control helpers in the appropriate LocalDevStack control/service container.

## Downstream validation checklist

Before LocalDevStack adopts a new Scriptomatic commit, validate:

1. PHP image builds with explicit `SCRIPTOMATIC_REF`/`TOOLSET_REF` and the configured UID/GID.
2. Node image builds through both upstream UID-1000 reuse and any configured fresh-user path.
3. PHP and Node runtime entrypoints propagate process exits/signals.
4. mounted root CA refresh works under the selected sudo policy.
5. `bash`, `sh`, and `sh -l` remain usable for their intended interactive/non-interactive roles.
6. `docknotify` reaches `SERVER_TOOLS:9901` when the service is enabled and remains harmless when absent.
7. Certbot/Mongo helpers use configured container/service names and Docker DNS.
8. no LocalDevStack Dockerfile still downloads Scriptomatic from `master` or Toolset from a mutable branch.
