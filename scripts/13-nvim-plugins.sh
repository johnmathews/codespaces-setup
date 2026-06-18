#!/usr/bin/env bash
# Pre-load Neovim plugins headlessly using lazy.nvim.
# This script is designed to be run in the background from setup.sh so the
# Codespace becomes usable immediately while plugins install concurrently.
#
# Progress is logged to ~/.cache/nvim-setup.log (already redirected by setup.sh).
# Check status: tail -f ~/.cache/nvim-setup.log
# Wait interactively: bash ~/codespaces-setup/scripts/13-nvim-plugins.sh

set -euo pipefail

log() { echo "[nvim-plugins] $*"; }

NVIM_BIN="$(command -v nvim 2>/dev/null || true)"

if [[ -z "${NVIM_BIN}" ]]; then
  log "ERROR: nvim not found in PATH, cannot pre-load plugins."
  exit 1
fi

log "Neovim binary: ${NVIM_BIN}"
log "Neovim version: $(nvim --version | head -1)"

# Ensure sqlite-backed plugin history path exists before plugin init.
NVIM_DB_DIR="${HOME}/.local/share/nvim/databases"
mkdir -p "${NVIM_DB_DIR}"
log "Ensured Neovim database directory exists: ${NVIM_DB_DIR}"

# Bootstrap lazy.nvim and install/sync all plugins.
# '+Lazy! sync' runs synchronously in headless mode.
# '+qa' quits after the sync completes.
log "Running lazy.nvim plugin sync (this may take a few minutes)..."
if nvim --headless "+Lazy! sync" +qa 2>&1; then
  log "Plugin sync complete."
else
  log "WARNING: Plugin sync exited with non-zero status – some plugins may be missing."
  log "Re-run manually with: nvim --headless '+Lazy! sync' +qa"
fi

# Run Treesitter parser compilation for common languages.
# This avoids the first-open delay for syntax highlighting.
log "Installing common Treesitter parsers..."
if nvim --headless \
  "+TSInstall! bash python lua javascript typescript json yaml toml markdown" \
  "+TSUpdateSync" \
  +qa 2>&1; then
  log "Treesitter parsers installed."
else
  log "WARNING: Treesitter install exited non-zero – parsers may be incomplete."
fi

log "Neovim plugin pre-load finished."
log "You can now open nvim – plugins and parsers should be ready."
