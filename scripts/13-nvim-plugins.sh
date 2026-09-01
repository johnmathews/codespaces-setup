#!/usr/bin/env bash
# Pre-load Neovim plugins headlessly using lazy.nvim.
# This script is designed to be run in the background from setup.sh so the
# Codespace becomes usable immediately while plugins install concurrently.
#
# Progress is logged to ~/.cache/nvim-setup.log (already redirected by setup.sh).
# Check status: tail -f ~/.cache/nvim-setup.log  (or: setup-status)
# Wait interactively: bash ~/codespaces-setup/scripts/13-nvim-plugins.sh

set -euo pipefail

log() { echo "[nvim-plugins] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# This step is the single largest network consumer in the whole kit - lazy.nvim
# clones dozens of plugin repos and Treesitter downloads and COMPILES parsers -
# and it was the only network-touching script that did not source lib.sh, so it
# had no retry and no timeout. It also runs detached from setup.sh, so its exit
# status reaches nothing: not FAILED_STEPS, not the failure signal, not the exit
# code. "Neovim opens with half its plugins" was therefore completely silent.
#
# It still fails soft (a missing plugin should not fail a Codespace), but it now
# writes a status file that setup-status and the run record can read.
NVIM_STATUS_FILE="${NVIM_STATUS_FILE:-${HOME}/.cache/nvim-setup.status}"
mkdir -p "$(dirname "${NVIM_STATUS_FILE}")"
printf 'running\n' >"${NVIM_STATUS_FILE}"

NVIM_PROBLEMS=()
finish() {
  if ((${#NVIM_PROBLEMS[@]} == 0)); then
    printf 'ok\n' >"${NVIM_STATUS_FILE}"
  else
    {
      printf 'incomplete\n'
      printf '%s\n' "${NVIM_PROBLEMS[@]}"
    } >"${NVIM_STATUS_FILE}"
  fi
}
trap finish EXIT

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
# Retried and time-bounded like every other network operation. Cloning dozens
# of repos is slow, so allow a much longer per-attempt budget than the default.
if RETRY_TIMEOUT="${NVIM_SYNC_TIMEOUT:-900}" RETRY_ATTEMPTS=3 \
  retry nvim --headless "+Lazy! sync" +qa 2>&1; then
  log "Plugin sync complete."
else
  log "WARNING: Plugin sync exited with non-zero status – some plugins may be missing."
  log "Re-run manually with: nvim --headless '+Lazy! sync' +qa"
  NVIM_PROBLEMS+=("plugin sync failed")
fi

# Run Treesitter parser compilation for common languages.
# This avoids the first-open delay for syntax highlighting.
log "Installing common Treesitter parsers..."
if RETRY_TIMEOUT="${NVIM_TS_TIMEOUT:-900}" RETRY_ATTEMPTS=3 \
  retry nvim --headless \
  "+TSInstall! bash python lua javascript typescript json yaml toml markdown" \
  "+TSUpdateSync" \
  +qa 2>&1; then
  log "Treesitter parsers installed."
else
  log "WARNING: Treesitter install exited non-zero – parsers may be incomplete."
  NVIM_PROBLEMS+=("treesitter parser install failed")
fi

log "Neovim plugin pre-load finished."
log "You can now open nvim – plugins and parsers should be ready."
