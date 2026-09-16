# Downstream Compatibility

Scriptomatic is consumed by LocalDevStack and related Docker images as a bootstrap/source-script dependency. This document records the supported downstream integration contract.

## Scriptomatic source

`main` is the canonical live distribution source:

```text
https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/<script>.sh
```

Consumers that need reproducible builds may replace `main` with a full 40-character Scriptomatic commit SHA.

For PHP/Node bootstrap, the selected source revision must also be passed through `SCRIPTOMATIC_REF` so sibling helpers are fetched from the same revision:

```dockerfile
ARG SCRIPTOMATIC_REF=main

RUN curl -fsSLo /usr/local/bin/cli-setup.sh \
      "https://raw.githubusercontent.com/infocyph/Scriptomatic/${SCRIPTOMATIC_REF}/bash/php-cli-setup.sh" \
 && chmod +x /usr/local/bin/cli-setup.sh \
 && SCRIPTOMATIC_REF="$SCRIPTOMATIC_REF" TOOLSET_REF=2.0 \
      /usr/local/bin/cli-setup.sh dev 8.4
```

The same pattern applies to `node-cli-setup.sh`.

Historical downstream URLs using `Scriptomatic/master` must migrate to `Scriptomatic/main` or a full commit SHA.

## Toolset dependency

Toolset is not consumed from `main` or `master`. PHP/Node bootstrap uses an exact stable Toolset release:

```text
TOOLSET_REF=2.0
```

`gitx` and `chromacat` are downloaded from:

```text
https://github.com/infocyph/Toolset/releases/download/<TOOLSET_REF>/...
```

and verified against the `SHA256SUMS` asset from that same release before installation.

Downstream consumers should pass an exact supported Toolset stable release rather than a branch name.

## Preserved PHP inputs

The PHP bootstrap preserves:

```text
UID
GID
LINUX_PKG
LINUX_PKG_VERSIONED
PHP_EXT
PHP_EXT_VERSIONED
MSMTP_FROM
```

and adds only the dependency selectors:

```text
SCRIPTOMATIC_REF
TOOLSET_REF
```

## Preserved Node inputs

The Node bootstrap preserves:

```text
UID
GID
LINUX_PKG
LINUX_PKG_VERSIONED
NODE_GLOBAL
NODE_GLOBAL_VERSIONED
NODE_LOG_DIR
```

and adds only the dependency selectors:

```text
SCRIPTOMATIC_REF
TOOLSET_REF
```

## Runtime compatibility

The following established behavior remains part of the downstream contract:

- PHP and Node developer runtimes execute as non-root developer users after bootstrap;
- passwordless sudo remains available inside these development images;
- installed shared helper executables under `/usr/local/bin` are root-owned;
- `docknotify` defaults to `SERVER_TOOLS:9901` and remains best-effort unless strict mode is requested;
- PHP and Node root-CA handling continues to use `ROOTCA_PATH`;
- Certbot renewal uses the fixed 12-hour cadence and fixed `/usr/local/bin/reload-services` deploy hook;
- Mongo replica bootstrap uses fixed `rs0` topology at `mongo-primary:27017`, `mongo-secondary1:27017`, and `mongo-secondary2:27017`.

## LocalDevStack migration

LocalDevStack should expose build arguments similar to:

```dockerfile
ARG SCRIPTOMATIC_REF=main
ARG TOOLSET_REF=2.0
```

Its PHP/Node Dockerfiles should fetch the initial Scriptomatic bootstrap from `SCRIPTOMATIC_REF`, pass both selectors into the setup process, and avoid direct Toolset branch downloads.

For a reproducible LocalDevStack release/build, set `SCRIPTOMATIC_REF` to an accepted Scriptomatic commit SHA while retaining the tested exact Toolset release.
