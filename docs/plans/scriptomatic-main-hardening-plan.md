# Scriptomatic — Main-Branch Hardening & Compatibility Plan

## Status

Working branch:

```text
plan/scriptomatic-main-hardening
```

Baseline:

```text
repository: infocyph/Scriptomatic
base branch: main
base commit: 261397d3271cda5a6c186a64f8239bd3205fcf93
```

This repository does **not** require a release/tag lifecycle.

The supported consumption model remains direct installation/download from `main`.

Examples such as the following remain valid repository contracts:

```text
https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/<script>.sh
```

No version tag, release asset, release installer, or release manifest is required by this plan.

---

# 1. Governing Rules

## 1.1 Preserve Existing Behavior

Existing externally observable behavior is a hard compatibility requirement.

During this program we may:

- harden unsafe implementation details;
- improve validation;
- improve quoting and argv safety;
- improve temporary-file handling;
- make network activity bounded;
- improve diagnostics;
- make operations idempotent where they are intended to be repeatable;
- eliminate race conditions;
- improve signal handling without changing command semantics;
- improve portability within each script's existing supported environment;
- add tests and CI;
- remove accidental bugs where the intended behavior is already clear;
- reduce duplication when doing so does not alter current behavior.

We must **not** silently change established behavior, defaults, workflows, or expected integration semantics merely because another design might be cleaner.

Examples of behavior that must remain compatible unless separately approved:

- Scriptomatic is consumable directly from `main`;
- PHP/Node setup scripts continue to provide the same developer-environment responsibilities;
- current user creation/reuse behavior remains available;
- current passwordless-sudo behavior remains available as currently expected by consumers;
- current npm/Composer setup behavior is preserved unless implementation hardening can be performed transparently;
- current Node dependency-install and fallback behavior is preserved;
- current Node keepalive behavior is preserved;
- `NODE_CMD` keeps its current shell-expression behavior;
- existing banner, alias, notification, Certbot and Mongo workflows stay recognizable and compatible;
- existing environment-variable names remain supported;
- currently consumed executable paths remain supported.

If a security/correctness fix would necessarily alter an observable contract, stop that item at the planning/test boundary and record it in the tracker for an explicit decision instead of changing behavior implicitly.

## 1.2 Main Is the Distribution Contract

`main` is the canonical install source.

This plan does **not** introduce:

- GitHub Releases as a requirement;
- stable tags as a requirement;
- version-coupled Scriptomatic assets;
- an `install.sh` release system;
- a Scriptomatic self-update protocol;
- immutable release references as a mandatory consumer contract.

Consumers may still choose to pin a commit SHA on their own when they require reproducible builds, but Scriptomatic itself continues to support `main` directly.

## 1.3 Scriptomatic Remains Scriptomatic

Do not turn this repository into Toolset.

Toolset owns reusable general-purpose CLIs.

Scriptomatic owns shell/bootstrap/runtime/environment scripts and supporting utilities.

Where Scriptomatic already consumes Toolset utilities such as `gitx` and `chromacat`, keep that relationship rather than duplicating their implementations.

---

# 2. Current Script Surface

Current Bash/script surface:

```text
bash/alias-maker.sh
bash/banner.sh
bash/certbot-hook.sh
bash/certbot-renew.sh
bash/docknotify.sh
bash/mongo-replica.sh
bash/node-cli-setup.sh
bash/node-entry.sh
bash/owners.sh
bash/php-cli-setup.sh
bash/php-entry.sh
```

Classify them as follows for testing and ownership:

| Script | Role | Critical consumer class |
|---|---|---|
| `php-cli-setup.sh` | PHP image/dev-runtime bootstrap | high |
| `node-cli-setup.sh` | Node image/dev-runtime bootstrap | high |
| `php-entry.sh` | PHP runtime entrypoint wrapper | high |
| `node-entry.sh` | Node runtime entrypoint | high |
| `alias-maker.sh` | interactive developer shell helper | medium |
| `banner.sh` | presentation helper | medium |
| `docknotify.sh` | optional host-notification client | medium |
| `certbot-hook.sh` | Certbot deploy-hook helper | medium |
| `certbot-renew.sh` | Certbot renewal loop | medium |
| `mongo-replica.sh` | Mongo replica bootstrap | medium |
| `owners.sh` | Git ownership-analysis utility | low/standalone |

---

# 3. Phase 1 — Repository Foundation & Permanent CI

## 3.1 Documentation

Add or normalize:

```text
README.md
docs/script-contracts.md
docs/security-review.md
```

Document each script with:

- purpose;
- expected shell;
- normal invocation;
- current environment variables;
- required external commands;
- root/non-root expectation;
- network access;
- filesystem mutations;
- current failure behavior;
- known consumer assumptions.

Documentation must describe actual behavior, not desired behavior that has not yet been implemented.

## 3.2 Static Validation

Add permanent checks for:

- `bash -n` for Bash scripts;
- `sh -n` for explicitly POSIX-`sh` scripts;
- ShellCheck;
- executable-bit expectations where appropriate;
- CRLF detection;
- unsafe merge-conflict markers;
- accidental debug leftovers.

Use targeted ShellCheck suppressions only when the current behavior genuinely requires them.

## 3.3 CI

Add `.github/workflows/ci.yml`.

Use current major GitHub actions.

Minimum jobs:

1. static/syntax/ShellCheck;
2. utility smoke tests;
3. PHP setup integration;
4. Node setup integration;
5. entrypoint integration;
6. server-helper integration;
7. security/hardening audit;
8. aggregate CI gate.

CI must test the real behavior without requiring a tag or GitHub Release.

## 3.4 Test Helpers

Create:

```text
tests/lib/assert.sh
tests/static.sh
tests/smoke.sh
tests/security-audit.sh
```

All test fixtures must use temporary directories and clean them deterministically.

---

# 4. Phase 2 — PHP Bootstrap Hardening

Targets:

```text
bash/php-cli-setup.sh
bash/php-entry.sh
```

## 4.1 Input Validation Without Contract Changes

Validate current inputs before privileged mutation:

```text
USERNAME
PHP_VERSION
UID
GID
LINUX_PKG
LINUX_PKG_VERSIONED
PHP_EXT
PHP_EXT_VERSIONED
MSMTP_FROM
```

Preserve all current environment-variable names and accepted normal values.

Reject values that would be interpreted as shell/package-manager control syntax rather than package/extension names.

Parse comma-separated lists safely into arrays instead of relying on unsafe word splitting.

## 4.2 Environment Detection

The script is intentionally coupled to Alpine-based official-style PHP images.

Fail clearly when required capabilities are absent rather than failing deep in execution:

```text
apk
/usr/local/etc/php
PHP-FPM configuration paths
required user-management utilities
```

Do not attempt a distro-general rewrite in this project.

## 4.3 Remote Downloads

Keep current functional behavior, including installing required helper content, but harden downloads:

- bounded connect timeout;
- bounded overall timeout;
- finite retries with backoff;
- download to private temporary files;
- validate non-empty content;
- validate expected script syntax where applicable;
- atomic move into destination;
- clean partial files on failure.

Direct `main` consumption is allowed and remains supported.

Do not introduce a mandatory tag/release reference.

## 4.4 Toolset Helpers

Continue installing the currently expected Toolset helpers:

```text
gitx
chromacat
```

The current Toolset source policy may continue unless the downstream ecosystem separately chooses to pin it.

Scriptomatic hardening must not copy/fork Toolset source code.

## 4.5 Scriptomatic Sibling Helpers

Continue installing the same sibling helpers used today:

```text
banner.sh -> show-banner
docknotify.sh -> docknotify
php-entry.sh -> php-entry
alias-maker.sh -> alias-maker
```

Normalize branch usage to the repository's canonical `main` branch where Scriptomatic currently mixes `master` and `main`.

This is not a tag/release change; it removes stale branch naming while preserving the live-main installation model.

## 4.6 User and Permission Hardening

Preserve current user creation behavior and current sudo capability expected by development containers.

Harden:

- UID/GID validation;
- pre-existing group/user handling;
- ownership verification;
- home-directory creation;
- sudoers file mode/content validation;
- predictable failure when desired UID/GID conflicts cannot be reconciled safely.

Shared executable permissions should be deterministic.

Do not change user-visible privilege behavior in this phase.

## 4.7 Generated Configuration

Keep generating the same current configuration:

```text
/etc/msmtprc
/etc/profile.d/composer-home.sh
/etc/profile.d/banner-hook.sh
/etc/profile.d/git-config-global.sh
/usr/local/etc/php/conf.d/99-script-bundle.ini
PHP-FPM include configuration
```

Harden writes with temporary files and atomic replacement where practical.

Validate resulting PHP/FPM configuration before declaring setup successful.

Repeated execution must not create duplicate includes/hooks/config lines.

## 4.8 Composer and PHP Extension Installer

Preserve current functional behavior.

Hardening goals:

- bound downloads;
- validate installer content where practical;
- ensure failures are explicit;
- avoid half-installed executable files;
- retain current Composer update behavior unless an explicit later decision changes it;
- retain current PHP extension input behavior.

Do not convert this item into a version-policy redesign.

## 4.9 Cleanup

Limit cleanup to paths created/owned by this script whenever possible.

Review broad cleanup commands carefully so they do not remove mounted/runtime-required content.

Preserve the resulting image state expected by current consumers.

Self-removal of the setup script must be tested as part of the existing behavior before any decision to change it.

## 4.10 `php-entry.sh`

Preserve:

```text
root-CA bootstrap
docker-php-entrypoint argument forwarding
```

Harden:

- sudo/root capability detection;
- idempotency;
- failure diagnostics;
- CA copy/update handling;
- temporary-state handling;
- final `exec` semantics.

Final application invocation must remain:

```sh
exec docker-php-entrypoint "$@"
```

---

# 5. Phase 3 — Node Bootstrap Hardening

Targets:

```text
bash/node-cli-setup.sh
bash/node-entry.sh
```

## 5.1 Input Validation

Validate existing inputs without renaming/removing them:

```text
USERNAME
NODE_VERSION
UID
GID
LINUX_PKG
LINUX_PKG_VERSIONED
NODE_GLOBAL
NODE_GLOBAL_VERSIONED
NODE_LOG_DIR
```

Safely parse package lists.

## 5.2 Existing UID/GID Reuse

Preserve the important current behavior where an existing upstream `node` user occupying UID 1000 can be reused/renamed.

Harden each transition and verify the resulting state:

- username;
- UID;
- primary GID;
- home;
- shell;
- ownership.

Avoid broad `|| true` around correctness-critical state changes.

## 5.3 npm/Corepack Behavior

Preserve current observable behavior:

- Corepack enable remains best-effort;
- npm update behavior remains compatible;
- optional global package inputs remain supported;
- npm cache/global prefix stays user-owned.

Harden command construction so user-provided package-list data cannot become arbitrary shell syntax.

Improve error diagnostics while retaining existing fallback semantics.

## 5.4 Helper Installation

Continue installing the same helpers as today:

```text
Toolset: gitx, chromacat
Scriptomatic: banner.sh, docknotify.sh, node-entry.sh, alias-maker.sh
```

Normalize Scriptomatic self-references to canonical `main` rather than stale `master` references.

Use bounded/atomic downloads without introducing tagging.

## 5.5 Shell/Profile Mutation

Preserve current `.bashrc` additions and shell setup.

Make them idempotent and ownership-safe.

Repeated execution must not duplicate:

- npm prefix lines;
- PATH lines;
- Git config line;
- banner snippet;
- managed alias/function blocks.

---

# 6. Phase 4 — Node Entrypoint Hardening

Target:

```text
bash/node-entry.sh
```

Preserve all existing high-level behavior:

- APP_DIR default;
- log-file behavior;
- direct command override;
- HOST/PORT defaults;
- dependency auto-install behavior;
- pnpm/yarn/npm selection order;
- current lockfile fallbacks;
- framework detection;
- `dev` then `start`/server fallback strategy;
- `NODE_CMD` shell-expression override;
- current keepalive-on-failure behavior and default;
- root-CA bootstrap behavior.

Hardening goals:

- quote paths/arguments safely;
- avoid unintended duplicate process execution where it can be fixed without changing intended fallback semantics;
- ensure a selected long-running process becomes the final `exec` path;
- preserve exit codes;
- preserve signal delivery;
- bound or clarify any potentially blocking setup operation;
- improve npm-cache permission handling;
- make CA bootstrap idempotent;
- avoid silent permission failures where they matter;
- prevent log-path input from producing unsafe unintended filesystem mutations.

Add regression tests first so hardening can prove compatibility.

---

# 7. Phase 5 — Shared Developer Utilities

## 7.1 `alias-maker.sh`

Preserve all current aliases and helper functions unless a concrete correctness bug is demonstrated.

Harden:

- repeated execution/idempotency;
- temporary-file replacement;
- `.bashrc` ownership/mode preservation;
- NUL-safe Git filename handling already expected by helper functions;
- optional dependency diagnostics;
- `dos2unix` failure cleanup;
- merged-branch handling.

Tests must run against a disposable HOME and Git repository.

## 7.2 `banner.sh`

Preserve current visual behavior when dependencies are available:

- INFOCYPH figlet heading;
- random credit;
- random ChromaCat box style;
- description box.

Harden graceful behavior around missing/limited terminal capabilities while keeping successful output compatible.

Banner rendering must not become runtime-critical for setup/entrypoint behavior.

Test:

- normal TTY-style environment;
- piped/non-TTY output;
- missing dependency behavior;
- long description;
- empty/default description.

## 7.3 `docknotify.sh`

Preserve:

- environment-variable names;
- CLI options;
- best-effort default;
- `DOCKNOTIFY_STRICT=1` failure mode;
- host/port defaults;
- urgency and timeout semantics;
- title/body caps;
- single-line protocol.

Harden:

- protocol framing;
- newline/tab sanitization for all protocol fields;
- token secrecy in errors;
- numeric validation;
- bounded socket operation;
- exact strict/non-strict exit behavior.

Use a local TCP fixture to validate the bytes actually sent.

## 7.4 `owners.sh`

Preserve the utility's purpose and recognizable output.

Replace whitespace-unsafe iteration with NUL-safe Git file traversal.

Check required commands explicitly:

```text
git
git-fame
```

Test filenames containing spaces and other shell-sensitive characters.

---

# 8. Phase 6 — Server/Service Helpers

## 8.1 `certbot-hook.sh`

Preserve its job:

- reload NGINX container when present;
- reload APACHE container when present.

Harden:

- exact running-container detection;
- no false-positive branch based only on `docker ps` command success;
- non-interactive `docker exec` suitable for Certbot hooks;
- clear diagnostics;
- proper exit status on a detected-container reload failure.

Keep existing container names compatible.

## 8.2 `certbot-renew.sh`

Preserve current behavior:

```text
renew quietly
use /usr/local/bin/reload-services as deploy hook
repeat every 12h
```

Harden:

- strict shell mode where compatible;
- signal handling;
- interruption of sleep on shutdown;
- diagnostics on repeated renewal failures;
- dependency checks.

Do not change the 12-hour default or renewal command contract without explicit approval.

## 8.3 `mongo-replica.sh`

Preserve current intended topology by default:

```text
replica set: rs0
mongo-primary:27017
mongo-secondary1:27017
mongo-secondary2:27017
```

Harden:

- readiness detection rather than relying solely on a fixed sleep;
- compatibility with the currently expected Mongo shell and modern `mongosh` where available;
- idempotent detection of an already-initialized replica set;
- clear failure when the topology conflicts;
- bounded wait.

Default topology must remain unchanged.

---

# 9. Phase 7 — Security & Reliability Audit

Add a permanent repository audit for high-impact patterns.

Review, but do not mechanically reject without context:

```text
curl | bash
wget | sh
eval
source of writable files
unquoted variable expansion in privileged commands
unbounded curl
predictable temporary paths
world-writable executable/config paths
unsafe `for x in $(...)` filename handling
interactive flags in non-interactive hooks
broad `rm -rf`
mutable-branch remote downloads
```

Important: mutable `main` downloads are **allowed by repository policy**.

The audit should distinguish:

- allowed direct-`main` distribution policy;
- genuinely unsafe transport/execution patterns.

Do not fail CI merely because a URL contains `/main/`.

---

# 10. Test Matrix

Create/maintain permanent tests:

```text
tests/lib/assert.sh
tests/static.sh
tests/smoke.sh
tests/security-audit.sh
tests/alias-maker.sh
tests/banner.sh
tests/docknotify.sh
tests/owners.sh
tests/php-bootstrap.sh
tests/php-entry.sh
tests/node-bootstrap.sh
tests/node-entry.sh
tests/certbot.sh
tests/mongo-replica.sh
```

## 10.1 PHP Integration

Validate in a disposable compatible PHP Alpine image:

- package/bootstrap path;
- user creation;
- UID/GID;
- sudo capability expected by current environment;
- helper downloads;
- helper executable permissions;
- Composer configuration;
- FPM include generation;
- PHP CA configuration;
- msmtp configuration;
- alias setup;
- banner hook;
- non-root user shell;
- rerun/idempotency where applicable;
- cleanup behavior.

## 10.2 Node Integration

Validate in a disposable compatible Node Alpine image:

- existing upstream `node` user path;
- fresh-user path;
- UID/GID/home/shell;
- sudo behavior;
- npm prefix/cache;
- Corepack behavior;
- npm update fallback semantics;
- optional global packages;
- helpers;
- alias/banner setup;
- non-root execution.

## 10.3 Entrypoint Integration

Validate:

- direct command forwarding;
- argument preservation;
- exit code;
- final `exec` behavior;
- signals;
- CA bootstrap;
- current Node dependency-install semantics;
- current framework detection;
- `NODE_CMD`;
- current keepalive default.

## 10.4 Utility/Server Fixtures

Use local fixtures/mocks for:

- TCP notification receiver;
- fake Docker CLI/container state;
- fake Certbot;
- fake Mongo shell/readiness/state;
- disposable Git repository with difficult filenames.

No test should require destructive host-level operations.

---

# 11. CI Gate

The final aggregate CI gate must require all permanent jobs used by the project.

Do not merge a hardening phase while its relevant integration job is red.

Where GitHub Actions cannot faithfully reproduce an environment, add a deterministic fixture test plus document the limitation rather than silently skipping it.

---

# 12. Downstream Compatibility

The primary downstream Docker ecosystem must continue to be able to consume Scriptomatic directly from `main`.

Expected canonical form:

```text
https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/<script>.sh
```

Consumers that need stronger rebuild reproducibility may choose a full commit SHA themselves:

```text
https://raw.githubusercontent.com/infocyph/Scriptomatic/<commit-sha>/bash/<script>.sh
```

This is optional consumer policy, not a Scriptomatic release requirement.

Do not force LocalDevStack or any other consumer onto Scriptomatic tags/releases through this plan.

---

# 13. Implementation Order

Execute in this order:

1. repository foundation and baseline CI;
2. PHP bootstrap + PHP entrypoint;
3. Node bootstrap;
4. Node entrypoint;
5. alias/banner/docknotify/owners utilities;
6. Certbot/Mongo server helpers;
7. full security/reliability audit;
8. docs and downstream compatibility verification;
9. final full CI gate and cleanup.

At every phase:

1. add/strengthen regression tests for current behavior first;
2. harden implementation;
3. prove behavior remains compatible;
4. update the tracker with exact completed items and any deferred decision.

---

# 14. Acceptance Criteria

The hardening program is complete when:

1. All shipped scripts pass the correct shell syntax policy.
2. ShellCheck is clean under the repository's documented policy.
3. Permanent CI exists and is green.
4. PHP bootstrap succeeds in a clean compatible PHP Alpine fixture.
5. Node bootstrap succeeds in a clean compatible Node Alpine fixture.
6. Current user/UID/GID/sudo behavior remains compatible.
7. Current npm/Composer behavior remains compatible unless explicitly changed later.
8. Current Node dependency-install/fallback/keepalive behavior remains compatible.
9. Entrypoints preserve arguments, exit codes and signals.
10. Generated PHP/FPM configuration validates.
11. `.bashrc` and profile mutation is idempotent.
12. Banner/notification helpers cannot unexpectedly break the primary development runtime.
13. `docknotify` protocol and strict/non-strict behavior are regression-tested.
14. Certbot helpers detect/reload the intended containers correctly.
15. Mongo replica bootstrap is bounded and idempotent while preserving the existing default topology.
16. Git/file traversal safely handles spaces and shell-sensitive filenames.
17. Remote downloads use bounded and failure-safe mechanics.
18. Scriptomatic continues to be installable directly from `main` with no tag/release requirement.
19. Existing environment variables and known invocation paths remain supported.
20. Any behavior-changing proposal discovered during hardening is separately recorded and not silently implemented.
21. The final aggregate CI gate is green on the clean branch.
22. Temporary migration/apply helpers are removed before merge; permanent tests/workflows remain.

---

# 15. Explicit Non-Goals

This plan does not:

- introduce Scriptomatic version tags;
- introduce GitHub Release publishing;
- add a Scriptomatic installer/updater product;
- replace direct `main` distribution;
- redesign existing PHP/Node developer-container behavior;
- remove current environment variables;
- make Scriptomatic a general CLI framework;
- duplicate Toolset functionality;
- change LocalDevStack architecture beyond what is needed to keep consuming hardened Scriptomatic behavior.
