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
| Batch 2 | 4–6 | **Complete** |
| Batch 3 | 7–9 | Pending |

---

# Phase 1 — Repository Foundation & Permanent CI

Status: **Complete**

- [x] Root README, script contracts and security review added.
- [x] Canonical direct-`main` distribution policy documented.
- [x] Permanent assertion, static, smoke and security test framework added.
- [x] Bash/POSIX syntax validation, executable-mode validation and ShellCheck error gate added.
- [x] Permanent GitHub Actions jobs added using `actions/checkout@v7`.
- [x] PHP, Node, entrypoint, utility/server baseline, security and aggregate CI gate established.

Validated in Batch 1 CI.

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

Target:

```text
bash/node-entry.sh
```

- [x] Expanded `tests/node-entry.sh` beyond the Batch 1 forwarding baseline.
- [x] Direct command argv forwarding and exit-code propagation tested.
- [x] File-log behavior/default paths exercised.
- [x] Existing dependency auto-install and package-manager selection order preserved.
- [x] Existing pnpm/yarn/npm lockfile fallback contract retained.
- [x] Framework detection and framework-specific final `exec` paths retained.
- [x] Generic `dev` host/port attempt → plain `dev` fallback order retained.
- [x] Removed accidental duplicate execution of a successful generic `dev` command.
- [x] Generic trial path now forwards shutdown signals to its child.
- [x] Direct-command signal forwarding verified.
- [x] `NODE_CMD` remains a trusted shell-expression override.
- [x] `NODE_KEEPALIVE_ON_FAIL=1` remains the default.
- [x] npm install flags are now argv-safe rather than word-split strings.
- [x] Log-path creation reports failures clearly.
- [x] npm cache ownership handling avoids unnecessary privileged mutation.
- [x] Root-CA bootstrap no longer relies on a predictable `/tmp` stamp and is content-aware/idempotent.

---

# Phase 5 — Shared Developer Utilities

Status: **Complete**

Targets:

```text
bash/alias-maker.sh
bash/banner.sh
bash/docknotify.sh
bash/owners.sh
```

- [x] Dedicated fixtures added for all four utilities.
- [x] Existing aliases and managed utility-function block preserved.
- [x] `.bashrc` managed-block replacement made same-directory/atomic and mode-aware.
- [x] Repeated alias-maker execution verified idempotent.
- [x] `dos2unix` handling keeps filenames with spaces/shell-sensitive characters intact.
- [x] Merged-branch iteration uses structured branch output instead of presentation parsing.
- [x] Banner retains INFOCYPH/description presentation when dependencies work.
- [x] Banner degrades to plain output if figlet fails or presentation dependencies are unavailable.
- [x] Non-TTY/`NO_COLOR` output avoids making ChromaCat presentation runtime-critical.
- [x] Docknotify CLI/env/default best-effort semantics preserved.
- [x] Docknotify protocol fields sanitize tabs/newlines/carriage returns, including the token.
- [x] Docknotify now emits the intended newline-terminated wire frame.
- [x] Docknotify validates host/port safely without treating host data as command syntax.
- [x] Strict-mode send failure remains non-zero; best-effort mode remains nonfatal.
- [x] Token leakage is regression-tested.
- [x] `owners.sh` now uses NUL-safe tracked-file iteration.
- [x] `owners.sh` validates Git and git-fame dependencies.
- [x] Filenames containing spaces and shell-sensitive characters are regression-tested.

---

# Phase 6 — Certbot & Mongo Helpers

Status: **Complete**

Targets:

```text
bash/certbot-hook.sh
bash/certbot-renew.sh
bash/mongo-replica.sh
```

- [x] Dedicated Certbot and Mongo fixtures added and wired into permanent CI.
- [x] Default `NGINX` / `APACHE` names and reload commands preserved.
- [x] Running-container detection now checks exact container state rather than relying on redirected `docker ps` output.
- [x] Certbot hook no longer allocates an interactive TTY.
- [x] Reload failures return meaningful non-zero status while absent containers are skipped cleanly.
- [x] 12-hour renewal cadence remains the default through `CERTBOT_RENEW_INTERVAL`.
- [x] `/usr/local/bin/reload-services` remains the default deploy hook.
- [x] Certbot dependency/hook preflight and stop-signal handling added.
- [x] Renewal failure diagnostics improved without changing the recurring retry model.
- [x] `rs0` and the three existing default member hostnames/ports preserved.
- [x] Fixed startup sleep replaced with bounded readiness probing.
- [x] `mongosh` is preferred when available with transparent legacy `mongo` fallback.
- [x] Matching replica topology is idempotent.
- [x] Conflicting existing topology fails clearly instead of blindly reinitializing.
- [x] Uninitialized topology executes the existing `rs.initiate` intent.

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

CI run: **205**  
Implementation head: `560abc687da94f771fe27d8fbe1c05ec498092ac`  
Result: **success**

Green jobs included static/smoke, PHP/Node integration, entrypoint/server baselines, security audit and aggregate gate.

# Batch 2 Validation Record

CI run: **220**  
Implementation head: `d8fc9879be29220a7c8cb793b3a40c2e56283b8f`  
Result: **success**

Green jobs:

- Static and shell validation
- Utility smoke
- Shared utility regression
- PHP bootstrap integration
- Node bootstrap integration
- Entrypoint integration
- Server helper integration
- Security and hardening audit
- CI gate

Next execution point:

```text
Batch 3 — Phases 7–9
Phase 7 — Full Security & Reliability Audit
```
