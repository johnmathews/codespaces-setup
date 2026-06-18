#!/usr/bin/env bash
# Install Node.js (LTS) and npm.
# Prefers Node 20 from NodeSource, but always guarantees a working `node` AND
# `npm`. This matters because:
#   - Ubuntu's `nodejs` package does NOT bundle npm (it's a separate package).
#   - Behind a TLS-intercepting proxy / with broken third-party apt repos, the
#     NodeSource setup can silently no-op, leaving distro node without npm.

set -euo pipefail

log() { echo "[nodejs] $*"; }

NODE_MAJOR="20"

have_node_and_npm() {
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}

if have_node_and_npm && [[ "$(node --version 2>/dev/null)" == v${NODE_MAJOR}.* ]]; then
  log "Node.js $(node --version) and npm $(npm --version) already installed, skipping."
  exit 0
fi

log "Attempting Node.js ${NODE_MAJOR}.x install via NodeSource..."
if curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -; then
  sudo apt-get install -y -q nodejs || log "WARNING: NodeSource 'apt-get install nodejs' failed."
else
  log "WARNING: NodeSource setup failed (proxy/repo?); falling back to distro packages."
fi

# Guarantee node + npm exist regardless of how the NodeSource step went.
if ! command -v node >/dev/null 2>&1; then
  log "node still missing; installing distro nodejs..."
  sudo apt-get install -y -q nodejs
fi
if ! command -v npm >/dev/null 2>&1; then
  log "npm missing (distro nodejs ships without it); installing the npm package..."
  sudo apt-get install -y -q npm
fi

if ! command -v npm >/dev/null 2>&1; then
  log "ERROR: npm could not be installed."
  exit 1
fi

log "Installed node $(node --version), npm $(npm --version)"
