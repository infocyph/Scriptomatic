# Scriptomatic

Scriptomatic is Infocyph's collection of shell bootstrap, container-entrypoint, developer-shell, and service helper scripts.

## Distribution policy

`main` is the canonical Scriptomatic distribution source. A tag or GitHub Release is not required.

Canonical raw form:

```text
https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/<script>.sh
```

Consumers that need reproducible builds may pin a full commit SHA in the same URL shape, but Scriptomatic itself continues to support direct consumption from `main`.

The permanent CI suite verifies this contract and rejects stale Scriptomatic `master` self-references, tag/release workflows, and tag-triggered publishing behavior.

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
/usr/local/bin/cli-setup.sh dev 8.4
```

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
/usr/local/bin/cli-setup.sh dev 24
```

The script is intentionally designed for Alpine-based official-style Node images. Existing inputs remain supported:

- `UID`, `GID`
- `LINUX_PKG`, `LINUX_PKG_VERSIONED`
- `NODE_GLOBAL`, `NODE_GLOBAL_VERSIONED`
- `NODE_LOG_DIR`

The upstream `node` user/UID reuse behavior, passwordless sudo, Corepack best-effort enablement, npm update fallback, user npm prefix/cache, helper installation, and shell setup remain part of the compatibility contract.

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
