#!/usr/bin/env bash
# Install Claude Code CLI via the official installer.

set -euo pipefail

log() { echo "[claude-code] $*"; }

if command -v claude &>/dev/null; then
  log "Claude Code already installed ($(claude --version 2>/dev/null || echo 'unknown version')), skipping."
  exit 0
fi

log "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

log "Installed: $(claude --version 2>/dev/null || echo 'installed')"
