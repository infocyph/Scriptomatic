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
- [x] Direct installation/download from `main` remains supported.
- [x] Existing externally observable behavior is preserved by default.
- [x] Hardening, validation, safety, diagnostics, tests and implementation improvements are allowed.
- [x] Behavior-changing findings require an explicit decision before implementation.
- [x] Existing environment-variable names and known invocation paths remain supported.
- [x] Scriptomatic remains separate from Toolset and does not duplicate Toolset CLIs.

---

# Phase 1 — Repository Foundation & Permanent CI

Status: **Pending**

## Documentation

- [ ] Add/normalize root `README.md`.
- [ ] Add `docs/script-contracts.md`.
- [ ] Add `docs/security-review.md`.
- [ ] Document purpose, shell, invocation, dependencies, privileges, network/filesystem behavior for every script.
- [ ] Document direct-`main` consumption as the canonical Scriptomatic distribution policy.
- [ ] Document optional consumer-side commit-SHA pinning without making it mandatory.

## Static validation

- [ ] Add `tests/lib/assert.sh`.
- [ ] Add `tests/static.sh`.
- [ ] Add `tests/smoke.sh`.
- [ ] Add `tests/security-audit.sh`.
- [ ] Classify Bash vs POSIX `sh` scripts.
- [ ] Add `bash -n` validation.
- [ ] Add `sh -n` validation where appropriate.
- [ ] Add ShellCheck policy.
- [ ] Add CRLF/conflict-marker/debug-leftover checks.
- [ ] Verify executable modes.

## GitHub Actions

- [ ] Add `.github/workflows/ci.yml`.
- [ ] Use current supported major versions of GitHub actions.
- [ ] Add static job.
- [ ] Add utility smoke job.
- [ ] Add PHP bootstrap integration job.
- [ ] Add Node bootstrap integration job.
- [ ] Add entrypoint integration job.
- [ ] Add server-helper integration job.
- [ ] Add security/hardening audit job.
- [ ] Add aggregate CI gate.

## Gate

- [ ] Phase 1 CI fully green.

---

# Phase 2 — PHP Bootstrap & PHP Entrypoint

Status: **Pending**

Targets:

```text
bash/php-cli-setup.sh
bash/php-entry.sh
```

## Regression baseline

- [ ] Add `tests/php-bootstrap.sh` before major implementation changes.
- [ ] Add `tests/php-entry.sh` before major implementation changes.
- [ ] Capture existing username/UID/GID behavior.
- [ ] Capture existing sudo behavior.
- [ ] Capture current Composer behavior.
- [ ] Capture current helper-download behavior.
- [ ] Capture current FPM/msmtp/profile behavior.
- [ ] Capture current setup cleanup/self-removal behavior.
- [ ] Capture current root-CA bootstrap behavior.

## Input and argv hardening

- [ ] Validate `USERNAME`.
- [ ] Validate `PHP_VERSION`.
- [ ] Validate `UID` / `GID`.
- [ ] Safely parse `LINUX_PKG`.
- [ ] Safely parse `LINUX_PKG_VERSIONED`.
- [ ] Safely parse `PHP_EXT`.
- [ ] Safely parse `PHP_EXT_VERSIONED`.
- [ ] Preserve all currently valid values and environment names.

## Environment/preflight

- [ ] Validate Alpine/PHP-image prerequisites early.
- [ ] Validate required user-management tools.
- [ ] Fail clearly for unsupported runtime images.

## Network/download hardening

- [ ] Bound curl connect time.
- [ ] Bound total download time.
- [ ] Add finite retry/backoff.
- [ ] Use private temporary paths.
- [ ] Reject empty/partial script downloads.
- [ ] Validate downloaded shell syntax where practical.
- [ ] Use atomic destination replacement.
- [ ] Preserve direct `main` consumption policy.
- [ ] Normalize Scriptomatic sibling URLs from stale `master` references to canonical `main`.
- [ ] Keep Toolset integration without duplicating Toolset source.

## User, permission and generated-state hardening

- [ ] Preserve current user creation behavior.
- [ ] Preserve current passwordless-sudo behavior expected by consumers.
- [ ] Harden pre-existing UID/GID/group conflict handling.
- [ ] Verify resulting home/shell/ownership.
- [ ] Validate sudoers content and mode.
- [ ] Make helper executable ownership/modes deterministic.
- [ ] Make PHP ini write failure-safe.
- [ ] Make FPM include mutation idempotent.
- [ ] Make msmtp config write failure-safe.
- [ ] Make profile hook writes idempotent.
- [ ] Validate resulting PHP config.
- [ ] Validate resulting FPM config.

## Composer / extension installer

- [ ] Preserve current functional behavior.
- [ ] Harden extension-installer acquisition.
- [ ] Harden Composer update failure handling.
- [ ] Prevent half-installed helper executables.
- [ ] Do not redesign version policy in this phase.

## Cleanup

- [ ] Audit broad `/tmp` and `/var/tmp` cleanup.
- [ ] Ensure runtime/mounted files cannot be removed accidentally.
- [ ] Test current self-removal behavior before deciding whether it can be hardened transparently.

## `php-entry.sh`

- [ ] Preserve root-CA bootstrap semantics.
- [ ] Preserve final `docker-php-entrypoint` forwarding.
- [ ] Harden root/sudo capability detection.
- [ ] Make CA update idempotent.
- [ ] Harden temporary state.
- [ ] Preserve final `exec` behavior.
- [ ] Preserve exit code/signal behavior.

## Gate

- [ ] PHP integration tests green on clean compatible upstream image.
- [ ] Existing PHP behavior regression tests green.

---

# Phase 3 — Node Bootstrap

Status: **Pending**

Target:

```text
bash/node-cli-setup.sh
```

## Regression baseline

- [ ] Add `tests/node-bootstrap.sh` before major implementation changes.
- [ ] Capture current upstream `node` UID reuse/rename behavior.
- [ ] Capture fresh-user behavior.
- [ ] Capture sudo behavior.
- [ ] Capture Corepack behavior.
- [ ] Capture npm update/fallback behavior.
- [ ] Capture optional global-package behavior.
- [ ] Capture shell/profile/helper behavior.

## Input hardening

- [ ] Validate `USERNAME`.
- [ ] Validate `NODE_VERSION`.
- [ ] Validate `UID` / `GID`.
- [ ] Safely parse `LINUX_PKG`.
- [ ] Safely parse `LINUX_PKG_VERSIONED`.
- [ ] Safely parse `NODE_GLOBAL`.
- [ ] Safely parse `NODE_GLOBAL_VERSIONED`.
- [ ] Validate `NODE_LOG_DIR` safely.

## UID/GID reuse

- [ ] Preserve existing UID-owner reuse/rename behavior.
- [ ] Verify resulting username.
- [ ] Verify resulting UID.
- [ ] Verify resulting primary GID.
- [ ] Verify resulting home.
- [ ] Verify resulting shell.
- [ ] Verify resulting ownership.
- [ ] Remove correctness-critical broad `|| true` where safe to do so without changing intended behavior.

## npm/Corepack

- [ ] Preserve Corepack best-effort behavior.
- [ ] Preserve npm update behavior and fallback semantics.
- [ ] Preserve optional global packages.
- [ ] Make package-list command construction injection-safe.
- [ ] Preserve npm cache/global-prefix behavior.
- [ ] Verify non-root global installation path.

## Helpers/profile

- [ ] Harden Toolset helper downloads.
- [ ] Normalize Scriptomatic sibling downloads to canonical `main`.
- [ ] Harden Scriptomatic helper downloads.
- [ ] Preserve all current helper paths/names.
- [ ] Make `.bashrc` additions idempotent.
- [ ] Preserve npm PATH/prefix lines.
- [ ] Preserve Git config line.
- [ ] Preserve banner snippet.

## Gate

- [ ] Node integration tests green for existing-user path.
- [ ] Node integration tests green for fresh-user path.
- [ ] Existing Node bootstrap behavior regression tests green.

---

# Phase 4 — Node Entrypoint

Status: **Pending**

Target:

```text
bash/node-entry.sh
```

## Regression contract

- [ ] Add `tests/node-entry.sh`.
- [ ] Capture `APP_DIR` default.
- [ ] Capture current file-log behavior/default.
- [ ] Capture direct command override.
- [ ] Capture `HOST` / `PORT` defaults.
- [ ] Capture dependency auto-install behavior.
- [ ] Capture pnpm/yarn/npm selection order.
- [ ] Capture current lockfile fallback behavior.
- [ ] Capture framework detection.
- [ ] Capture generic dev fallback semantics.
- [ ] Capture `NODE_CMD` shell-expression behavior.
- [ ] Capture `NODE_KEEPALIVE_ON_FAIL` default/current behavior.
- [ ] Capture root-CA bootstrap.

## Hardening

- [ ] Quote all path/argument handling safely.
- [ ] Harden log path creation.
- [ ] Harden npm cache permission handling.
- [ ] Avoid accidental duplicate process execution while preserving intended fallback semantics.
- [ ] Ensure selected long-running process becomes final `exec` path.
- [ ] Preserve command exit codes.
- [ ] Preserve signal delivery.
- [ ] Harden root-CA idempotency.
- [ ] Keep current dependency-install fallback contract.
- [ ] Keep current keepalive behavior/default.
- [ ] Keep `NODE_CMD` behavior intact and document trust requirement.

## Gate

- [ ] Node entrypoint regression suite green.
- [ ] Signal/exit forwarding fixture green.

---

# Phase 5 — Shared Developer Utilities

Status: **Pending**

## `alias-maker.sh`

- [ ] Add/complete `tests/alias-maker.sh`.
- [ ] Preserve every current alias unless a proven bug requires an explicit decision.
- [ ] Preserve managed function block behavior.
- [ ] Verify repeated execution is idempotent.
- [ ] Preserve `.bashrc` ownership/mode.
- [ ] Harden temporary-file replacement.
- [ ] Harden `dos2unix` failure cleanup.
- [ ] Verify Git file handling with spaces/shell-sensitive characters.
- [ ] Verify merged-branch helper behavior.

## `banner.sh`

- [ ] Add/complete `tests/banner.sh`.
- [ ] Preserve INFOCYPH figlet presentation when dependencies are present.
- [ ] Preserve random credit behavior.
- [ ] Preserve random ChromaCat box behavior.
- [ ] Preserve description rendering.
- [ ] Harden non-TTY behavior.
- [ ] Harden missing dependency behavior.
- [ ] Ensure presentation failure cannot unexpectedly break the primary runtime.

## `docknotify.sh`

- [ ] Add/complete `tests/docknotify.sh`.
- [ ] Preserve current CLI options/env names/defaults.
- [ ] Preserve default best-effort behavior.
- [ ] Preserve `DOCKNOTIFY_STRICT=1` behavior.
- [ ] Preserve timeout/urgency/title/body semantics.
- [ ] Verify exact wire framing with local TCP fixture.
- [ ] Sanitize protocol delimiters in all fields.
- [ ] Ensure token is never printed in diagnostics.
- [ ] Validate numeric bounds.
- [ ] Verify absent-listener exit behavior.

## `owners.sh`

- [ ] Add/complete `tests/owners.sh`.
- [ ] Preserve current purpose/output style.
- [ ] Replace whitespace-unsafe file iteration.
- [ ] Validate `git` dependency.
- [ ] Validate `git-fame` dependency.
- [ ] Test filenames containing spaces.
- [ ] Test shell-sensitive filenames.

## Gate

- [ ] Shared utility suite green.

---

# Phase 6 — Certbot & Mongo Helpers

Status: **Pending**

## `certbot-hook.sh`

- [ ] Add/complete `tests/certbot.sh`.
- [ ] Preserve default container names `NGINX` and `APACHE`.
- [ ] Preserve reload commands.
- [ ] Fix running-container detection without changing intended behavior.
- [ ] Remove inappropriate interactive TTY allocation from hook execution.
- [ ] Return meaningful status on detected-container reload failure.
- [ ] Cleanly skip absent containers.

## `certbot-renew.sh`

- [ ] Preserve 12-hour loop default.
- [ ] Preserve `certbot renew --quiet` behavior.
- [ ] Preserve `/usr/local/bin/reload-services` deploy hook.
- [ ] Add dependency checks.
- [ ] Harden signal/shutdown behavior.
- [ ] Improve failure diagnostics without changing renewal cadence.

## `mongo-replica.sh`

- [ ] Add/complete `tests/mongo-replica.sh`.
- [ ] Preserve replica-set name `rs0`.
- [ ] Preserve default member hostnames/ports.
- [ ] Replace sole fixed-sleep dependency with bounded readiness logic while preserving effective startup behavior.
- [ ] Support currently expected Mongo shell.
- [ ] Add `mongosh` compatibility where transparent.
- [ ] Detect already-initialized matching replica set.
- [ ] Fail clearly on conflicting topology.

## Gate

- [ ] Server-helper integration suite green.

---

# Phase 7 — Full Security & Reliability Audit

Status: **Pending**

- [ ] Audit `curl | bash` / `wget | sh` patterns.
- [ ] Audit unbounded network calls.
- [ ] Audit command-construction injection risk.
- [ ] Audit writable configuration sourcing.
- [ ] Audit predictable temporary paths.
- [ ] Audit broad `rm -rf` paths.
- [ ] Audit executable ownership/modes.
- [ ] Audit sudo/root transitions.
- [ ] Audit unsafe Git/path iteration.
- [ ] Audit interactive flags in automation hooks.
- [ ] Audit secret/token leakage.
- [ ] Ensure audit explicitly allows repository-policy `/main/` URLs.
- [ ] Record any finding whose safe fix would change observable behavior as an explicit deferred decision.

## Gate

- [ ] No unresolved high-impact issue that can be fixed without violating compatibility constraints.

---

# Phase 8 — Documentation & Downstream Compatibility

Status: **Pending**

- [ ] Root README accurately describes every public script.
- [ ] Script contracts match implementation and tests.
- [ ] Security review documents real boundaries/assumptions.
- [ ] Canonical Scriptomatic URLs use `main`, not stale `master`.
- [ ] Direct-main installation tested.
- [ ] Optional consumer commit-SHA pinning documented without becoming mandatory.
- [ ] LocalDevStack-relevant behavior cross-checked.
- [ ] No Toolset functionality duplicated.

---

# Phase 9 — Final Gate & Cleanup

Status: **Pending**

- [ ] Run complete static suite.
- [ ] Run complete PHP integration suite.
- [ ] Run complete Node integration suite.
- [ ] Run complete entrypoint suite.
- [ ] Run complete utility suite.
- [ ] Run complete Certbot/Mongo suite.
- [ ] Run complete security audit.
- [ ] Aggregate CI gate green on final clean head.
- [ ] Remove temporary one-shot migration/apply helpers/workflows.
- [ ] Keep permanent CI/tests/docs.
- [ ] Verify branch contains no accidental generated artifacts.
- [ ] Verify no release/tag workflow was introduced.
- [ ] Verify direct `main` consumption remains the intended post-merge model.
- [ ] Final code/documentation rescan completed.

---

# Deferred Decisions

Use this section only when a hardening finding cannot be fixed without changing established behavior.

| ID | Area | Finding | Compatibility impact | Decision |
|---|---|---|---|---|
| — | — | None yet | — | — |

---

# Completion Summary

Current overall status: **Planning initialized**

Completed:

- repository baseline identified;
- fresh work branch created from `main`;
- no-tag/no-release policy established;
- direct-`main` install policy established;
- behavior-preservation rule established;
- implementation plan added;
- progress tracker added.

Next execution point:

```text
Phase 1 — Repository Foundation & Permanent CI
```
