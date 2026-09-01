#!/usr/bin/env bash
# Install Node.js (LTS) + npm from the official nodejs.org tarball into /usr/local.
#
# Why not NodeSource or apt:
#   - Behind a TLS-intercepting proxy / broken third-party apt repos, the
#     NodeSource setup silently no-ops, leaving Ubuntu's nodejs (no npm bundled).
#   - Ubuntu's node is too old: current editor tools (eslint_d, markdownlint,
#     biome, ...) require Node >= 20/22 and warn/fail on Node 18.
#
# The tarball is a plain HTTPS download (works behind the proxy via the system
# CA) and extracting into /usr/local puts node/npm/npx on PATH for every shell,
# with npm's global prefix at /usr/local so `npm i -g` bins also land on PATH.

set -euo pipefail

log() { echo "[nodejs] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NODE_VERSION="v22.14.0"
PREFIX="/usr/local"

# node was already checked functionally; npm was not — `command -v npm` passes
# for a corrupt npm, and the $(npm --version) below sits in a log argument where
# a failing substitution never trips `set -e`. Run both.
if installed_version_is node "${NODE_VERSION}" && npm --version >/dev/null 2>&1; then
  log "Node.js ${NODE_VERSION} and npm $(npm --version) already installed, skipping."
  exit 0
fi

ARCH="$(uname -m)"
case "${ARCH}" in
  aarch64 | arm64) NODE_ARCH="arm64" ;;
  *) NODE_ARCH="x64" ;;
esac

TARBALL="node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz"
URL="https://nodejs.org/dist/${NODE_VERSION}/${TARBALL}"
TMP="$(mktemp -d)"
# The happy-path `rm -rf` below cannot run if the download fails under `set -e`.
trap 'rm -rf "${TMP}"' EXIT

log "Downloading Node.js ${NODE_VERSION} (${NODE_ARCH})..."
# fetch_verified runs `tar -tzf` over the whole archive BEFORE anything is
# unpacked. That matters more here than anywhere else: the extract below targets
# a live /usr/local, so a truncated tarball would half-clobber a working
# toolchain that 12-claude-code.sh and 15-dev-tools.sh depend on in this same run.
fetch_verified "${URL}" "${TMP}/${TARBALL}"

# Extract bin/, lib/, include/, share/ straight into /usr/local.
log "Installing into ${PREFIX}..."
sudo tar -xzf "${TMP}/${TARBALL}" -C "${PREFIX}" --strip-components=1 \
  --exclude='*/CHANGELOG.md' --exclude='*/LICENSE' --exclude='*/README.md'

hash -r 2>/dev/null || true

# Verify by RUNNING both, not by looking them up: a half-extracted /usr/local
# leaves files at the right paths that do not execute.
if ! node --version >/dev/null 2>&1; then
  log "ERROR: node does not run after install."
  exit 1
fi
if ! npm --version >/dev/null 2>&1; then
  log "ERROR: npm does not run after install."
  exit 1
fi

log "Installed node $(node --version), npm $(npm --version)"
