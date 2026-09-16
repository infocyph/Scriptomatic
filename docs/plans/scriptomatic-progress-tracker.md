# Scriptomatic Hardening Progress Tracker

Branch: `plan/scriptomatic-hardening`

Baseline: `main` at `261397d3271cda5a6c186a64f8239bd3205fcf93`

Governing plan: `docs/plans/scriptomatic-hardening-plan.md`

This tracker is temporary. Batch 3 implementation is complete; this closeout snapshot is intentionally committed before the tracker and governing plan are deleted for the final clean branch gate.

---

# Current Focus

**Batch 3 — Phase 5 + Phase 6 + Phase 7: COMPLETE**

Validation head before temporary-plan cleanup: `01688ebf87da6999756d3ed9a3cdad24ecbf036e`

Green aggregate CI: run `35089916708`.

Batch rule: implementation advances three phases per batch and the tracker is updated at batch start and close.

---

# Global Decisions

- [x] Scriptomatic remains an independent shared script/bootstrap repository.
- [x] Its primary runtime context is inside Docker containers, especially LocalDevStack PHP/Node/service images.
- [x] LocalDevStack is a downstream consumer, not the architecture owner.
- [x] Container behavior takes precedence over host-machine convenience when contracts differ.
- [x] Scriptomatic does not require a tag/release lifecycle.
- [x] `main` is the canonical default Scriptomatic source.
- [x] `SCRIPTOMATIC_REF` may override `main`; reproducible LocalDevStack builds should use a commit SHA.
- [x] All sibling Scriptomatic downloads use the same selected `SCRIPTOMATIC_REF`.
- [x] Toolset is consumed through stable release `2.0`.
- [x] PHP/Node scripts remain compatible with Alpine container images and non-root runtime users.
- [x] Temporary implementation plan/tracker are removed only after recording this completed closeout state.

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

- [x] Privileged input/package/extension validation.
- [x] Alpine/PHP-image capability contract.
- [x] Pinned + verified PHP extension installer.
- [x] No floating Composer self-update; exact optional Composer version.
- [x] Toolset `2.0` helper acquisition with release checksums.
- [x] Same-ref Scriptomatic helper acquisition.
- [x] Shared executables remain root-owned `0755`.
- [x] Passwordless sudo is explicit opt-in.
- [x] Generated PHP/FPM validation and repeatable FPM include.
- [x] Private temp workspace; no broad temp deletion/self-delete.
- [x] Optional immutable Oh My Bash path.
- [x] Content-aware root-CA refresh and transparent PHP entrypoint exec.
- [x] Disposable PHP Alpine bootstrap/re-run gate green.

# Phase 3 — Node Runtime Bootstrap

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

- [x] Alias managed block repeatable/idempotent and atomic.
- [x] Optional aliases degrade safely.
- [x] Banner plain/non-TTY/NO_COLOR fallback and non-critical startup behavior.
- [x] Dock notification framing, validation, token-safe diagnostics, strict/non-strict behavior.
- [x] Owners NUL-safe Git enumeration and stable TSV output.
- [x] Permanent utility tests.
- [x] Shared utility integration gate green.

---

# Phase 5 — Server / Service Helpers

## Certbot hook

- [x] Exact `docker container inspect` existence/running checks replace substring/status filters.
- [x] Interactive TTY flags removed.
- [x] Nginx/Apache container names configurable.
- [x] Missing optional container cleanly skips.
- [x] Existing-but-stopped/reload-failed target returns non-zero with diagnostics.
- [x] Reload execution bounded by timeout and suitable for a service/control container.

## Certbot renewal loop

- [x] Strict shell/error policy.
- [x] Configurable interval and bounded optional jitter.
- [x] Signal-aware foreground shutdown.
- [x] Failure counter, backoff, and diagnostics.
- [x] Default repeated-failure threshold prevents silent infinite failure loops.
- [x] One-cycle deterministic mode and container foreground semantics tested/documented.

## Mongo replica bootstrap

- [x] Bounded readiness polling; fixed startup sleep removed.
- [x] `mongosh` preferred; legacy `mongo` fallback retained deliberately.
- [x] Configurable replica-set name, member endpoints, connection URI, and timeouts.
- [x] Existing desired topology detected and accepted without mutation.
- [x] Initialization occurs only for an uninitialized replica set.
- [x] Conflicting topology fails rather than reconciling implicitly.
- [x] Docker-DNS member endpoint assumptions explicit and separate from the connection URI.
- [x] Topology return codes preserved correctly under strict Bash control flow.

## Tests / gate

- [x] Permanent `tests/certbot.sh` and `tests/mongo-replica.sh` deterministic fixtures.
- [x] Server/service helper integration green.
- [x] Phase 5 aggregate gate green in run `35089916708`.

---

# Phase 6 — Permanent Documentation / Security / Downstream Contract

- [x] README finalized with container-focused inventory/examples.
- [x] `docs/script-contracts.md` finalized for behavior/env/privilege/mutation/network/exit contracts.
- [x] `docs/security-review.md` finalized with accepted trust boundaries.
- [x] `docs/localdevstack-consumer-contract.md` added.
- [x] LocalDevStack normal `SCRIPTOMATIC_REF=main` behavior and commit-SHA reproducible pinning documented.
- [x] `TOOLSET_REF=2.0` stable dependency documented.
- [x] Container-first assumptions documented: Alpine PHP/Node bootstrap, non-root runtime, Docker stdout/stderr, Docker DNS/service names, no-TTY automation.
- [x] Security audit expanded repository-wide with no phase backlog/temporary allowlist.
- [x] Entrypoint exit/signal contracts revalidated after source changes.
- [x] Phase 6 documentation/security gate green in run `35089916708`.

---

# Phase 7 — LocalDevStack / Docker Consumer Validation + Final Cleanup

## Consumer validation

- [x] Inspected current LocalDevStack planning branch Docker/PHP/Node/service consumers.
- [x] Confirmed PHP/Node Dockerfiles still use `Scriptomatic/master`; recorded required migration instead of mutating planning-only Dockerfiles.
- [x] Confirmed hardened PHP/Node bootstrap call shapes remain compatible when explicit `SCRIPTOMATIC_REF`, `SCRIPTOMATIC_UID`, `SCRIPTOMATIC_GID`, and `TOOLSET_REF` are propagated.
- [x] Documented `bash`, `sh`, and login-shell boundary; application entrypoints do not depend on interactive shell startup.
- [x] Root-CA behavior under non-root runtime users documented with explicit trusted-development sudo choice.
- [x] `docknotify` defaults verified/documented against `SERVER_TOOLS:9901`, best-effort by default.
- [x] Service helpers use configurable Docker DNS/container names rather than static IP assumptions.
- [x] Current LocalDevStack Mongo is single-node; Scriptomatic replica topology remains generic/configurable instead of hard-coding the current compose shape.
- [x] Required downstream pin/config changes isolated into the LocalDevStack shared-foundations plan and permanent Scriptomatic consumer contract.
- [x] LocalDevStack `docs/plans/docker-ecosystem/01-shared-foundations-plan.md` updated with the accepted Scriptomatic/Toolset handoff contract.

## Final cleanup state

- [x] Phase 5–7 source/docs/tests pass aggregate CI before plan cleanup (`35089916708`).
- [ ] Remove any remaining one-shot migration/apply workflow/script artifacts after final repository inspection.
- [ ] Remove stale phase-only wording from permanent CI/test surfaces.
- [ ] Delete governing implementation plan and this tracker after this closeout commit.
- [ ] Refresh draft PR #57 to reference permanent artifacts only.
- [ ] Run final aggregate CI on the clean branch.
- [ ] Confirm no unresolved PR review threads/blockers.
- [ ] Branch/PR merge-ready, but do not merge automatically.

---

# Work Log

## 2026-09-16

- Created `plan/scriptomatic-hardening` from current `main`.
- Established source policy: Scriptomatic `main` by default, optional ref/SHA override; Toolset stable `2.0`.
- Completed Phases 1–2; aggregate CI green.
- Completed Phases 3–4; Node Alpine + shared-utility + security aggregate CI green (`35088528923`).
- User clarified Scriptomatic scripts are primarily consumed inside Docker/LocalDevStack containers and set a three-phases-per-batch rule.
- Started Batch 3: Phases 5–7 and updated tracker before implementation.
- Hardened Certbot reload/renewal and Mongo replica bootstrap for non-interactive container operation.
- Finalized permanent container-first docs and repository-wide security audit.
- Inspected LocalDevStack `plan/docker-ecosystem-bottom-up`; found the PHP/Node `Scriptomatic/master` migration requirement and documented the accepted downstream ref/UID/GID/sudo contract.
- Updated LocalDevStack shared-foundations plan without changing its planning-only Dockerfiles.
- Closed Batch 3 implementation at Scriptomatic head `01688ebf87da6999756d3ed9a3cdad24ecbf036e`; aggregate CI run `35089916708` fully green.
- Next operation is cleanup-only: remove temporary plan/tracker/one-shot artifacts, refresh PR #57, and require one final clean-branch CI gate.
