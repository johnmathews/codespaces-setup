#!/usr/bin/env bash
# The config repository owns Neovim and its tool pins, digests and platform gate.
# Run after the managed clone and general tooling so its user-local pins win.

set -euo pipefail

log() { echo "[neovim] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NVIM_CONFIG_DIR="${HOME}/.config/nvim"
BOOTSTRAP="${NVIM_CONFIG_DIR}/scripts/bootstrap-linux"
if [[ ! -f "${BOOTSTRAP}" ]]; then
  log "ERROR: ${BOOTSTRAP} missing; run scripts/04-neovim-config.sh first."
  exit 1
fi

cd "${NVIM_CONFIG_DIR}"
log "Bootstrapping Neovim and tools from ${NVIM_CONFIG_DIR}..."
RETRY_TIMEOUT="${NVIM_BOOTSTRAP_TIMEOUT:-900}" RETRY_ATTEMPTS=3 \
  retry env PREFIX="${HOME}/.local" bash "${BOOTSTRAP}"
log "Installed: $(nvim --version | head -1) ($(command -v nvim))"
