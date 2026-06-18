#!/usr/bin/env bash
# Install Claude Code CLI via the official Anthropic installer.
# Installer source: https://claude.ai/install.sh (official Anthropic endpoint)
# The same curl-to-bash pattern is used by the other installers in this repo
# (atuin, uv, nodejs) where an official vendor script is trusted.

set -euo pipefail

log() { echo "[claude-code] $*"; }

if command -v claude &>/dev/null; then
  log "Claude Code already installed ($(claude --version 2>/dev/null || echo 'unknown version')), skipping."
  exit 0
fi

log "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

log "Installed: $(claude --version 2>/dev/null || echo 'installed')"
