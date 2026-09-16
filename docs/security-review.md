# Security Review

Scriptomatic contains privileged image-build scripts, non-root container entrypoints, Docker-control helpers, and service-bootstrap logic. Shell parsing, remote acquisition, ownership, privilege transition, Docker socket access, and secret handling are therefore security-sensitive boundaries.

## Final remote-code / dependency rules

Forbidden in the accepted state:

- `curl | bash` / `wget | sh` remote execution;
- mutable Toolset `main`/`master` executable downloads;
- Scriptomatic sibling downloads hard-coded to `master`;
- `releases/latest` for executable/bootstrap dependencies;
- executing downloaded content before required syntax/integrity validation;
- shell `eval` as an input-processing mechanism.

Scriptomatic normally follows `main`; a reproducible consumer should set `SCRIPTOMATIC_REF` to an immutable commit SHA. Toolset uses stable release `2.0` plus its checksum manifest.

The PHP extension installer default is pinned to `2.11.12` with SHA-256:

```text
7c133ae4b9490d912287188c62ea570729cfa74f0ea357e4be672ce696b4aa29
```

Oh My Bash is disabled by default. When explicitly enabled, Scriptomatic uses an immutable upstream commit rather than executing a mutable remote installer pipeline.

## Package and argument boundaries

Privileged PHP/Node bootstrap package/global-package lists are parsed as structured comma-separated tokens and validated before package-manager invocation. Tokens beginning with option syntax are rejected where unsafe.

`NODE_CMD` is intentionally retained only as a trusted compatibility escape hatch. It must not be populated from untrusted application/user data; direct container argv is the preferred path.

Mongo replica-set names/member endpoints are validated before being embedded in JavaScript passed to the Mongo shell.

## Filesystem / privilege rules

- shared executables under `/usr/local/bin` remain `root:root`, mode `0755`;
- setup scripts use private temporary workspaces and clean only their own temporary content;
- setup scripts do not self-delete;
- no broad `/tmp/*` or `/var/tmp/*` cleanup is accepted;
- generated privileged configuration uses explicit modes and atomic replacement where practical;
- passwordless sudo is opt-in and intended for trusted developer containers only.

For LocalDevStack, enabling passwordless sudo is a downstream trust decision. It is useful where a non-root PHP/Node entrypoint must refresh a mounted root CA, but it should not be silently enabled for unrelated containers.

## Runtime / container rules

Entrypoints preserve final `exec` semantics so application exit codes and signals remain container-visible.

Root-CA bootstrap compares content rather than using predictable stale `/tmp` stamp files.

Node defaults avoid hidden runtime mutation:

```text
NODE_LOG_ENABLED=0
NODE_KEEPALIVE_ON_FAIL=0
NODE_AUTO_INSTALL=0
NODE_ALLOW_LOCKFILE_FALLBACK=0
```

Presentation and notification helpers are non-critical to application lifecycle by default.

## Docker-control boundary

`certbot-hook.sh` is a Docker-control helper and therefore requires Docker CLI/socket access. Docker socket exposure should be limited to the appropriate LocalDevStack control/service container; Scriptomatic does not require application PHP/Node containers to receive Docker control privileges.

The Certbot hook uses exact container inspection and non-interactive `docker exec`; it does not use substring `docker ps` matching or request a TTY. Missing optional targets are skipped, while stopped or reload-failed configured targets are treated as errors.

`certbot-renew.sh` runs as a foreground container/supervisor process, reacts to termination signals, and exits after the default repeated-failure threshold rather than silently masking an indefinitely broken renewal path.

## Mongo bootstrap boundary

`mongo-replica.sh` does not rely on a fixed startup sleep. Readiness and post-init convergence have finite deadlines.

The script:

- prefers `mongosh`;
- validates replica-set name/member endpoints;
- initializes only an uninitialized replica set;
- treats already matching topology as success;
- refuses conflicting existing topology rather than rewriting it implicitly;
- separates connection URI from advertised Docker-DNS member endpoints.

Credentials may be present in `MONGO_URI`; the script does not echo that URI in normal diagnostics.

## Notification secret handling

`docknotify` accepts an optional `NOTIFY_TOKEN` as protocol data. Tabs/newlines are rejected and the token is never included in send-failure diagnostics. The notification transport remains best-effort unless strict mode is explicitly enabled.

## LocalDevStack boundary

LocalDevStack owns:

- image and Compose construction;
- mounted certificates/configuration;
- service/container names and Docker networks;
- Docker socket exposure;
- whether trusted-development sudo is enabled;
- whether Scriptomatic `main` or an immutable commit is selected.

Scriptomatic must not absorb LocalDevStack-specific static IPs or orchestration policy. See `docs/localdevstack-consumer-contract.md`.

## Permanent audit

`tests/security-audit.sh` is repository-wide in the final state. It rejects the high-impact patterns above, including mutable executable refs, pipe-to-shell execution, broad shared-temp deletion, setup self-deletion, stale CA stamps, ordinary-user ownership of shared binaries, non-interactive Docker TTY use, substring Certbot container detection, and the old fixed Mongo startup sleep.

Behavioral tests cover secret-safe notification failures, process exit/signal behavior, exact Certbot reload targeting, renewal failure thresholds/signals, and Mongo idempotency/conflict handling.
