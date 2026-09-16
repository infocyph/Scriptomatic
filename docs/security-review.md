# Security Review

Scriptomatic includes privileged build scripts and runtime entrypoints, so shell/download/ownership boundaries are treated as security-sensitive.

## Remote code and dependency rules

Forbidden in accepted final state:

- `curl | bash` / `wget | sh` remote execution;
- mutable Toolset `main`/`master` executable downloads;
- Scriptomatic sibling downloads hard-coded to `master`;
- unbounded network fetches for executable content;
- executing downloaded content before syntax/integrity validation.

Scriptomatic itself normally follows `main`; reproducible consumers may set `SCRIPTOMATIC_REF` to an immutable commit. Toolset uses its exact stable release and checksum file.

PHP extension installer default is pinned to `2.11.12` with published SHA-256 `7c133ae4b9490d912287188c62ea570729cfa74f0ea357e4be672ce696b4aa29`.

Oh My Bash is disabled by default. When enabled, Scriptomatic checks out an explicit immutable commit rather than executing a mutable installer pipeline.

## Filesystem / privilege rules

- shared executables under `/usr/local/bin` remain `root:root` and non-writable by ordinary users;
- setup scripts use private temporary workspaces and clean only owned temporary content;
- no setup script deletes itself;
- no broad `/tmp/*` or `/var/tmp/*` cleanup in accepted final state;
- passwordless sudo is opt-in and intended for trusted developer containers only;
- generated privileged configuration uses explicit modes and atomic replacement where practical.

## Runtime rules

Entrypoints must preserve final `exec` semantics and container signals/exit codes. Root-CA bootstrap is content-aware rather than keyed to predictable stale `/tmp` stamp files.

Presentation and notification helpers are non-critical to the primary application lifecycle.

## Ongoing audit

`tests/security-audit.sh` tracks known unresolved findings phase-by-phase and fails on unreviewed high-impact patterns. By the final phase the temporary allowlist is removed and the audit must be clean.
