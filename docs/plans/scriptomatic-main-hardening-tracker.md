# Scriptomatic — Main-Branch Hardening Progress Tracker

Plan:

```text
docs/plans/scriptomatic-main-hardening-plan.md
```

Working branch:

```text
plan/scriptomatic-main-hardening
```

Baseline:

```text
main @ 261397d3271cda5a6c186a64f8239bd3205fcf93
```

## Governing Constraints

- [x] No Scriptomatic tag/release lifecycle is required.
- [x] Direct installation/download from `main` remains supported and canonical.
- [x] Existing externally observable behavior is preserved by default.
- [x] Hardening, validation, safety, diagnostics, tests and implementation improvements are allowed.
- [x] Behavior-changing findings require an explicit decision before implementation.
- [x] Existing environment-variable names and known invocation paths remain supported.
- [x] Scriptomatic remains separate from Toolset and does not duplicate Toolset CLIs.

## Batch Schedule

| Batch | Phases | Status |
|---|---|---|
| Batch 1 | 1–3 | **Complete** |
| Batch 2 | 4–6 | Pending |
| Batch 3 | 7–9 | Pending |

---

# Phase 1 — Repository Foundation & Permanent CI

Status: **Complete**

## Documentation

- [x] Add/normalize root `README.md`.
- [x] Add `docs/script-contracts.md`.
- [x] Add `docs/security-review.md`.
- [x] Document every script's purpose, shell, invocation, dependencies, privileges and side effects.
- [x] Document direct-`main` consumption as canonical policy.
- [x] Document optional consumer-side commit-SHA pinning without making it mandatory.

## Static validation

- [x] Add `tests/lib/assert.sh`.
- [x] Add `tests/static.sh`.
- [x] Add `tests/smoke.sh`.
- [x] Add `tests/security-audit.sh`.
- [x] Classify Bash vs POSIX `sh` scripts.
- [x] Add `bash -n` validation.
- [x] Add `sh -n` validation where appropriate.
- [x] Add ShellCheck policy: errors are gating; warning/info findings are handled in their owning phases when compatibility-safe.
- [x] Add CRLF/conflict-marker/debug-leftover checks.
- [x] Normalize and verify executable modes for all shipped scripts.

## GitHub Actions

- [x] Add `.github/workflows/ci.yml`.
- [x] Use `actions/checkout@v7`.
- [x] Add static job.
- [x] Add utility smoke job.
- [x] Add PHP bootstrap integration job.
- [x] Add Node bootstrap integration job.
- [x] Add entrypoint integration job.
- [x] Add server-helper baseline job.
- [x] Add security/hardening audit job.
- [x] Add aggregate CI gate.

## Gate

- [x] Phase 1 CI fully green.

Validated by CI run **205** on implementation head:

```text
560abc687da94f771fe27d8fbe1c05ec498092ac
```

---

# Phase 2 — PHP Bootstrap & PHP Entrypoint

Status: **Complete**

Targets:

```text
bash/php-cli-setup.sh
bash/php-entry.sh
```

## Regression and compatibility

- [x] Add `tests/php-bootstrap.sh`.
- [x] Add `tests/php-entry.sh`.
- [x] Preserve username/UID/GID inputs and behavior.
- [x] Preserve passwordless-sudo behavior used by existing consumers.
- [x] Preserve Composer self-update behavior.
- [x] Preserve helper names/paths and Toolset integration.
- [x] Preserve FPM, msmtp, profile and Composer-home behavior.
- [x] Preserve successful setup self-removal behavior.
- [x] Preserve best-effort root-CA bootstrap and final PHP entrypoint forwarding.

## Input and argv hardening

- [x] Validate `USERNAME`.
- [x] Validate `PHP_VERSION`.
- [x] Validate `UID` / `GID`.
- [x] Parse `LINUX_PKG` safely into argv.
- [x] Parse `LINUX_PKG_VERSIONED` safely into argv.
- [x] Parse `PHP_EXT` safely into argv.
- [x] Parse `PHP_EXT_VERSIONED` safely into argv.
- [x] Reject option/shell-control injection tokens.

## Environment and network hardening

- [x] Validate Alpine/PHP-image prerequisites early.
- [x] Use private bootstrap temporary directory.
- [x] Bound curl connect time and total time.
- [x] Add finite retry behavior.
- [x] Reject empty downloads.
- [x] Syntax-check downloaded shell helpers.
- [x] Stage helpers before atomic destination replacement.
- [x] Normalize Scriptomatic sibling URLs from stale `master` to canonical `main`.
- [x] Keep Toolset on its existing `main` integration policy.
- [x] Replace direct Oh My Bash `curl | bash` execution with download + syntax validation + execution.
- [x] Preserve PHP extension installer and Composer version policies rather than redesign them.

## State and permissions

- [x] Harden UID/GID/group conflicts.
- [x] Verify resulting UID/GID/home/shell.
- [x] Validate sudoers with `visudo`.
- [x] Keep shared `/usr/local/bin` helper executables deterministic `root:root` / `0755`.
- [x] Make privileged generated file replacement failure-safe where practical.
- [x] Make FPM include additions idempotent.
- [x] Validate PHP configuration.
- [x] Validate PHP-FPM configuration.
- [x] Remove broad unrelated `/tmp/*` and `/var/tmp/*` cleanup while preserving setup self-removal.

## `php-entry.sh`

- [x] Preserve final `exec docker-php-entrypoint "$@"` behavior.
- [x] Harden root/sudo capability detection.
- [x] Make root-CA stamp content-sensitive/idempotent.
- [x] Avoid writing successful state when CA installation fails.
- [x] Preserve best-effort/nonfatal CA semantics.
- [x] Preserve PHP entrypoint environment rather than introducing Node-specific variables.

## Gate

- [x] PHP integration test green on clean `php:8.4-fpm-alpine` fixture.
- [x] PHP entrypoint forwarding regression green.

---

# Phase 3 — Node Bootstrap

Status: **Complete**

Target:

```text
bash/node-cli-setup.sh
```

## Regression and compatibility

- [x] Add `tests/node-bootstrap.sh`.
- [x] Preserve upstream `node` UID reuse/rename behavior.
- [x] Cover fresh-user behavior separately.
- [x] Preserve passwordless sudo.
- [x] Preserve Corepack best-effort behavior.
- [x] Preserve npm `latest` → `next` → keep-current fallback semantics.
- [x] Preserve optional global-package behavior.
- [x] Preserve helper paths/names and banner/alias behavior.
- [x] Preserve setup self-removal.

## Input hardening

- [x] Validate `USERNAME`.
- [x] Validate `NODE_VERSION`.
- [x] Validate `UID` / `GID`.
- [x] Parse Linux package lists safely into argv.
- [x] Parse Node global package lists safely into argv.
- [x] Validate `NODE_LOG_DIR` as a safe absolute path.
- [x] Reject shell-control/option injection tokens.

## UID/GID reuse

- [x] Preserve existing UID-owner reuse/rename path.
- [x] Fix home migration so `usermod -m` is not pointed at a pre-created destination.
- [x] Verify final username/UID/GID/home/shell.
- [x] Exercise existing-user/UID-reuse path in disposable `node:24-alpine` fixture.
- [x] Exercise fresh-user creation path in the same fixture without repeating the full network bootstrap.

## npm/Corepack and profile

- [x] Keep Corepack behavior best-effort.
- [x] Keep npm update/fallback semantics.
- [x] Make optional global package invocation argv-safe.
- [x] Preserve user npm cache/global prefix.
- [x] Run optional global package install as the target user with explicit prefix/cache.
- [x] Keep `.bashrc` additions idempotent.
- [x] Preserve npm prefix/cache/PATH and Git-config profile lines.
- [x] Fix first-time Oh My Bash replacement so the intended npm/Git profile lines survive.

## Helpers

- [x] Bound and validate Toolset helper downloads while retaining Toolset `main` policy.
- [x] Normalize Scriptomatic sibling downloads to canonical `main`.
- [x] Stage and syntax-check downloaded helpers before install.
- [x] Keep shared helper executables root-owned and executable.

## Gate

- [x] Node integration green for upstream UID-reuse path.
- [x] Node integration green for fresh-user path.
- [x] Node bootstrap regression tests green.

Validated by CI run **205**.

---

# Phase 4 — Node Entrypoint

Status: **Pending**

Target: `bash/node-entry.sh`

- [ ] Expand `tests/node-entry.sh` beyond the Batch 1 forwarding baseline.
- [ ] Capture file-log defaults and behavior.
- [ ] Capture dependency auto-install and package-manager selection order.
- [ ] Capture lockfile fallback semantics.
- [ ] Capture framework detection/dev/start/server fallbacks.
- [ ] Preserve `NODE_CMD` trusted shell-expression behavior.
- [ ] Preserve `NODE_KEEPALIVE_ON_FAIL` current default and behavior.
- [ ] Harden path/log/cache handling.
- [ ] Remove accidental duplicate process execution while preserving intended fallback order.
- [ ] Preserve final `exec`, exit code and signal behavior.
- [ ] Harden root-CA idempotency without changing the entrypoint contract.

---

# Phase 5 — Shared Developer Utilities

Status: **Pending**

Targets:

```text
bash/alias-maker.sh
bash/banner.sh
bash/docknotify.sh
bash/owners.sh
```

- [ ] Add/complete dedicated fixtures for all four utilities.
- [ ] Preserve all current aliases and managed helper functions.
- [ ] Harden `.bashrc` idempotency/temp replacement/ownership.
- [ ] Preserve full banner presentation when dependencies exist.
- [ ] Harden banner behavior for missing dependencies/non-TTY use without making presentation runtime-critical.
- [ ] Preserve docknotify CLI/env/default best-effort semantics.
- [ ] Validate exact notification wire framing and protocol sanitization.
- [ ] Ensure notification token never leaks in diagnostics.
- [ ] Replace whitespace-unsafe Git file iteration in `owners.sh`.
- [ ] Test filenames containing spaces/shell-sensitive characters.

---

# Phase 6 — Certbot & Mongo Helpers

Status: **Pending**

Targets:

```text
bash/certbot-hook.sh
bash/certbot-renew.sh
bash/mongo-replica.sh
```

- [ ] Add/complete Certbot integration fixture.
- [ ] Preserve default `NGINX` / `APACHE` names and reload commands.
- [ ] Correct Docker running-container detection.
- [ ] Remove inappropriate TTY allocation from Certbot hook automation.
- [ ] Preserve 12-hour renewal cadence and deploy hook.
- [ ] Harden signal/failure diagnostics.
- [ ] Add/complete Mongo replica fixture.
- [ ] Preserve `rs0` and existing default member topology.
- [ ] Add bounded readiness handling while preserving startup intent.
- [ ] Add transparent `mongosh` compatibility where available.
- [ ] Make already-initialized matching topology idempotent and conflicting topology diagnostic.

---

# Phase 7 — Full Security & Reliability Audit

Status: **Pending**

- [ ] Rescan all remote execution/network calls.
- [ ] Rescan command-construction injection risk.
- [ ] Rescan writable config sourcing/temp paths/broad deletion.
- [ ] Rescan executable ownership and root/sudo transitions.
- [ ] Rescan Git/path iteration and automation TTY usage.
- [ ] Rescan secret/token leakage.
- [ ] Explicitly allow policy-approved Scriptomatic/Toolset `/main/` consumption.
- [ ] Record behavior-changing findings as deferred decisions rather than silently changing them.

---

# Phase 8 — Documentation & Downstream Compatibility

Status: **Pending**

- [ ] Reconcile README/contracts/security docs with final implementation.
- [ ] Ensure canonical Scriptomatic URLs use `main`, not stale `master`.
- [ ] Test direct-main installation contract.
- [ ] Keep optional SHA pinning documented, not mandatory.
- [ ] Cross-check LocalDevStack-relevant behavior.
- [ ] Confirm no Toolset CLI functionality has been duplicated.

---

# Phase 9 — Final Gate & Cleanup

Status: **Pending**

- [ ] Run complete static/PHP/Node/entrypoint/utility/server/security suite.
- [ ] Aggregate CI gate green on final clean head.
- [ ] Remove any temporary migration/apply helpers or workflows.
- [ ] Keep permanent CI/tests/docs.
- [ ] Verify no generated/accidental artifacts remain.
- [ ] Verify no release/tag workflow exists.
- [ ] Verify direct `main` consumption remains the intended post-merge model.
- [ ] Final code/documentation rescan.

---

# Deferred Decisions

| ID | Area | Finding | Compatibility impact | Decision |
|---|---|---|---|---|
| — | — | None currently requiring a behavior-changing decision | — | — |

---

# Batch 1 Validation Record

CI run:

```text
205
https://github.com/infocyph/Scriptomatic/actions/runs/35099304812
```

Validated implementation head:

```text
560abc687da94f771fe27d8fbe1c05ec498092ac
```

Result: **success**

Green jobs:

- Static and shell validation
- Utility smoke
- PHP bootstrap integration
- Node bootstrap integration
- Entrypoint integration
- Server helper baseline
- Security and hardening audit
- CI gate

Next execution point:

```text
Batch 2 — Phases 4–6
Phase 4 — Node Entrypoint
```
