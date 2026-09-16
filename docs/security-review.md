# Security Review

Scriptomatic contains privileged build/bootstrap scripts and runtime helpers. Hardening preserves the repository's existing external behavior while reducing avoidable implementation risk.

## Distribution trust

Scriptomatic intentionally supports direct installation from `main`. That is a project policy, not an integrity guarantee: consumers that require reproducible builds may pin a full commit SHA.

The PHP and Node setup scripts also consume Toolset from its `main` branch. This remains an accepted compatibility behavior unless the downstream ecosystem separately changes that policy.

Permanent CI enforces the Scriptomatic distribution contract: canonical self-references use `main`, and the repository must not acquire a release/publish workflow or tag-triggered release behavior.

## Accepted mutable upstream policies

The following mutable sources/version-selection behaviors are retained intentionally for compatibility and must not be mistaken for immutable supply-chain guarantees:

- Scriptomatic `main`;
- Toolset `main`;
- Oh My Bash's current upstream installer source;
- `mlocati/docker-php-extension-installer` `releases/latest`;
- Composer self-update;
- npm update/fallback behavior.

Changing those policies is a separate compatibility decision, not part of this hardening program.

## Remote execution

Remote shell content is not piped directly into a shell. Bootstrap downloads are fetched to private temporary files with bounded curl settings and finite retries, checked for non-empty content and shell syntax where applicable, then executed or installed through staged files.

## Privilege boundary

`php-cli-setup.sh` and `node-cli-setup.sh` are root build scripts. They intentionally create a developer account with passwordless sudo because current consumer images rely on that behavior. The scripts validate requested identity values and verify the resulting account state.

Shared helper executables under `/usr/local/bin` remain root-owned executable files. User-writable runtime state belongs in the developer home, cache or application paths instead.

Certbot automation uses non-interactive Docker execution and checks exact running-container state before reload attempts.

## Input boundary

Comma-separated package, extension and global-package lists are parsed as argument arrays. Tokens containing shell-control syntax or beginning with package-manager option syntax are rejected before privileged package commands run.

`NODE_CMD` in `node-entry.sh` is an intentional trusted shell-expression escape hatch and is not treated as untrusted data. Only trusted container/application configuration should populate it.

Mongo replica-set and member-host overrides are validated before interpolation into Mongo shell JavaScript. Replica inspection proceeds to initialization only for the actual not-yet-initialized condition; unrelated inspection/authentication failures are not treated as an initialization signal.

Notification protocol fields are normalized to a single record before transmission, and the notification token is not included in diagnostics.

## Generated configuration

Privileged generated files are written through same-filesystem temporary files and renamed into place where practical. Repeated bootstrap execution must not duplicate managed include/profile lines.

## Temporary data

Bootstrap scripts use private temporary directories and clean only paths they own. Broad deletion of unrelated `/tmp` or `/var/tmp` content is not part of Scriptomatic hardening.

The PHP root-CA stamp is content-sensitive and written with a restrictive umask. Node CA installation compares source/destination content instead of relying on a global success stamp.

## Git and path safety

Git ownership and EOL helpers use NUL-safe file traversal where tracked filenames are involved. CI rejects the previous whitespace-unsafe `for ... in $(git ls-files ...)` pattern.

## Secrets

Notification tokens and external credentials must not be emitted in diagnostics. Scriptomatic does not persist API secrets as part of the PHP/Node bootstrap contract.

## Downstream compatibility

Scriptomatic's canonical branch is `main`. Downstream consumers still using the historical `master` raw URL should migrate that branch component to `main` after the hardening PR is merged; the setup arguments, environment inputs and installed entrypoint/helper paths remain compatible. See [`downstream-compatibility.md`](downstream-compatibility.md).

## Deferred behavior-changing findings

Safer designs that necessarily change an established default—such as replacing direct-main distribution, changing npm/Composer update policy, removing development-container passwordless sudo, or changing Node keepalive behavior—require an explicit separate decision and are not silently introduced by this hardening program.
