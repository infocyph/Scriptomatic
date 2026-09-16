# Scriptomatic Hardening Progress Tracker

Branch: `plan/scriptomatic-hardening`

Baseline: `main` at `261397d3271cda5a6c186a64f8239bd3205fcf93`

Governing plan: `docs/plans/scriptomatic-hardening-plan.md`

This tracker is temporary. Delete it together with the governing plan before merge after all work and the final clean-branch CI gate are complete.

---

# Current Focus

**Phase 1 — Repository, CI, documentation, and security baseline**

Next task:

- create permanent test harness and CI;
- add static/ShellCheck policy;
- add initial README/contracts/security docs;
- codify `SCRIPTOMATIC_REF=main` and `TOOLSET_REF=2.0` dependency behavior.

---

# Global Decisions

- [x] Scriptomatic remains an independent shared script/bootstrap repository.
- [x] LocalDevStack is a downstream consumer, not the architecture owner.
- [x] Scriptomatic does not require a tag/release lifecycle.
- [x] `main` is the canonical default Scriptomatic source.
- [x] `SCRIPTOMATIC_REF` may override `main` for rollback/reproducibility.
- [x] All sibling Scriptomatic downloads must use the same selected `SCRIPTOMATIC_REF`.
- [x] Toolset must be consumed through its stable release contract; current expected ref is `2.0`.
- [x] Final implementation plan/tracker must be deleted before merge.

---

# Phase 1 — Repository / CI / Security Foundation

## Repository documentation

- [ ] Add root `README.md`.
- [ ] Add `docs/script-contracts.md`.
- [ ] Add `docs/security-review.md`.
- [ ] Document every script's class, shell, dependencies, privilege, network, mutation, and LocalDevStack relevance.
- [ ] Document Scriptomatic `main` + optional `SCRIPTOMATIC_REF` policy.
- [ ] Document Toolset stable `2.0` dependency policy.

## Test foundation

- [ ] Add `tests/lib/assert.sh`.
- [ ] Add `tests/static.sh`.
- [ ] Add initial smoke harness.
- [ ] Correctly classify Bash vs POSIX `sh` scripts.
- [ ] Add `bash -n` checks for Bash scripts.
- [ ] Add `sh -n` checks for POSIX entrypoints.
- [ ] Add ShellCheck policy with only local/documented suppressions.

## Security baseline

- [ ] Add `tests/security-audit.sh`.
- [ ] Audit `curl | bash` / `wget | sh`.
- [ ] Audit `eval` and untrusted `sh -c`.
- [ ] Audit writable config sourcing.
- [ ] Audit mutable Toolset branch downloads.
- [ ] Audit Scriptomatic `master` references.
- [ ] Audit unbounded network fetches.
- [ ] Audit `/usr/local/bin` ownership.
- [ ] Audit predictable `/tmp` state.
- [ ] Audit broad `/tmp/*` and `/var/tmp/*` deletion.
- [ ] Audit self-deleting setup scripts.

## CI

- [ ] Add `.github/workflows/ci.yml`.
- [ ] Add static/ShellCheck job.
- [ ] Add utility smoke job.
- [ ] Add PHP bootstrap integration job.
- [ ] Add Node bootstrap integration job.
- [ ] Add entrypoint integration job.
- [ ] Add server-helper integration job.
- [ ] Add security audit job.
- [ ] Add aggregate CI gate.

### Phase 1 gate

- [ ] Full Phase 1 CI green.

---

# Phase 2 — PHP Runtime Bootstrap

Targets: `bash/php-cli-setup.sh`, `bash/php-entry.sh`

## Input/capability validation

- [ ] Validate `USERNAME`.
- [ ] Validate `PHP_VERSION`.
- [ ] Validate numeric `UID`/`GID`.
- [ ] Parse `LINUX_PKG` safely.
- [ ] Parse `LINUX_PKG_VERSIONED` safely.
- [ ] Parse `PHP_EXT` safely.
- [ ] Parse `PHP_EXT_VERSIONED` safely.
- [ ] Validate/sanitize `MSMTP_FROM`.
- [ ] Explicitly require Alpine/PHP-image capabilities.

## Remote dependencies

- [ ] Replace floating `install-php-extensions` latest URL with explicit version/ref/checksum policy.
- [ ] Remove Oh My Bash `curl | bash`.
- [ ] Make Oh My Bash optional and immutable/verified when enabled.
- [ ] Replace Toolset `main` downloads with Toolset release `2.0` assets/checksums.
- [ ] Replace Scriptomatic `master` downloads with selected `SCRIPTOMATIC_REF`.
- [ ] Add bounded download/retry/temp-file behavior.

## Composer / config / identity

- [ ] Remove unconditional Composer self-update.
- [ ] Add explicit optional `COMPOSER_VERSION` behavior.
- [ ] Keep shared `/usr/local/bin` executables root-owned `0755`.
- [ ] Make passwordless sudo explicit through `SCRIPTOMATIC_PASSWORDLESS_SUDO`.
- [ ] Make generated config replacement atomic where practical.
- [ ] Validate PHP configuration after generation.
- [ ] Validate FPM configuration after generation.

## Cleanup / runtime entrypoint

- [ ] Remove broad `/tmp/*` cleanup.
- [ ] Remove broad `/var/tmp/*` cleanup.
- [ ] Remove setup-script self-deletion.
- [ ] Use private owned temp workspace/trap cleanup.
- [ ] Replace `/tmp/.rootca_installed` with content-aware CA identity.
- [ ] Preserve transparent `exec docker-php-entrypoint "$@"` semantics.

## Tests

- [ ] Add `tests/php-bootstrap.sh`.
- [ ] Add `tests/php-entry.sh`.
- [ ] Test resulting non-root user identity and home.
- [ ] Test shared helper ownership.
- [ ] Test Toolset exact 2.0 helper consumption.
- [ ] Test Scriptomatic selected-ref consistency.
- [ ] Test generated PHP/FPM validity.
- [ ] Test entrypoint argument/exit/signal behavior.
- [ ] Test repeated/idempotent paths.

### Phase 2 gate

- [ ] Disposable supported PHP Alpine bootstrap fully green.

---

# Phase 3 — Node Runtime Bootstrap

Targets: `bash/node-cli-setup.sh`, `bash/node-entry.sh`

## Setup inputs / identity

- [ ] Validate `USERNAME`.
- [ ] Validate `NODE_VERSION`.
- [ ] Validate numeric `UID`/`GID`.
- [ ] Parse Linux package lists safely.
- [ ] Parse Node global package lists safely.
- [ ] Validate `NODE_LOG_DIR`.
- [ ] Preserve upstream `node` UID reuse/rename behavior.
- [ ] Verify final UID/GID/home/shell/ownership after reuse or creation.
- [ ] Remove broad correctness-suppressing `|| true` around identity migration.

## Reproducibility / dependencies

- [ ] Remove `npm@latest` implicit upgrade.
- [ ] Remove `npm@next` fallback.
- [ ] Add optional exact `NPM_VERSION`.
- [ ] Add `SCRIPTOMATIC_REPRODUCIBLE` policy for global packages.
- [ ] Use Toolset release `2.0` for `gitx`/`chromacat`.
- [ ] Use selected `SCRIPTOMATIC_REF` for sibling helpers.
- [ ] Keep shared helpers root-owned.

## Entrypoint

- [ ] Default `NODE_LOG_ENABLED=0`.
- [ ] Default `NODE_KEEPALIVE_ON_FAIL=0`.
- [ ] Add explicit `NODE_AUTO_INSTALL`.
- [ ] Add explicit `NODE_ALLOW_LOCKFILE_FALLBACK`.
- [ ] Preserve strict lockfile install behavior by default.
- [ ] Remove generic dev double-execution/probing.
- [ ] Select one deterministic final process and `exec` it.
- [ ] Document `NODE_CMD` as a trusted shell-expression escape hatch.
- [ ] Replace `/tmp/.rootca_installed` with content-aware CA identity.

## Tests

- [ ] Add `tests/node-bootstrap.sh`.
- [ ] Add `tests/node-entry.sh`.
- [ ] Test existing UID 1000 reuse path.
- [ ] Test fresh-user path.
- [ ] Test npm prefix/cache ownership.
- [ ] Test exact Toolset helper consumption.
- [ ] Test selected Scriptomatic ref consistency.
- [ ] Test direct command forwarding.
- [ ] Test exit/signal semantics.
- [ ] Test dependency-install policy.
- [ ] Test no default keepalive on failed app.

### Phase 3 gate

- [ ] Disposable supported Node Alpine integration fully green.

---

# Phase 4 — Shared Utilities

Targets: `alias-maker.sh`, `banner.sh`, `docknotify.sh`, `owners.sh`

## alias-maker

- [ ] Prove repeated execution is idempotent.
- [ ] Preserve target ownership/mode during managed-block replacement.
- [ ] Use secure/atomic temp replacement where appropriate.
- [ ] Avoid sudo unless required.
- [ ] Keep Git path handling NUL-safe.
- [ ] Make optional-tool aliases degrade cleanly.
- [ ] Add `tests/alias-maker.sh`.

## banner

- [ ] Plain fallback without `figlet`.
- [ ] Plain fallback without/failing `chromacat`.
- [ ] Non-TTY behavior.
- [ ] `NO_COLOR`-compatible behavior where relevant.
- [ ] Unicode/empty description behavior.
- [ ] Ensure banner failure cannot break shell startup.
- [ ] Add `tests/banner.sh`.

## docknotify

- [ ] Preserve best-effort default.
- [ ] Fix trailing-newline protocol framing.
- [ ] Sanitize all protocol fields including token.
- [ ] Never expose notification token in diagnostics.
- [ ] Validate host/port/timeout/urgency/limits/strict flag.
- [ ] Test local TCP listener.
- [ ] Test absent listener non-strict success.
- [ ] Test absent listener strict failure.
- [ ] Add `tests/docknotify.sh`.

## owners

- [ ] Replace `for f in $(git ls-files)` with NUL-safe enumeration.
- [ ] Validate `git` dependency.
- [ ] Validate `git-fame` dependency.
- [ ] Define stable machine-readable output (prefer TSV).
- [ ] Test whitespace/special-character filenames.
- [ ] Add `tests/owners.sh`.

### Phase 4 gate

- [ ] Shared utility integration suite fully green.

---

# Phase 5 — Server / Service Helpers

Targets: `certbot-hook.sh`, `certbot-renew.sh`, `mongo-replica.sh`

## certbot-hook

- [ ] Replace status-only `docker ps -q -f name=` detection with exact identity/existence.
- [ ] Remove `docker exec -it` from non-interactive hook.
- [ ] Add configurable Nginx container name.
- [ ] Add configurable Apache container name.
- [ ] Missing optional container cleanly skips.
- [ ] Detected-container reload failure returns non-zero.

## certbot-renew

- [ ] Add strict shell/error policy.
- [ ] Add configurable renewal interval.
- [ ] Add optional jitter.
- [ ] Add signal-aware shutdown.
- [ ] Add repeated-failure diagnostics.
- [ ] Avoid silent infinite failure loop.

## Mongo replica

- [ ] Remove fixed `sleep 10`.
- [ ] Add bounded readiness polling.
- [ ] Prefer `mongosh`; decide/document legacy `mongo` fallback.
- [ ] Add configurable replica-set name.
- [ ] Add configurable member endpoints.
- [ ] Add configurable readiness timeout.
- [ ] Detect already initialized desired topology.
- [ ] Initiate only when uninitialized.
- [ ] Fail on conflicting existing topology unless reconciliation is explicit.
- [ ] Add `tests/mongo-replica.sh`.

## Tests

- [ ] Add `tests/certbot.sh`.
- [ ] Validate exact Docker container behavior with mocks/ephemeral containers.
- [ ] Validate renewal loop shutdown/error behavior.
- [ ] Validate Mongo readiness/idempotency with deterministic fixture.

### Phase 5 gate

- [ ] Server/service helper suite fully green.

---

# Phase 6 — Final Documentation / Downstream Contract / Cleanup

## Permanent docs

- [ ] Finalize README script inventory/examples.
- [ ] Finalize `docs/script-contracts.md`.
- [ ] Finalize `docs/security-review.md`.
- [ ] Every public script documents purpose/invocation/env/dependencies/privilege/mutations/network/exit/examples.

## LocalDevStack contract

- [ ] Document normal `SCRIPTOMATIC_REF=main` downstream default.
- [ ] Document commit-SHA override for reproducible downstream builds.
- [ ] Document `TOOLSET_REF=2.0` stable dependency.
- [ ] Confirm no LocalDevStack requirement leaked into Scriptomatic core behavior unnecessarily.

## Final audit

- [ ] No `curl | bash`/`wget | sh` remote execution remains.
- [ ] No hidden mutable Toolset dependency remains.
- [ ] No Scriptomatic `master` hard-code remains.
- [ ] No unresolved package-token injection boundary remains.
- [ ] No unintended ordinary-user ownership of shared executables remains.
- [ ] No broad `/tmp`/`/var/tmp` deletion remains.
- [ ] No setup self-deletion remains.
- [ ] No predictable stale CA stamp remains.
- [ ] No secret leakage issue remains.
- [ ] Entrypoints preserve intended exec/exit/signal contracts.

## Cleanup before merge

- [ ] Remove all one-shot migration/apply workflows/scripts.
- [ ] Delete `docs/plans/scriptomatic-hardening-plan.md`.
- [ ] Delete this tracker.
- [ ] Refresh PR description to reference permanent artifacts only.
- [ ] Run CI on the final clean branch.

### Phase 6 / final gate

- [ ] Final aggregate CI green on branch with no temporary plans/helpers.
- [ ] Branch is merge-ready.

---

# Work Log

## 2026-09-16

- Created `plan/scriptomatic-hardening` from current `main`.
- Added governing hardening plan.
- Added this progress tracker.
- Confirmed source policy: no Scriptomatic tag/release lifecycle; default `main`, optional `SCRIPTOMATIC_REF` override.
- Confirmed Toolset dependency policy: stable `2.0` release.
- Current focus set to Phase 1.
