# Scriptomatic Hardening Progress Tracker

Branch: `plan/scriptomatic-hardening`

Baseline: `main` at `261397d3271cda5a6c186a64f8239bd3205fcf93`

Governing plan: `docs/plans/scriptomatic-hardening-plan.md`

This tracker is temporary. Delete it together with the governing plan only after Phase 7 and the final clean-branch CI gate are complete.

---

# Current Focus

**Batch 3 — Phase 5 + Phase 6 + Phase 7**

1. Phase 5 — harden Certbot and Mongo service helpers for non-interactive container use.
2. Phase 6 — finish permanent docs, downstream contracts, and repository-wide security audit.
3. Phase 7 — validate Scriptomatic as a Docker/LocalDevStack consumer dependency, then remove temporary planning/apply machinery and run the final clean gate.

Batch rule: progress three phases per implementation batch and update this tracker at batch start and close.

---

# Global Decisions

- [x] Scriptomatic remains an independent shared script/bootstrap repository.
- [x] Its primary runtime context is inside Docker containers, especially LocalDevStack PHP/Node/service images.
- [x] LocalDevStack is a downstream consumer, not the architecture owner.
- [x] Container behavior takes precedence over host-machine convenience when contracts differ.
- [x] Scriptomatic does not require a tag/release lifecycle.
- [x] `main` is the canonical default Scriptomatic source.
- [x] `SCRIPTOMATIC_REF` may override `main`; LocalDevStack reproducible builds should use a commit SHA.
- [x] All sibling Scriptomatic downloads use the same selected `SCRIPTOMATIC_REF`.
- [x] Toolset is consumed through stable release `2.0`.
- [x] PHP/Node scripts remain compatible with Alpine container images and non-root runtime users.
- [x] Final implementation plan/tracker must be deleted before merge.

---

# Phase 1 — Repository / CI / Security Foundation

- [x] Root README and permanent contract/security docs established.
- [x] Permanent assertion/static/smoke harness established.
- [x] Bash vs POSIX parser classification enforced.
- [x] ShellCheck policy established.
- [x] Security audit established.
- [x] Permanent CI jobs established for static, utilities, PHP, Node, entrypoints, service helpers, security, and aggregate gate.
- [x] `SCRIPTOMATIC_REF=main` + optional override documented.
- [x] `TOOLSET_REF=2.0` policy documented.
- [x] Phase 1 gate green.

# Phase 2 — PHP Runtime Bootstrap

Targets: `bash/php-cli-setup.sh`, `bash/php-entry.sh`

- [x] Privileged input/package/extension validation.
- [x] Explicit Alpine/PHP-image capability contract.
- [x] Pinned + verified PHP extension installer.
- [x] No floating Composer self-update; exact optional Composer version.
- [x] Toolset `2.0` helper acquisition with release checksums.
- [x] Same-ref Scriptomatic helper acquisition.
- [x] Shared executables remain root-owned `0755`.
- [x] Passwordless sudo is explicit opt-in.
- [x] Generated PHP/FPM config validation and idempotent FPM include.
- [x] Private temp workspace; no broad temp deletion/self-delete.
- [x] Optional immutable Oh My Bash path.
- [x] Content-aware root-CA refresh and transparent PHP entrypoint exec.
- [x] Disposable PHP Alpine bootstrap/re-run gate green.

# Phase 3 — Node Runtime Bootstrap

Targets: `bash/node-cli-setup.sh`, `bash/node-entry.sh`

- [x] Input/package/global-package validation.
- [x] Upstream UID/GID reuse retained and result verified.
- [x] No implicit `npm@latest` / `npm@next`; exact optional npm version.
- [x] Reproducible global-package mode.
- [x] Toolset `2.0` and same-ref Scriptomatic helpers.
- [x] Shared helpers root-owned.
- [x] Logging, keepalive, and runtime install default off.
- [x] Lockfile fallback explicit opt-in.
- [x] Deterministic single final process; direct args preferred over trusted `NODE_CMD` escape hatch.
- [x] Content-aware root-CA refresh.
- [x] Existing-UID and fresh-user disposable Node Alpine integration green.

# Phase 4 — Shared Utilities

Targets: `alias-maker.sh`, `banner.sh`, `docknotify.sh`, `owners.sh`

- [x] Alias managed block is repeatable/idempotent and atomic.
- [x] Optional aliases degrade safely.
- [x] Banner has plain/non-TTY/NO_COLOR fallbacks and cannot make shell startup fail.
- [x] Dock notification protocol has exact newline framing, validated fields, token-safe diagnostics, strict/non-strict behavior.
- [x] Owners uses NUL-safe Git enumeration and stable TSV output.
- [x] Permanent utility tests added.
- [x] Shared utility integration gate green.

---

# Phase 5 — Server / Service Helpers

Targets: `certbot-hook.sh`, `certbot-renew.sh`, `mongo-replica.sh`

## Certbot hook

- [ ] Use exact container existence/running checks, not substring/status filters.
- [ ] Remove interactive TTY flags.
- [ ] Make Nginx/Apache container names configurable.
- [ ] Missing optional container cleanly skips.
- [ ] Existing-but-stopped/reload-failed target returns non-zero with useful diagnostics.
- [ ] Keep behavior suitable for execution inside a service/container control plane.

## Certbot renew loop

- [ ] Strict shell/error policy.
- [ ] Configurable interval and optional bounded jitter.
- [ ] Signal-aware shutdown.
- [ ] Failure counter + diagnostics/backoff behavior.
- [ ] No silent infinite failure loop.
- [ ] Container foreground-process semantics documented/tested.

## Mongo replica bootstrap

- [ ] Bounded readiness polling; no fixed `sleep 10`.
- [ ] Prefer `mongosh`; documented legacy `mongo` fallback only if available.
- [ ] Configurable replica-set name/member endpoints/readiness timeout.
- [ ] Detect initialized desired topology.
- [ ] Initiate only when uninitialized.
- [ ] Conflicting topology fails unless explicit reconciliation exists.
- [ ] Container/Docker-DNS endpoint assumptions are explicit.

## Tests / gate

- [ ] Permanent `tests/certbot.sh` and `tests/mongo-replica.sh` cover deterministic fixtures.
- [ ] Server/service helper integration gate green.

---

# Phase 6 — Permanent Documentation / Security / Downstream Contract

- [ ] Finalize README script inventory and container-focused examples.
- [ ] Finalize `docs/script-contracts.md` for purpose/invocation/env/dependencies/privilege/mutations/network/exit semantics.
- [ ] Finalize `docs/security-review.md` with accepted trust boundaries.
- [ ] Document LocalDevStack normal `SCRIPTOMATIC_REF=main` behavior and commit-SHA reproducible pinning.
- [ ] Document `TOOLSET_REF=2.0` stable dependency.
- [ ] Document container-first assumptions: Alpine PHP/Node bootstrap, non-root runtime, Docker stdout/stderr, service-name/Docker-DNS endpoints, no TTY requirement for automation.
- [ ] Expand security audit repository-wide: no remote pipe-to-shell, hidden mutable Toolset refs, `master` refs, broad temp deletion, setup self-delete, stale CA stamps, secret leakage, or unintended shared-binary ownership.
- [ ] Validate entrypoint exit/signal contracts after final source changes.
- [ ] Phase 6 documentation/security gate green.

---

# Phase 7 — LocalDevStack / Docker Consumer Validation + Final Cleanup

This phase exists because Scriptomatic is predominantly consumed inside Docker containers, especially LocalDevStack. It validates the dependency boundary without moving LocalDevStack orchestration logic into Scriptomatic.

- [ ] Inspect current LocalDevStack Docker/PHP/Node/service consumers against the hardened Scriptomatic contracts.
- [ ] Verify PHP and Node image/bootstrap call shapes remain compatible.
- [ ] Verify `bash`, `sh`, and login-shell behavior where LocalDevStack relies on them.
- [ ] Verify root-CA mounted-file behavior under non-root runtime users.
- [ ] Verify `docknotify` defaults match the LocalDevStack notification service contract.
- [ ] Verify service helpers use Docker DNS/container names rather than static IP assumptions.
- [ ] Identify required downstream pin/config changes separately; do not hard-code LocalDevStack internals into reusable scripts.
- [ ] Remove all one-shot apply/migration workflows/scripts.
- [ ] Delete `docs/plans/scriptomatic-hardening-plan.md` and this tracker only after all Phase 7 checks are complete.
- [ ] Refresh draft PR #57 to reference permanent artifacts only.
- [ ] Run final aggregate CI on the clean branch.
- [ ] Branch/PR merge-ready, but do not merge automatically.

---

# Work Log

## 2026-09-16

- Created `plan/scriptomatic-hardening` from current `main`.
- Established source policy: Scriptomatic `main` by default, optional ref/SHA override; Toolset stable `2.0`.
- Completed Phases 1–2; clean aggregate CI green.
- Completed Phases 3–4; Node Alpine + shared-utility + security aggregate CI green (run `35088528923`).
- User clarified Scriptomatic scripts are primarily consumed inside Docker/LocalDevStack containers.
- Changed batching rule to three phases per batch.
- Started Batch 3: Phases 5–7, with Phase 7 dedicated to Docker/LocalDevStack consumer validation and final cleanup.
