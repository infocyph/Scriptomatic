# Script Contracts

Scriptomatic's primary execution context is Docker containers, especially `infocyph/LocalDevStack`. The contracts below preserve the interfaces and defaults already present on `main`; hardening does not create a parallel configuration framework.

## Shared source selectors

The PHP and Node bootstrap scripts intentionally add only:

```text
SCRIPTOMATIC_REF=main
TOOLSET_REF=2.0
```

Scriptomatic sibling helpers use the selected Scriptomatic ref. Toolset helpers use the stable Toolset `2.0` release and its `SHA256SUMS`.

## `php-cli-setup.sh`

Invocation:

```text
bash php-cli-setup.sh USERNAME PHP_VERSION
```

Existing inputs:

```text
UID
GID
LINUX_PKG
LINUX_PKG_VERSIONED
PHP_EXT
PHP_EXT_VERSIONED
MSMTP_FROM
```

Behavior remains the established Alpine PHP development bootstrap: base packages, PHP extensions, Composer through `install-php-extensions @composer`, PHP/FPM/msmtp configuration, passwordless sudo, Oh My Bash (`lambda` + existing plugins), banner, aliases and helper tools.

Hardening is implementation-only: validated/array-safe inputs, bounded downloads, private temp paths, same-ref Scriptomatic helpers, Toolset `2.0` checksum verification, root-owned shared executables, idempotent FPM include handling and config validation. The setup no longer clears all shared `/tmp`/`/var/tmp` content or deletes itself.

There is no `COMPOSER_VERSION`, PHP-extension-installer-version, sudo-mode or Oh-My-Bash-mode public API.

## `php-entry.sh`

Existing public CA input:

```text
ROOTCA_PATH
```

The destination remains `/usr/local/share/ca-certificates/rootCA.crt` and failure remains best-effort as before. The old `/tmp/.rootca_installed` marker is replaced by content comparison so changed CA content can refresh.

Final process behavior remains:

```sh
exec docker-php-entrypoint "$@"
```

## `node-cli-setup.sh`

Invocation:

```text
bash node-cli-setup.sh USERNAME NODE_VERSION
```

Existing inputs:

```text
UID
GID
LINUX_PKG
LINUX_PKG_VERSIONED
NODE_GLOBAL
NODE_GLOBAL_VERSIONED
NODE_LOG_DIR
```

Existing behavior remains: upstream UID reuse/rename when needed, passwordless sudo, Oh My Bash, npm cache/global prefix, optional global packages, and the build-time npm update:

```text
npm install -g npm@latest || npm install -g npm@next || true
```

Hardening validates inputs and final user identity, makes package execution argv-safe, uses same-ref Scriptomatic helpers, verifies Toolset `2.0`, and keeps shared executables root-owned. No npm-version/reproducibility/sudo/Oh-My-Bash policy API is introduced.

## `node-entry.sh`

Existing inputs/defaults remain, including:

```text
NODE_LOG_ENABLED=1
NODE_LOG_DIR=/var/log/node-app
NODE_ACCESS_LOG_FILE=access.log
NODE_ERROR_LOG_FILE=error.log
NODE_KEEPALIVE_ON_FAIL=1
HOST=0.0.0.0
PORT=3000
NPM_AUDIT=0
NPM_FUND=0
NODE_CMD
ROOTCA_PATH
```

Automatic dependency installation and existing npm/pnpm/yarn fallbacks stay automatic. No new auto-install or lockfile-fallback switches are introduced.

Concrete fixes only:

- root CA refresh uses content comparison instead of a stale `/tmp` stamp;
- a successful generic `npm run dev` compatibility attempt is not run twice.

## `alias-maker.sh`

The aliases and helper functions remain those from `main`. Repeated execution remains supported. No new alias format/capability-selection interface is introduced.

## `banner.sh`

The original interactive presentation is preserved:

- `INFOCYPH` figlet layout;
- centered content;
- three-row description box;
- rotating credit pool;
- original ChromaCat box-style pool.

Hardening only supplies plain fallback when `figlet`/`chromacat`/TTY styling is unavailable or `NO_COLOR` is set.

## `docknotify.sh`

Existing environment/options and best-effort behavior remain. The real protocol record is still:

```text
token<TAB>timeout<TAB>urgency<TAB>source<TAB>title<TAB>body<LF>
```

Hardening fixes the lost trailing newline and prevents token/protocol-separator leakage without changing the normal call shape.

## `owners.sh`

Human output remains:

```text
filename owner1 owner2 ...
```

Git filename enumeration is NUL-safe internally so spaces and unusual names are not shell-split.

## `certbot-hook.sh`

The fixed targets remain:

```text
NGINX
APACHE
```

The existing behavior is still “reload if running.” The concrete fixes are exact container inspection and non-interactive `docker exec` (no `-it`). No new Certbot configuration interface is added.

## `certbot-renew.sh`

This remains the original foreground loop:

```text
certbot renew --quiet --deploy-hook /usr/local/bin/reload-services
sleep 12h
```

repeated indefinitely. No new interval/jitter/failure-threshold API is added.

## `mongo-replica.sh`

The topology remains fixed exactly as on `main`:

```text
rs0
mongo-primary:27017
mongo-secondary1:27017
mongo-secondary2:27017
```

Hardening replaces the fixed `sleep 10` with readiness polling, prefers `mongosh` with `mongo` fallback, treats an already matching topology as success, and refuses to overwrite a conflicting topology. These are lifecycle/correctness fixes, not a new Mongo configuration interface.
