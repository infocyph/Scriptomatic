# Downstream Compatibility

Scriptomatic is consumed by LocalDevStack and related Docker images as a bootstrap/source-script dependency. This document records the supported downstream integration contract.

## Scriptomatic source

`main` is the canonical live distribution source:

```text
https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/<script>.sh
```

Consumers that need reproducible Scriptomatic builds may replace `main` with a full 40-character Scriptomatic commit SHA.

For PHP/Node bootstrap, the selected source revision must also be passed through `SCRIPTOMATIC_REF` so sibling helpers are fetched from the same revision:

```dockerfile
ARG SCRIPTOMATIC_REF=main

RUN curl -fsSLo /usr/local/bin/cli-setup.sh \
      "https://raw.githubusercontent.com/infocyph/Scriptomatic/${SCRIPTOMATIC_REF}/bash/php-cli-setup.sh" \
 && chmod +x /usr/local/bin/cli-setup.sh \
 && SCRIPTOMATIC_REF="$SCRIPTOMATIC_REF" \
      /usr/local/bin/cli-setup.sh dev 8.4
```

The same pattern applies to `node-cli-setup.sh`.

Historical downstream URLs using `Scriptomatic/master` must migrate to `Scriptomatic/main` or a full commit SHA.

## Toolset dependency

Toolset is not consumed from `main` or `master`. PHP/Node bootstrap uses Toolset's latest stable GitHub Release installer:

```text
https://github.com/infocyph/Toolset/releases/latest/download/install.sh
```

The bootstrap invokes that installer once for `gitx` and `chromacat`, targeting `/usr/local/bin`. Toolset's installer resolves the latest stable release, downloads its `SHA256SUMS`, verifies each selected CLI, validates syntax/version behavior, and installs the tools atomically.

There is intentionally no separate `TOOLSET_REF` input in Scriptomatic. Downstream consumers follow the latest stable Toolset release channel.

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
SCRIPTOMATIC_REF
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
SCRIPTOMATIC_REF
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

LocalDevStack should expose the Scriptomatic source selector:

```dockerfile
ARG SCRIPTOMATIC_REF=main
```

Its PHP/Node Dockerfiles should fetch the initial Scriptomatic bootstrap from `SCRIPTOMATIC_REF`, pass that selector into the setup process, and avoid direct Toolset branch downloads. Scriptomatic itself handles Toolset installation through the latest stable release installer.

For a reproducible LocalDevStack source build, set `SCRIPTOMATIC_REF` to an accepted Scriptomatic commit SHA. Toolset intentionally continues to track its latest stable release.
