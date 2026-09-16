# Security Review

Scriptomatic contains privileged Docker-image bootstrap scripts, runtime entrypoints and service helpers. This review intentionally distinguishes concrete security/correctness fixes from product policy: established `main` behavior is not redesigned in the name of hardening.

## Dependency/source boundaries

Accepted source rules:

- Scriptomatic siblings default to `SCRIPTOMATIC_REF=main` and may be commit-pinned downstream.
- Toolset helpers use stable `TOOLSET_REF=2.0` plus that release's checksum manifest.
- Toolset `main`/`master` and Scriptomatic `master` are not used for installed helper scripts.

Existing upstream behavior that remains unchanged:

- `install-php-extensions` is obtained from its existing `releases/latest` URL;
- Composer is requested through `install-php-extensions @composer`;
- Oh My Bash uses its existing upstream `master` installer;
- Node setup retains its existing `npm@latest` / `npm@next` update attempt.

Those are existing product/dependency choices. This hardening pass does not expose new version-selection APIs for them.

The Oh My Bash installer is downloaded to a private temporary file and syntax-checked rather than piped directly from curl into Bash.

## Shell and argument safety

- privileged package/extension/global-package inputs are parsed before invocation rather than shell-reparsed through unquoted replacement text;
- tokens that can become command options are rejected where relevant;
- shell `eval` is not introduced;
- `NODE_CMD` remains the existing trusted shell-expression escape hatch and is not treated as untrusted input.

## Filesystem and ownership

- shared `/usr/local/bin` helpers remain `root:root` and executable;
- temporary workspaces are private and scripts clean only their own temporary content;
- broad `rm -rf /tmp/*` / `/var/tmp/*` cleanup is removed;
- setup scripts no longer delete themselves;
- generated privileged files use explicit modes/atomic replacement where practical;
- the historical passwordless-sudo developer-container behavior remains unchanged rather than becoming a new policy switch.

## Runtime CA handling

PHP and Node entrypoints keep the existing `ROOTCA_PATH` input and best-effort behavior. The fixed system destination remains `/usr/local/share/ca-certificates/rootCA.crt`.

The unsafe part was the global `/tmp/.rootca_installed` marker: a changed mounted CA could be ignored. It is replaced by content comparison. No new CA strictness/destination API is introduced.

## Node entrypoint

Historical logging, automatic dependency install/fallback, keepalive, host/port and `NODE_CMD` behavior remain.

The concrete correctness fix is that a successful generic `npm run dev` compatibility attempt is no longer executed a second time.

## Presentation and utilities

Banner layout/credits/box styles are product presentation and are preserved. Hardening only adds safe plain fallback when terminal styling dependencies are unavailable.

`owners.sh` keeps its human output while making Git path enumeration NUL-safe.

`docknotify.sh` keeps its existing interface and best-effort semantics; the protocol newline is fixed and token/protocol separators are not leaked into the wire format or diagnostics.

## Docker-control helpers

`certbot-hook.sh` keeps fixed `NGINX` / `APACHE` names and reload-if-running behavior. Exact container inspection replaces substring matching, and `docker exec -it` becomes non-interactive `docker exec`.

`certbot-renew.sh` remains the original 12-hour infinite renewal loop. This pass does not add interval, jitter, retry-threshold or lifecycle policy controls.

## Mongo

The original `rs0` topology and member names remain fixed. The concrete fixes are:

- readiness polling instead of fixed `sleep 10`;
- `mongosh` preference with legacy `mongo` fallback;
- no repeated `rs.initiate()` when the desired topology already exists;
- refusal to overwrite a conflicting existing topology.

No new Mongo topology/configuration API is introduced.

## Permanent audit

`tests/security-audit.sh` checks concrete hazards only: mutable Toolset/Scriptomatic helper refs, remote pipe-to-shell execution, broad shared-temp deletion, setup self-deletion, stale CA stamp state, unsafe shared-binary ownership, shell `eval`, Docker TTY use, substring Certbot detection, unsafe Git filename enumeration and the fixed Mongo startup sleep.

It also prevents accidental reintroduction of the unsolicited configuration variables removed during the scope-correction pass.
