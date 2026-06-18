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

NODE_VERSION="v22.14.0"
PREFIX="/usr/local"

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 &&
  [[ "$(node --version 2>/dev/null)" == "${NODE_VERSION}" ]]; then
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

log "Downloading Node.js ${NODE_VERSION} (${NODE_ARCH})..."
curl -fsSL "${URL}" -o "${TMP}/${TARBALL}"

# Extract bin/, lib/, include/, share/ straight into /usr/local.
log "Installing into ${PREFIX}..."
sudo tar -xzf "${TMP}/${TARBALL}" -C "${PREFIX}" --strip-components=1 \
  --exclude='*/CHANGELOG.md' --exclude='*/LICENSE' --exclude='*/README.md'

rm -rf "${TMP}"
hash -r 2>/dev/null || true

if ! command -v npm >/dev/null 2>&1; then
  log "ERROR: npm not found after install."
  exit 1
fi

log "Installed node $(node --version), npm $(npm --version)"
