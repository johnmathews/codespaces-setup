#!/usr/bin/env bash
# Install Node.js 20 (LTS) via NodeSource repository.
# Matches shell_environment role: nodejs_major_version = 20.

set -euo pipefail

log() { echo "[nodejs] $*"; }

NODE_MAJOR="20"

if command -v node &>/dev/null; then
  CURRENT="$(node --version)"
  if [[ "${CURRENT}" == v${NODE_MAJOR}.* ]]; then
    log "Node.js ${CURRENT} already installed, skipping."
    exit 0
  fi
  log "Found Node.js ${CURRENT}, upgrading to ${NODE_MAJOR}.x..."
fi

log "Adding NodeSource repository for Node.js ${NODE_MAJOR}.x..."
curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -

log "Installing Node.js..."
sudo apt-get install -y -q nodejs

log "Installed: $(node --version)"
