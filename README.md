# Scriptomatic

Scriptomatic is Infocyph's collection of shell bootstrap, container-entrypoint, developer-shell, and service helper scripts.

## Distribution policy

`main` is the canonical Scriptomatic distribution source. A tag or GitHub Release is not required.

Canonical raw form:

```text
https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/<script>.sh
```

Consumers that need reproducible Scriptomatic builds may pin a full commit SHA in the same URL shape. PHP/Node bootstrap also accepts `SCRIPTOMATIC_REF=main` (default) or the same full commit SHA so every sibling Scriptomatic helper is fetched from the identical source revision.

Toolset is consumed through its **latest stable GitHub Release installer**, not from the mutable Toolset source branch. PHP/Node bootstrap downloads `https://github.com/infocyph/Toolset/releases/latest/download/install.sh` and uses that installer to install `gitx` and `chromacat` into `/usr/local/bin`. The Toolset installer verifies each selected tool against the latest release's `SHA256SUMS` before installation.

The permanent CI suite verifies this contract and rejects stale Scriptomatic `master` self-references, mutable Toolset `main` consumption, tag/release workflows for Scriptomatic, and tag-triggered Scriptomatic publishing behavior.

## Script surface

| Script | Shell | Role | Typical privilege |
|---|---|---|---|
| `bash/php-cli-setup.sh` | Bash | Alpine/PHP developer-image bootstrap | root |
| `bash/php-entry.sh` | POSIX sh | PHP entrypoint wrapper and local-CA bootstrap | runtime user/root via sudo when available |
| `bash/node-cli-setup.sh` | Bash | Alpine/Node developer-image bootstrap | root |
| `bash/node-entry.sh` | POSIX sh | Node application entrypoint | runtime user |
| `bash/alias-maker.sh` | Bash | developer aliases and shell helpers | target user |
| `bash/banner.sh` | Bash | interactive INFOCYPH banner | user |
| `bash/docknotify.sh` | Bash | best-effort TCP notification client | user |
| `bash/certbot-hook.sh` | Bash | reload web containers after certificate deployment | Docker access |
| `bash/certbot-renew.sh` | Bash | periodic Certbot renewal loop | Certbot/Docker environment |
| `bash/mongo-replica.sh` | Bash | MongoDB replica-set bootstrap | MongoDB access |
| `bash/owners.sh` | Bash | Git ownership-analysis helper | user |

Detailed contracts and dependencies are documented in [`docs/script-contracts.md`](docs/script-contracts.md). Security assumptions are documented in [`docs/security-review.md`](docs/security-review.md). Downstream integration notes are in [`docs/downstream-compatibility.md`](docs/downstream-compatibility.md).

## PHP bootstrap

```bash
curl -fsSLo /usr/local/bin/cli-setup.sh \
  https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/php-cli-setup.sh
chmod +x /usr/local/bin/cli-setup.sh
SCRIPTOMATIC_REF=main /usr/local/bin/cli-setup.sh dev 8.4
```

For a reproducible Scriptomatic build, replace `main` in the download URL with a full commit SHA and pass that same SHA through `SCRIPTOMATIC_REF`. Toolset remains on its latest stable release channel.

The script is intentionally designed for Alpine-based official-style PHP images. It preserves the existing package/extension inputs:

- `UID`, `GID`
- `LINUX_PKG`, `LINUX_PKG_VERSIONED`
- `PHP_EXT`, `PHP_EXT_VERSIONED`
- `MSMTP_FROM`

It also installs the existing developer helpers (`gitx`, `chromacat`, `show-banner`, `docknotify`, `php-entry`, and `alias-maker`), configures PHP/FPM, Mailpit/msmtp, Composer home, the developer user, sudo, and the shell environment.

## Node bootstrap

```bash
curl -fsSLo /usr/local/bin/cli-setup.sh \
  https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/node-cli-setup.sh
chmod +x /usr/local/bin/cli-setup.sh
SCRIPTOMATIC_REF=main /usr/local/bin/cli-setup.sh dev 24
```

For a reproducible Scriptomatic build, replace `main` in the download URL with a full commit SHA and pass that same SHA through `SCRIPTOMATIC_REF`. Toolset remains on its latest stable release channel.

The script is intentionally designed for Alpine-based official-style Node images. Existing inputs remain supported:

- `UID`, `GID`
- `LINUX_PKG`, `LINUX_PKG_VERSIONED`
- `NODE_GLOBAL`, `NODE_GLOBAL_VERSIONED`
- `NODE_LOG_DIR`

The upstream `node` user/UID reuse behavior, passwordless sudo, Corepack best-effort enablement, npm update fallback, user npm prefix/cache, helper installation, and shell setup remain part of the compatibility contract.

## Server helper contracts

`certbot-renew.sh` keeps the established fixed 12-hour renewal interval and `/usr/local/bin/reload-services` deploy hook. `mongo-replica.sh` keeps the established `rs0` topology with `mongo-primary:27017`, `mongo-secondary1:27017`, and `mongo-secondary2:27017`. Their hardening improves readiness, shutdown, idempotency, conflict handling, and diagnostics without turning those established defaults into a new configuration surface.

## Testing

Run locally:

```bash
bash tests/static.sh
bash tests/smoke.sh
bash tests/security-audit.sh
bash tests/main-contract.sh
bash tests/php-bootstrap.sh
bash tests/php-entry.sh
bash tests/node-bootstrap.sh
bash tests/node-entry.sh
bash tests/alias-maker.sh
bash tests/banner.sh
bash tests/docknotify.sh
bash tests/owners.sh
bash tests/server-baseline.sh
bash tests/certbot.sh
bash tests/mongo-replica.sh
```

Set `SCRIPTOMATIC_FULL_INTEGRATION=1` for the PHP and Node bootstrap tests to exercise disposable upstream Docker images when Docker is available.

## Compatibility rule

Hardening work preserves established behavior by default. Validation, quoting, bounded network calls, safer temporary files, idempotency, clearer diagnostics, and correctness fixes are allowed. A change that necessarily alters an established external contract must be decided explicitly instead of being introduced silently.
