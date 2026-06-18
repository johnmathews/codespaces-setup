#!/usr/bin/env bash
# Install uv (Python package manager) via official installer script.
# Matches shell_environment role: uv_enabled = true.

set -euo pipefail

log() { echo "[uv] $*"; }

if command -v uv &>/dev/null; then
  log "uv already installed ($(uv --version)), skipping."
  exit 0
fi

log "Installing uv via official installer..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# The installer puts uv in ~/.local/bin; make it globally available
UV_LOCAL="${HOME}/.local/bin/uv"
if [[ -x "${UV_LOCAL}" ]]; then
  sudo ln -sf "${UV_LOCAL}" /usr/local/bin/uv
fi

log "Installed: $(uv --version)"
