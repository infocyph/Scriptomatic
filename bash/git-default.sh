#!/usr/bin/env bash

set -euo pipefail

die(){ echo "Error: $*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git not found"

USERNAME="${USERNAME:-${USER:-}}"
if [[ -z "${USERNAME}" ]]; then
  USERNAME="$(id -un 2>/dev/null || true)"
fi
[[ -n "${USERNAME}" ]] || die "could not determine USERNAME"

HOME_DIR="${HOME_DIR:-/home/${USERNAME}}"

GIT_SAFE_DIR_PATTERN="${GIT_SAFE_DIR_PATTERN:-/app/*}"
GIT_CREDENTIAL_STORE="${GIT_CREDENTIAL_STORE:-${HOME_DIR}/.git-credentials}"
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"

# Ensure HOME for git config (important if running as root or under docker build)
export HOME="${HOME:-$HOME_DIR}"

mkdir -p "$(dirname "$GIT_CREDENTIAL_STORE")"

# ---- Safe directory (avoid "dubious ownership" in containers)
git config --global --add safe.directory "$GIT_SAFE_DIR_PATTERN"

# ---- Credential store (file locked down)
git config --global credential.helper "store --file ${GIT_CREDENTIAL_STORE}"
( umask 077; : > "${GIT_CREDENTIAL_STORE}" )

# ---- Optional identity
if [[ -n "${GIT_USER_NAME}" ]]; then
  git config --global user.name "${GIT_USER_NAME}"
fi
if [[ -n "${GIT_USER_EMAIL}" ]]; then
  git config --global user.email "${GIT_USER_EMAIL}"
fi

# ---- Recommended defaults (LF, safer pull/push, better diffs)
git config --global core.autocrlf false
git config --global core.eol lf
git config --global core.safecrlf true

git config --global pull.rebase true
git config --global rebase.autoStash true

git config --global fetch.prune true
git config --global fetch.pruneTags true

git config --global rerere.enabled true
git config --global merge.conflictStyle zdiff3
git config --global diff.algorithm histogram

git config --global push.default simple
git config --global push.autoSetupRemote true

echo "✅ Git defaults configured for user '${USERNAME}'"
echo "   safe.directory: ${GIT_SAFE_DIR_PATTERN}"
echo "   credential store: ${GIT_CREDENTIAL_STORE}"
if [[ -n "${GIT_USER_NAME}" ]]; then echo "   user.name: ${GIT_USER_NAME}"; fi
if [[ -n "${GIT_USER_EMAIL}" ]]; then echo "   user.email: ${GIT_USER_EMAIL}"; fi
