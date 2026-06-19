#!/usr/bin/env bash
# Install Claude Code CLI via the official Anthropic installer.
# Installer source: https://claude.ai/install.sh (official Anthropic endpoint)
# The same curl-to-bash pattern is used by the other installers in this repo
# (atuin, uv, nodejs) where an official vendor script is trusted.

set -euo pipefail

log() { echo "[claude-code] $*"; }

if command -v claude &>/dev/null; then
  before="$(claude --version 2>/dev/null || echo 'unknown version')"
  log "Claude Code already installed (${before}); updating to latest..."
  # Prefer the CLI's built-in self-updater; fall back to re-running the official
  # installer if it is missing or fails (e.g. an old build without `update`).
  if claude update 2>&1; then
    log "Up to date: $(claude --version 2>/dev/null || echo 'unknown version') (was ${before})"
  else
    log "WARNING: 'claude update' failed; re-running official installer..."
    curl -fsSL https://claude.ai/install.sh | bash
    log "Reinstalled: $(claude --version 2>/dev/null || echo 'installed') (was ${before})"
  fi
  exit 0
fi

log "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

log "Installed: $(claude --version 2>/dev/null || echo 'installed')"
