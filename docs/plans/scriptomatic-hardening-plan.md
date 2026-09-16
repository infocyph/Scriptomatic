# Scriptomatic Hardening Plan

## Status

Repository: `infocyph/Scriptomatic`

Working branch: `plan/scriptomatic-hardening`

Baseline: `main` at `261397d3271cda5a6c186a64f8239bd3205fcf93`

Primary downstream consumer: `infocyph/LocalDevStack`

This plan is temporary implementation scaffolding. After the hardening program is complete, accepted, and the final branch gate is green, delete this plan and its progress tracker before merge.

---

# 1. Product Contract

Scriptomatic is a shared script/bootstrap repository, not a versioned CLI suite.

It owns reusable shell scripts for:

- PHP developer-runtime bootstrap;
- Node developer-runtime bootstrap;
- PHP/Node container entrypoints;
- developer shell aliases and presentation;
- optional host notifications;
- Certbot/server hooks;
- Mongo replica bootstrap;
- repository ownership analysis.

Scriptomatic must remain independently usable. LocalDevStack is a downstream consumer and must not define Scriptomatic's architecture.

## 1.1 Source/ref policy

Scriptomatic does **not** require a tag/release lifecycle.

Canonical source:

```text
main
```

Normal consumers may fetch from `main`.

Consumers that require reproducibility or rollback may override:

```text
SCRIPTOMATIC_REF=<branch-tag-or-commit>
```

Default:

```text
SCRIPTOMATIC_REF=main
```

All sibling Scriptomatic downloads performed by Scriptomatic scripts must use the same selected `SCRIPTOMATIC_REF`; never mix `main` and `master`.

Do not add Scriptomatic version numbers, release manifests, release installers, `SHA256SUMS`, or tag-triggered publishing merely for symmetry with Toolset.

Toolset is different: Scriptomatic must consume Toolset through the accepted Toolset stable release contract. Current expected Toolset release:

```text
TOOLSET_REF=2.0
```

Do not fetch Toolset executables from mutable `main`/`master`.

---

# 2. Baseline Findings

The current repository contains 11 Bash/POSIX shell scripts and no repository CI/test suite beyond `.github/CODEOWNERS`.

Critical findings already confirmed:

1. `php-cli-setup.sh` and `node-cli-setup.sh` fetch Toolset from mutable `main`.
2. The same setup scripts fetch Scriptomatic sibling helpers from `master`, while the repository default branch is `main`.
3. `php-cli-setup.sh` downloads `install-php-extensions` from `releases/latest`.
4. `php-cli-setup.sh` executes the Oh My Bash installer through `curl | bash`.
5. `php-cli-setup.sh` runs unconditional `composer self-update`.
6. `node-cli-setup.sh` upgrades npm to `npm@latest` and falls back to `npm@next`.
7. Both setup scripts chown shared `/usr/local/bin` helpers to the developer user.
8. Both setup scripts perform broad `/tmp/*`/`/var/tmp/*` cleanup and self-delete with `rm -f -- "$0"`.
9. Passwordless sudo is enabled unconditionally for the developer user.
10. `node-entry.sh` defaults to file logging and keepalive-on-failure, and its generic dev fallback can execute a dev script twice.
11. Runtime dependency installation can silently fall back from lockfile-strict commands to mutable installs.
12. `php-entry.sh` and `node-entry.sh` use predictable `/tmp/.rootca_installed` state instead of CA-content identity.
13. `docknotify.sh` constructs its final protocol payload via command substitution, which strips the documented trailing newline.
14. `certbot-hook.sh` uses `docker ps -q -f name=...` status rather than exact non-empty identity and invokes `docker exec -it` from a non-interactive hook.
15. `certbot-renew.sh` has an infinite loop with fixed sleep and no shutdown/error policy.
16. `mongo-replica.sh` relies on fixed `sleep 10`, legacy `mongo`, hard-coded topology, and non-idempotent initialization.
17. `owners.sh` uses `for f in $(git ls-files)`, which breaks whitespace/special-character paths.
18. `banner.sh` assumes both `figlet` and `chromacat` exist and treats presentation as a hard dependency.

---

# 3. Repository Foundation

Add permanent documentation:

```text
README.md
docs/script-contracts.md
docs/security-review.md
```

Add permanent tests:

```text
tests/lib/assert.sh
tests/static.sh
tests/alias-maker.sh
tests/banner.sh
tests/docknotify.sh
tests/owners.sh
tests/php-entry.sh
tests/node-entry.sh
tests/php-bootstrap.sh
tests/node-bootstrap.sh
tests/certbot.sh
tests/mongo-replica.sh
tests/security-audit.sh
```

Add CI under `.github/workflows/ci.yml`.

No release/publish workflow is required for Scriptomatic.

## 3.1 Script classification

Bash scripts:

```text
alias-maker.sh
banner.sh
certbot-hook.sh
certbot-renew.sh
docknotify.sh
mongo-replica.sh
node-cli-setup.sh
owners.sh
php-cli-setup.sh
```

POSIX `sh` candidates:

```text
node-entry.sh
php-entry.sh
```

Validate with the correct parser and ShellCheck dialect.

## 3.2 CI jobs

Required permanent jobs:

- syntax + ShellCheck;
- utility smoke tests;
- PHP bootstrap integration;
- Node bootstrap integration;
- runtime entrypoint integration;
- server-helper integration;
- cross-cutting security audit;
- aggregate CI gate.

Use disposable Alpine/upstream PHP and Node containers where appropriate.

---

# 4. Shared Download and Dependency Contract

Introduce explicit inputs in setup scripts:

```text
SCRIPTOMATIC_REF=main
SCRIPTOMATIC_BASE_URL=https://raw.githubusercontent.com/infocyph/Scriptomatic
TOOLSET_REF=2.0
TOOLSET_RELEASE_BASE_URL=
```

The Scriptomatic helper URL should be derived as:

```text
${SCRIPTOMATIC_BASE_URL}/${SCRIPTOMATIC_REF}/bash/<helper>
```

Toolset helpers must use Toolset's release assets for `TOOLSET_REF=2.0`, including checksum verification.

Required network behavior:

- `curl --fail --location --silent --show-error`;
- finite connect timeout;
- finite operation timeout;
- bounded retry;
- private temporary directory;
- syntax validation before installation;
- atomic destination replacement where practical.

For Scriptomatic `main`, GitHub content integrity is trusted as the selected source policy; consumers that require immutable behavior must set `SCRIPTOMATIC_REF` to a commit SHA.

Do not execute a remotely downloaded third-party installer without independent integrity/version control.

---

# 5. Phase 1 — Repository, CI, Documentation, Security Baseline

## Goals

- add README and script classification;
- add syntax + ShellCheck policy;
- add security audit;
- add test harness;
- add CI aggregate gate;
- document `main`/optional-ref policy;
- inventory exact LocalDevStack-consumed scripts without coupling behavior to LocalDevStack.

## Security audit must flag/review

```text
curl | bash
wget | sh
eval
source of user-writable config
Toolset main/master downloads
Scriptomatic master downloads
unbounded curl
world-writable files
ordinary-user ownership of /usr/local/bin helpers
predictable security-sensitive /tmp state
broad rm -rf /tmp/*
broad rm -rf /var/tmp/*
self-deleting setup scripts
untrusted sh -c
```

### Phase 1 gate

Repository static/security/smoke CI must be green before moving to runtime bootstrap mutations.

---

# 6. Phase 2 — PHP Runtime Bootstrap

Targets:

```text
bash/php-cli-setup.sh
bash/php-entry.sh
```

## 6.1 Validate privileged inputs

Validate before mutation:

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

Requirements:

- valid Linux username;
- numeric UID/GID;
- accepted PHP version syntax;
- parse comma-separated package/extension values into arrays;
- reject package tokens beginning with option syntax where unsafe;
- no privileged command built through unquoted expansion.

## 6.2 Explicit Alpine/PHP-image capability

`php-cli-setup.sh` is intentionally an Alpine/PHP-image bootstrap script.

Require and diagnose:

```text
apk
/usr/local/etc/php
docker-php-* image conventions
```

Do not make it distro-generic. Generic PHP administration belongs in Toolset `phpx`.

## 6.3 PHP extension installer

Remove floating `releases/latest` dependency.

Introduce an explicit installer version/ref/checksum contract.

Download to private temp storage, verify identity/checksum, validate executable, use it, then clean only owned temp data.

## 6.4 Composer

Remove unconditional:

```text
composer self-update
```

Introduce optional:

```text
COMPOSER_VERSION=
```

Policy:

- unset: preserve upstream Composer version;
- set: explicitly install/validate requested version;
- no implicit latest mutation.

## 6.5 Toolset

Install required Toolset helpers through exact stable release `2.0`:

```text
gitx
chromacat
```

Verify against Toolset release checksums.

## 6.6 Scriptomatic sibling helpers

Required PHP helpers:

```text
banner.sh
docknotify.sh
php-entry.sh
alias-maker.sh
```

Fetch all from the same `SCRIPTOMATIC_REF`, default `main`.

Never hard-code `master`.

## 6.7 Shared executable ownership

Everything installed in `/usr/local/bin` remains:

```text
root:root
0755
```

Never chown shared executables to the developer user.

## 6.8 Passwordless sudo

Make explicit:

```text
SCRIPTOMATIC_PASSWORDLESS_SUDO=0|1
```

Preferred default: `0`.

LocalDevStack may explicitly opt in for trusted dev containers.

## 6.9 Atomic generated config

Generate/replace atomically where practical:

```text
/etc/msmtprc
/etc/profile.d/composer-home.sh
/etc/profile.d/banner-hook.sh
/etc/profile.d/git-config-global.sh
/usr/local/etc/php/conf.d/99-script-bundle.ini
```

Validate resulting PHP/FPM configuration before declaring setup successful.

## 6.10 Cleanup

Remove broad cleanup and self-delete behavior:

```text
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -f -- "$0"
```

Use a private temp directory and trap only owned files.

## 6.11 Oh My Bash

Remove `curl | bash`.

Make optional:

```text
SCRIPTOMATIC_OH_MY_BASH=0|1
```

If enabled, use an immutable upstream ref plus verified download before execution.

Shell-presentation failure must not corrupt/fail the core runtime build unless explicitly required.

## 6.12 PHP entrypoint

Keep it small and transparent.

Replace `/tmp/.rootca_installed` with source/destination CA digest or equivalent idempotent state.

CA installation should:

- detect whether update is required;
- handle privilege capability explicitly;
- fail/skip according to documented policy;
- finish with transparent:

```sh
exec docker-php-entrypoint "$@"
```

### Phase 2 gate

Disposable PHP Alpine bootstrap + resulting non-root runtime + FPM/PHP validation must be green.

---

# 7. Phase 3 — Node Runtime Bootstrap

Targets:

```text
bash/node-cli-setup.sh
bash/node-entry.sh
```

## 7.1 Validate inputs

Validate:

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

Package/global lists must use arrays/structured parsing, not shell-reparsed strings.

## 7.2 npm reproducibility

Remove:

```text
npm install -g npm@latest
npm install -g npm@next
```

Introduce:

```text
NPM_VERSION=
```

Policy:

- unset: preserve npm shipped with selected Node image;
- set: install exact version;
- no implicit `@next` fallback.

## 7.3 Global package policy

Retain optional global package support, but add reproducible mode:

```text
SCRIPTOMATIC_REPRODUCIBLE=0|1
```

When enabled, reject unversioned global packages.

## 7.4 UID/GID reuse

Preserve the useful upstream `node` UID reuse/rename path.

After mutation, verify:

- final username;
- UID;
- GID;
- home;
- shell;
- ownership.

Do not hide failed identity migration behind broad `|| true`.

## 7.5 Helpers

Toolset:

```text
gitx
chromacat
```

from `TOOLSET_REF=2.0`.

Scriptomatic:

```text
banner.sh
docknotify.sh
node-entry.sh
alias-maker.sh
```

from the same `SCRIPTOMATIC_REF`.

## 7.6 Node entrypoint defaults

Recommended defaults:

```text
NODE_LOG_ENABLED=0
NODE_KEEPALIVE_ON_FAIL=0
NODE_AUTO_INSTALL=0
NODE_ALLOW_LOCKFILE_FALLBACK=0
```

Docker stdout/stderr should remain the primary default logging path.

A broken app should normally make the container fail rather than remain alive forever.

Runtime dependency installation must be explicit.

Strict lockfile installs must not silently fall back to mutable installs unless explicitly permitted.

## 7.7 Avoid double execution

Current generic `dev` probing may execute the same long-running command and then run it again.

Select one deterministic application command and make it the final `exec` path.

## 7.8 `NODE_CMD`

Retain only as an explicitly documented trusted shell-expression escape hatch for compatibility.

Normal container arguments are preferred.

## 7.9 Root CA

Share the PHP entrypoint's digest/idempotency model rather than maintaining a separate predictable `/tmp` stamp.

### Phase 3 gate

Disposable Node Alpine bootstrap must pass both existing-UID and new-user paths, plus non-root runtime/entrypoint tests.

---

# 8. Phase 4 — Shared Utilities

Targets:

```text
alias-maker.sh
banner.sh
docknotify.sh
owners.sh
```

## 8.1 alias-maker

- idempotent repeated execution;
- managed block replacement without duplicates;
- preserve target ownership/mode;
- use secure temp replacement;
- use sudo only when genuinely required;
- NUL-safe Git path handling remains mandatory;
- aliases depending on optional tools should degrade cleanly;
- test with disposable HOME and unusual filenames.

## 8.2 banner

Presentation must never be runtime-critical.

Behavior:

- `figlet` available -> enhanced heading;
- no `figlet` -> plain heading;
- `chromacat` available -> optional presentation enhancement;
- no/failing `chromacat` -> plain output;
- honor non-TTY and `NO_COLOR` behavior where relevant;
- support Unicode/empty description;
- banner failure must not break shell startup.

## 8.3 docknotify

Preserve best-effort default.

Fix protocol framing so the sent payload includes the documented newline; do not put final newline-containing payload through command substitution.

Sanitize/reject tabs/newlines in all protocol fields including token.

Never print notification token in diagnostics.

Test local TCP listener, absent listener, strict/non-strict mode.

## 8.4 owners

Replace whitespace-unsafe:

```text
for f in $(git ls-files)
```

with NUL-safe Git path handling.

Require/diagnose `git` and `git-fame`.

Define a stable machine-readable output contract, preferably TSV.

### Phase 4 gate

All utility fixtures must pass with no critical runtime dependency on presentation/notification tools.

---

# 9. Phase 5 — Server and Service Helpers

Targets:

```text
certbot-hook.sh
certbot-renew.sh
mongo-replica.sh
```

These remain Scriptomatic utilities but are not part of LocalDevStack's critical compatibility gate unless direct consumption is confirmed.

## 9.1 certbot-hook

- exact container identity/existence through Docker-native inspection;
- do not use `docker exec -it` from non-interactive hook;
- configurable container names;
- absent optional container -> clean skip;
- detected-container reload failure -> non-zero;
- bounded/diagnostic Docker behavior.

Suggested inputs:

```text
CERTBOT_NGINX_CONTAINER=NGINX
CERTBOT_APACHE_CONTAINER=APACHE
```

## 9.2 certbot-renew

- strict shell mode;
- configurable interval;
- optional jitter;
- signal-aware shutdown;
- useful repeated-failure diagnostics;
- no silent infinite failure loop.

Suggested:

```text
CERTBOT_RENEW_INTERVAL=12h
CERTBOT_RENEW_JITTER=0
```

## 9.3 mongo-replica

Remove fixed `sleep 10`.

Use bounded readiness polling.

Prefer `mongosh`, with deliberate legacy `mongo` compatibility only if retained.

Suggested inputs:

```text
MONGO_RS_NAME=rs0
MONGO_PRIMARY=mongo-primary:27017
MONGO_SECONDARY_1=mongo-secondary1:27017
MONGO_SECONDARY_2=mongo-secondary2:27017
MONGO_READY_TIMEOUT=60
```

Initialization must be idempotent:

1. wait for connectivity;
2. inspect replica state;
3. initiate only if uninitialized;
4. return success for matching existing config;
5. fail on conflicting config unless explicit reconciliation is introduced.

### Phase 5 gate

Deterministic local fixtures must validate exact container/reload and Mongo readiness/idempotency behavior.

---

# 10. Phase 6 — Documentation, Downstream Contract, Final Cleanup

## 10.1 Script docs

Each public script documents:

```text
Purpose
Invocation
Environment variables
Required commands
Privilege requirements
Filesystem mutations
Network access
Exit behavior
Example
```

Do not force version flags onto transparent entrypoints.

## 10.2 LocalDevStack integration contract

Downstream Dockerfiles may default to:

```dockerfile
ARG SCRIPTOMATIC_REF=main
ARG TOOLSET_REF=2.0
```

Scriptomatic URLs use the selected `SCRIPTOMATIC_REF`.

Toolset uses stable release assets for `2.0`.

A LocalDevStack release that requires exact reproducibility may override Scriptomatic with a full commit SHA without changing Scriptomatic itself.

## 10.3 Final security review

Confirm no unresolved high-impact findings involving:

- remote execution;
- package token injection;
- privilege escalation defaults;
- shared executable ownership;
- unsafe temporary files;
- broad deletion;
- secret exposure;
- entrypoint signal/exit corruption;
- hidden mutable Toolset dependency.

## 10.4 Final cleanup

Before merge:

- remove one-shot migration/apply workflows/scripts;
- delete this plan file;
- delete `docs/plans/scriptomatic-progress-tracker.md`;
- update PR description so it references only permanent artifacts;
- run final CI on the clean branch.

No Scriptomatic tag/release action is required after merge.

---

# 11. Recommended Execution Order

1. **Phase 1** — repository/CI/security foundation.
2. **Phase 2** — PHP setup + PHP entrypoint.
3. **Phase 3** — Node setup + Node entrypoint.
4. **Phase 4** — alias/banner/docknotify/owners.
5. **Phase 5** — Certbot + Mongo helpers.
6. **Phase 6** — permanent docs/downstream contract/security closeout/plan deletion.

Do not jump to downstream Docker changes until the relevant Scriptomatic contract is green.

---

# 12. Final Acceptance Criteria

Scriptomatic is merge-ready only when:

1. all shipped scripts pass the appropriate Bash/POSIX syntax checks;
2. ShellCheck is clean at the agreed severity;
3. permanent CI exists and the aggregate gate is green;
4. stable Toolset consumption uses exact release `2.0`, not mutable Toolset branches;
5. Scriptomatic sibling downloads consistently use `SCRIPTOMATIC_REF`, defaulting to `main`;
6. no setup path executes `curl | bash` or another unverified third-party remote script;
7. PHP bootstrap passes from a clean supported PHP Alpine image;
8. Node bootstrap passes from a clean supported Node Alpine image;
9. generated PHP/FPM configuration validates;
10. resulting non-root users have correct UID/GID/home/shell and do not own shared `/usr/local/bin` executables;
11. passwordless sudo is explicit rather than silently universal;
12. Composer/npm behavior is reproducible/explicit rather than implicit latest mutation;
13. entrypoints preserve transparent exec/exit/signal behavior;
14. runtime dependency installation and keepalive behavior are explicit opt-ins;
15. root-CA initialization is content-aware/idempotent, not a stale `/tmp` stamp;
16. banner/notification failures cannot break the primary runtime;
17. docknotify protocol framing is exact and secret-safe;
18. owners path handling is NUL-safe;
19. Certbot helper container detection/reload semantics are deterministic;
20. Mongo replica setup is readiness-based and idempotent;
21. cross-cutting security audit has no unresolved high-impact findings;
22. LocalDevStack can consume `SCRIPTOMATIC_REF=main` normally and override a commit when reproducibility is required;
23. one-shot implementation machinery is removed;
24. plan/tracker files are deleted before merge;
25. final clean-branch aggregate CI is green.

---

# 13. Decisions to Preserve

Do not turn Scriptomatic into Toolset.

Toolset owns general-purpose standalone CLIs such as `gitx`, `chromacat`, `phpx`, and others.

Scriptomatic owns reusable environment/bootstrap/entrypoint scripts and may consume Toolset where appropriate.

Scriptomatic remains intentionally lightweight:

- no mandatory tagging;
- no release publishing workflow;
- no suite versioning;
- `main` is the canonical normal source;
- optional `SCRIPTOMATIC_REF` provides downstream rollback/reproducibility;
- permanent CI, security review, and behavior tests provide the quality contract.
