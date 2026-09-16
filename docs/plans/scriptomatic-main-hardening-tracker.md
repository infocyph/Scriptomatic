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

Draft PR:

```text
#58 — Scriptomatic main-branch hardening
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
| Batch 2 | 4–6 | **Complete** |
| Batch 3 | 7–9 | **Complete** |

---

# Phase 1 — Repository Foundation & Permanent CI

Status: **Complete**

- [x] Root README, script contracts and security review added.
- [x] Canonical direct-`main` distribution policy documented.
- [x] Permanent assertion, static, smoke and security test framework added.
- [x] Bash/POSIX syntax validation, executable-mode validation and ShellCheck error gate added.
- [x] Permanent GitHub Actions jobs added using `actions/checkout@v7`.
- [x] PHP, Node, entrypoint, utility/server baseline, security and aggregate CI gate established.

---

# Phase 2 — PHP Bootstrap & PHP Entrypoint

Status: **Complete**

Targets:

```text
bash/php-cli-setup.sh
bash/php-entry.sh
```

- [x] PHP bootstrap and entrypoint regression fixtures added.
- [x] Username/version/UID/GID and package/extension inputs validated.
- [x] Package and extension lists converted to argv-safe handling.
- [x] Alpine/PHP prerequisites validated early.
- [x] Curl operations bounded with finite retries and private staging.
- [x] Downloaded helpers syntax-checked and installed atomically.
- [x] Scriptomatic helper URLs normalized from stale `master` to canonical `main`.
- [x] UID/GID/group conflicts and final identity verified.
- [x] Sudoers validated; shared helpers kept deterministic root-owned executables.
- [x] PHP/FPM/msmtp/profile writes hardened and made idempotent where applicable.
- [x] Broad unrelated temporary-directory cleanup removed while successful setup self-removal remains.
- [x] PHP root-CA bootstrap made content-aware/idempotent while remaining best-effort.
- [x] Final `docker-php-entrypoint` exec/exit/signal behavior preserved.

---

# Phase 3 — Node Bootstrap

Status: **Complete**

Target:

```text
bash/node-cli-setup.sh
```

- [x] Node bootstrap regression and disposable-image integration fixture added.
- [x] Username/version/UID/GID, package/global-package and log-path inputs validated.
- [x] Package/global-package command construction made argv-safe.
- [x] Upstream `node` UID-owner reuse/rename behavior preserved and verified.
- [x] Fresh-user path covered separately.
- [x] Home migration fixed so `usermod -m` is not pointed at a pre-created destination.
- [x] Corepack remains best-effort and npm `latest` → `next` → current fallback remains.
- [x] Toolset/Scriptomatic helper downloads bounded, validated and staged before install.
- [x] Scriptomatic helper URLs use canonical `main`.
- [x] First-time Oh My Bash replacement no longer discards intended npm/Git profile lines.
- [x] Existing sudo, helper names, profile behavior and successful setup self-removal preserved.

---

# Phase 4 — Node Entrypoint

Status: **Complete**

- [x] Direct command argv forwarding, exit codes and signal behavior covered.
- [x] File-log behavior/defaults covered.
- [x] Existing dependency-install/package-manager/lockfile fallback semantics preserved.
- [x] Framework-specific final `exec` behavior preserved.
- [x] Generic `dev` fallback no longer launches a successful command twice.
- [x] Generic trial child receives shutdown signals.
- [x] `NODE_CMD` remains the documented trusted shell-expression override.
- [x] `NODE_KEEPALIVE_ON_FAIL=1` remains the default.
- [x] npm flags made argv-safe and root-CA handling made content-aware.

---

# Phase 5 — Shared Developer Utilities

Status: **Complete**

- [x] Dedicated fixtures cover alias-maker, banner, docknotify and owners.
- [x] `.bashrc` managed-block replacement is idempotent, same-directory/atomic and mode-aware.
- [x] Banner retains full presentation when dependencies are usable and degrades safely otherwise.
- [x] Docknotify preserves best-effort defaults and strict mode while sending a real newline-terminated frame.
- [x] Docknotify sanitizes all protocol fields, including the token, without leaking token diagnostics.
- [x] `owners.sh` uses NUL-safe tracked-file iteration and validates dependencies.
- [x] Spaces and shell-sensitive filenames are regression-tested.

---

# Phase 6 — Certbot & Mongo Helpers

Status: **Complete**

- [x] Dedicated Certbot and Mongo fixtures added and wired into permanent CI.
- [x] Default `NGINX` / `APACHE` names and reload commands preserved.
- [x] Exact running-container detection replaces redirected `docker ps` assumptions.
- [x] Certbot hook no longer allocates an interactive TTY.
- [x] Default 12-hour renewal cadence and deploy hook remain unchanged.
- [x] Renewal loop gains dependency preflight, diagnostics and stop-signal handling.
- [x] Mongo defaults remain `rs0` with the existing three members.
- [x] Fixed startup sleep replaced by bounded readiness probing.
- [x] `mongosh` preferred with legacy `mongo` fallback.
- [x] Matching topology is idempotent and conflicting topology fails clearly.

---

# Phase 7 — Full Security & Reliability Audit

Status: **Complete**

- [x] Rescanned all shipped scripts for remote execution/network calls.
- [x] Rescanned command-construction injection risk.
- [x] Rescanned temporary paths, broad deletion and writable configuration execution.
- [x] Rescanned shared executable ownership and root/sudo transitions.
- [x] Rescanned Git/path iteration and Docker automation TTY use.
- [x] Rescanned secret/token leakage.
- [x] Expanded `tests/security-audit.sh` with permanent regression checks.
- [x] Explicitly preserved policy-approved Scriptomatic `main` and Toolset `main` consumption.
- [x] Added Mongo replica-set/member override validation before JavaScript interpolation.
- [x] Mongo now treats only actual `NotYetInitialized` state as initialization permission; unrelated inspection/auth failures fail safely.
- [x] Added regression coverage for invalid Mongo overrides and non-initialization errors.
- [x] Existing mutable upstream policies documented rather than silently redesigned.

---

# Phase 8 — Documentation & Downstream Compatibility

Status: **Complete**

- [x] README reconciled with the final implementation and complete test surface.
- [x] `docs/script-contracts.md` reconciled through Phases 4–7.
- [x] `docs/security-review.md` reconciled with accepted mutable sources and final trust boundaries.
- [x] Added `docs/downstream-compatibility.md`.
- [x] Added permanent `tests/main-contract.sh` for canonical `main` distribution.
- [x] CI now rejects stale canonical `master` self-references, release/publish workflows and tag-triggered release behavior.
- [x] Optional full-SHA pinning remains documented but is not mandatory.
- [x] LocalDevStack compatibility was cross-checked without modifying the downstream repository.
- [x] LocalDevStack follow-up recorded: change its Scriptomatic PHP/Node raw branch component from `master` to `main` after this PR merges.
- [x] PHP/Node setup invocation, environment inputs, entrypoint paths and helper names remain compatible.
- [x] Confirmed Scriptomatic consumes rather than duplicates Toolset CLI functionality.

---

# Phase 9 — Final Gate & Cleanup

Status: **Complete**

- [x] Complete static/PHP/Node/entrypoint/utility/server/security suite green on Batch 3 implementation head.
- [x] Push CI aggregate gate green on Batch 3 implementation head.
- [x] PR-triggered CI aggregate gate green on Batch 3 implementation head.
- [x] No temporary migration/apply helper or workflow exists.
- [x] Permanent CI/tests/docs retained.
- [x] Branch delta reviewed for accidental/generated artifacts.
- [x] `.github/workflows` contains only permanent `ci.yml`.
- [x] No release/publish workflow exists.
- [x] No tag-triggered distribution workflow exists.
- [x] Direct `main` consumption remains the intended post-merge model.
- [x] Plan remains consistent with the no-tag/no-release requirement.
- [x] Final code/documentation rescan completed.

---

# Deferred Decisions

No behavior-changing decision is required to complete this hardening program.

The following established mutable-development policies remain intentionally unchanged and documented:

- Scriptomatic `main` distribution;
- Toolset `main` consumption;
- current Oh My Bash upstream policy;
- PHP extension installer `releases/latest` policy;
- Composer self-update behavior;
- npm update/fallback behavior;
- passwordless sudo in the existing development-container contract;
- Node keepalive default.

---

# Downstream Follow-up

LocalDevStack's current default branch still references historical Scriptomatic `master` raw URLs in its PHP and Node Dockerfiles. After PR #58 merges, update those two branch components to `main`. No Scriptomatic tag/release migration is required.

This downstream repository was intentionally not modified from the Scriptomatic hardening branch.

---

# Validation Records

## Batch 1

CI run: **205**  
Implementation head: `560abc687da94f771fe27d8fbe1c05ec498092ac`  
Result: **success**

## Batch 2

Push CI run: **220**  
Implementation head: `d8fc9879be29220a7c8cb793b3a40c2e56283b8f`  
Result: **success**

PR #58 CI run: **222**  
Tracker head: `664941eeca5a3a818f5eae86cc80ae95940898cd`  
Result: **success**

## Batch 3

Implementation head:

```text
c137b5e87d57a4a985745b6720abfba7340356b9
```

Push CI run: **239** — **success**  
PR #58 CI run: **240** — **success**

Both runs include the expanded security audit, main-distribution contract and aggregate CI gate.

This tracker completion commit is documentation-only; its resulting push/PR checks are the final clean-head validation before merge readiness.
