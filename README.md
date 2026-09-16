# Scriptomatic

Scriptomatic is Infocyph's shared shell-script and runtime-bootstrap repository. It provides reusable build/runtime helpers without turning them into a versioned CLI suite.

## Source policy

`main` is the canonical Scriptomatic source. Consumers may override `SCRIPTOMATIC_REF` with a branch or immutable commit when rollback/reproducibility is required.

Sibling Scriptomatic helpers fetched by setup scripts always use the same selected `SCRIPTOMATIC_REF`.

Toolset is consumed separately through its stable release contract. Current default:

```text
TOOLSET_REF=2.0
```

## Script inventory

| Script | Shell | Class | Privilege / mutation | Network | LocalDevStack critical |
| --- | --- | --- | --- | --- | --- |
| `bash/php-cli-setup.sh` | Bash | PHP image bootstrap | root; packages/users/config | yes | yes |
| `bash/node-cli-setup.sh` | Bash | Node image bootstrap | root; packages/users/config | yes | yes |
| `bash/php-entry.sh` | POSIX sh | PHP runtime entrypoint | optional CA install | no | yes |
| `bash/node-entry.sh` | POSIX sh | Node runtime entrypoint | optional CA/log/deps | possible | yes |
| `bash/alias-maker.sh` | Bash | developer-shell UX | user `.bashrc` | no | yes |
| `bash/banner.sh` | Bash | presentation | none | no | yes |
| `bash/docknotify.sh` | Bash | optional notification transport | none | TCP | yes, non-critical |
| `bash/owners.sh` | Bash | repository analysis | none | no | no |
| `bash/certbot-hook.sh` | Bash | server hook | Docker container reload | Docker socket | no |
| `bash/certbot-renew.sh` | Bash | server renewal loop | Certbot state | ACME | no |
| `bash/mongo-replica.sh` | Bash | Mongo service bootstrap | replica-set state | Mongo | optional |

Detailed contracts live in [`docs/script-contracts.md`](docs/script-contracts.md). Security boundaries live in [`docs/security-review.md`](docs/security-review.md).

## PHP bootstrap

```bash
SCRIPTOMATIC_REF=main \
TOOLSET_REF=2.0 \
COMPOSER_VERSION=2.10.3 \
bash bash/php-cli-setup.sh developer 8.4
```

Important inputs include `SCRIPTOMATIC_UID`, `SCRIPTOMATIC_GID`, `LINUX_PKG`, `LINUX_PKG_VERSIONED`, `PHP_EXT`, `PHP_EXT_VERSIONED`, `MSMTP_FROM`, `COMPOSER_VERSION`, `SCRIPTOMATIC_PASSWORDLESS_SUDO`, and `SCRIPTOMATIC_OH_MY_BASH`.

`SCRIPTOMATIC_PASSWORDLESS_SUDO=1` is intended only for explicitly trusted development containers.

## Validation

Repository CI runs syntax checks, ShellCheck, utility/runtime smoke tests, PHP/Node integration fixtures, server-helper fixtures, and a cross-cutting security audit.

The implementation plans under `docs/plans/` are temporary and are deleted before the final merge once the hardening program is complete.
