# Security Review

Scriptomatic contains privileged build/bootstrap scripts and runtime helpers. Hardening must preserve the repository's existing external behavior while reducing avoidable implementation risk.

## Distribution trust

Scriptomatic intentionally supports direct installation from `main`. That is a project policy, not an integrity guarantee: consumers that require reproducible builds should pin a full commit SHA.

The PHP and Node setup scripts also consume Toolset from its `main` branch. This remains an accepted compatibility behavior unless the downstream ecosystem separately changes that policy.

## Remote execution

Remote shell content must not be piped directly into a shell. Bootstrap downloads are fetched to temporary files with bounded curl settings, checked for non-empty content and shell syntax where applicable, then executed or installed.

The PHP extension installer continues to use its existing `releases/latest` source and Composer/npm continue their existing update policies; changing those version policies is outside the compatibility-preserving hardening scope.

## Privilege boundary

`php-cli-setup.sh` and `node-cli-setup.sh` are root build scripts. They intentionally create a developer account with passwordless sudo because current consumer images rely on that behavior. The scripts validate requested identity values and verify the resulting account state.

Shared helper executables under `/usr/local/bin` are installed deterministically and are not sourced as configuration.

## Input boundary

Comma-separated package and extension lists are parsed as argument arrays. Tokens containing shell-control syntax or beginning with package-manager option syntax are rejected before a privileged package command runs.

`NODE_CMD` in `node-entry.sh` is an intentional trusted shell-expression escape hatch and is not treated as untrusted data.

## Generated configuration

Privileged generated files are written through same-filesystem temporary files and renamed into place where practical. Repeated bootstrap execution must not duplicate managed include/profile lines.

## Temporary data

Bootstrap scripts use private temporary directories and clean only paths they own. Broad deletion of unrelated `/tmp` or `/var/tmp` content is not required for hardening.

## Secrets

Notification tokens and external credentials must not be emitted in diagnostics. Scriptomatic does not persist API secrets as part of the PHP/Node bootstrap contract.

## Deferred behavior-changing findings

When a safer design would necessarily change an established default (for example npm/Composer update policy, Node keepalive behavior, or direct-main distribution), the finding must be documented for an explicit decision rather than silently changed during this hardening program.
