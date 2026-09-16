# Security Review

Scriptomatic contains privileged image-build scripts, non-root container entrypoints, Docker-control helpers, and service-bootstrap logic. Shell parsing, remote acquisition, ownership, privilege transition, Docker socket access, and secret handling are therefore security-sensitive boundaries.

This review intentionally separates **security/integrity hardening** from **product/default policy**. Existing LocalDevStack developer-container behavior is preserved unless changing it is necessary to remove a concrete security, correctness, or reproducibility defect.

## Remote-code / dependency rules

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

Composer remains available by default, but is pinned to `2.10.3` instead of invoking a floating self-update.

Oh My Bash remains enabled by default for backward-compatible developer shells. Its acquisition is hardened by using an immutable upstream commit rather than executing a mutable remote installer pipeline.

The Node setup intentionally no longer performs an unconditional `npm@latest` / `npm@next` upgrade. That change is retained because a mutable package-manager upgrade makes otherwise-identical image builds non-reproducible. Consumers can request an exact `NPM_VERSION`.

## Package and argument boundaries

Privileged PHP/Node bootstrap package/global-package lists are parsed as structured comma-separated tokens and validated before package-manager invocation. Tokens beginning with option syntax are rejected where unsafe.

`NODE_CMD` remains a trusted compatibility escape hatch. It must not be populated from untrusted application/user data; direct container argv is preferred.

Mongo replica-set names/member endpoints are validated before being embedded in JavaScript passed to the Mongo shell.

## Filesystem / privilege rules

- shared executables under `/usr/local/bin` remain `root:root`, mode `0755`;
- setup scripts use private temporary workspaces and clean only their own temporary content;
- setup scripts do not self-delete;
- no broad `/tmp/*` or `/var/tmp/*` cleanup is accepted;
- generated privileged configuration uses explicit modes and atomic replacement where practical.

Passwordless sudo remains enabled by default because Scriptomatic historically builds trusted LocalDevStack developer containers and their runtime CA workflow relies on that capability. This is now explicit/configurable: set `SCRIPTOMATIC_PASSWORDLESS_SUDO=0` for stricter images. The security boundary is **documented trusted-container use**, not silently redefining the product default.

## Runtime / container rules

Direct application commands preserve final `exec` semantics so exit codes and signals remain container-visible.

Root-CA bootstrap compares content rather than using predictable stale `/tmp` stamp files. For Node, `NODE_EXTRA_CA_CERTS` still points at a readable mounted CA even if best-effort system trust-store installation cannot be completed.

Node compatibility defaults remain:

```text
NODE_LOG_ENABLED=1
NODE_KEEPALIVE_ON_FAIL=1
NODE_AUTO_INSTALL=1
NODE_ALLOW_LOCKFILE_FALLBACK=1
```

These are developer-container product choices, not security invariants. Each can be set to `0` for strict/production-like operation. Hardening focuses on bounded/validated behavior and on fixing the generic-dev double-execution bug rather than silently changing the default workflow.

Presentation and notification helpers remain non-critical to application lifecycle by default.

## Presentation boundary

Security/reliability hardening must not redesign established presentation. `banner.sh` therefore retains the original figlet layout, three-row description box, complete credit pool, and ChromaCat box-style pool. Hardened behavior is limited to safe non-TTY/`NO_COLOR`/dependency-failure fallbacks.

## Docker-control boundary

`certbot-hook.sh` is a Docker-control helper and therefore requires Docker CLI/socket access. Docker socket exposure should be limited to the appropriate LocalDevStack control/service container; Scriptomatic does not require application PHP/Node containers to receive Docker control privileges.

The Certbot hook uses exact container inspection and non-interactive `docker exec`; it does not use substring `docker ps` matching or request a TTY. Missing **or stopped** optional targets are skipped, preserving the original “reload if running” behavior. Actual Docker inspection errors and reload failures remain errors.

`certbot-renew.sh` runs as a foreground container/supervisor process and reacts to termination signals. The default remains unlimited retries (`CERTBOT_RENEW_MAX_FAILURES=0`) with diagnostics/backoff, matching the old service behavior. A positive threshold is an explicit operator choice.

## Mongo bootstrap boundary

`mongo-replica.sh` retains the original `rs0` and three-member defaults, but no longer relies on a fixed startup sleep. Readiness and post-init convergence have finite deadlines.

The script:

- prefers `mongosh` while retaining legacy `mongo` fallback;
- validates replica-set name/member endpoints;
- initializes only an uninitialized replica set;
- treats already matching topology as success;
- refuses conflicting existing topology rather than rewriting it implicitly;
- separates connection URI from advertised Docker-DNS member endpoints.

Credentials may be present in `MONGO_URI`; the script does not echo that URI in normal diagnostics.

## Notification secret handling

`docknotify` accepts an optional `NOTIFY_TOKEN` as protocol data. Tabs/newlines are rejected and the token is never included in send-failure diagnostics. The notification transport remains best-effort unless strict mode is explicitly enabled.

Optional timeout/urgency/length/strict values retain their historical permissive fallback behavior because treating malformed optional presentation/notification tuning as fatal was unnecessary policy expansion.

## LocalDevStack boundary

LocalDevStack owns:

- image and Compose construction;
- mounted certificates/configuration;
- service/container names and Docker networks;
- Docker socket exposure;
- choosing stricter opt-outs when desired;
- whether Scriptomatic `main` or an immutable commit is selected.

Scriptomatic must not absorb LocalDevStack-specific static IPs or orchestration policy. See `docs/localdevstack-consumer-contract.md`.

## Permanent audit

`tests/security-audit.sh` rejects high-impact implementation risks without redefining established UX/default policy. It covers mutable executable refs, pipe-to-shell execution, broad shared-temp deletion, setup self-deletion, stale CA stamps, ordinary-user ownership of shared binaries, non-interactive Docker TTY use, substring Certbot container detection, floating npm upgrades, and the old fixed Mongo startup sleep.

Compatibility assertions additionally lock the established developer defaults for sudo, Oh My Bash, Composer availability, and Node entrypoint ergonomics so later hardening does not repeat this overscope.
