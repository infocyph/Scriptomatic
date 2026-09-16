# Downstream Compatibility

Scriptomatic's canonical distribution branch is `main`. This repository does not require tags or GitHub Releases for consumption.

## LocalDevStack

The current LocalDevStack default branch still references the historical Scriptomatic `master` raw URLs in:

```text
docker/dockerfiles/php.Dockerfile
docker/dockerfiles/node.Dockerfile
```

After the Scriptomatic hardening PR is merged, the downstream follow-up is intentionally small:

```text
https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/php-cli-setup.sh
→
https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/php-cli-setup.sh

https://raw.githubusercontent.com/infocyph/Scriptomatic/master/bash/node-cli-setup.sh
→
https://raw.githubusercontent.com/infocyph/Scriptomatic/main/bash/node-cli-setup.sh
```

No tag/release reference is required.

The hardened scripts preserve the LocalDevStack-relevant contracts:

- PHP setup invocation remains `cli-setup.sh USERNAME PHP_VERSION`.
- Node setup invocation remains `cli-setup.sh USERNAME NODE_VERSION`.
- `UID`, `GID` and existing package/extension/global-package environment inputs remain supported.
- PHP entrypoint remains `/usr/local/bin/php-entry`.
- Node entrypoint remains `/usr/local/bin/node-entry`.
- Passwordless sudo behavior used by the existing development images remains available.
- Toolset helpers remain installed under the same executable names.
- Scriptomatic sibling helpers remain installed under the same executable names.

The PHP integration suite exercises a clean `php:8.4-fpm-alpine` image. The Node integration suite exercises `node:24-alpine`, including both upstream UID reuse and fresh-user creation paths.

Consumers that require immutable/reproducible builds may substitute a full Scriptomatic commit SHA for `main`; this is optional and not Scriptomatic's mandatory distribution model.

## Ownership boundary

Scriptomatic owns bootstrap/runtime/environment shell behavior. Toolset owns the reusable general-purpose CLIs such as `gitx` and `chromacat`. Downstream projects compose the two; Scriptomatic must not fork Toolset CLI implementations.
