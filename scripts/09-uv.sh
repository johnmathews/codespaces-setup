#!/usr/bin/env bash
# Install uv (Python package manager) via official installer script.
# Matches shell_environment role: uv_enabled = true.

set -euo pipefail

log() { echo "[uv] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if command -v uv &>/dev/null; then
  log "uv already installed ($(uv --version)), skipping."
  exit 0
fi

log "Installing uv via official installer..."
# Download then run (with retries) instead of `curl | sh`, so a transient
# network failure can be retried rather than piping a truncated script to sh.
UV_INSTALLER="$(mktemp)"
retry net_curl https://astral.sh/uv/install.sh -o "${UV_INSTALLER}"
sh "${UV_INSTALLER}"
rm -f "${UV_INSTALLER}"

# The installer puts uv in ~/.local/bin; make it globally available
UV_LOCAL="${HOME}/.local/bin/uv"
if [[ -x "${UV_LOCAL}" ]]; then
  sudo ln -sf "${UV_LOCAL}" /usr/local/bin/uv
fi

log "Installed: $(uv --version)"
