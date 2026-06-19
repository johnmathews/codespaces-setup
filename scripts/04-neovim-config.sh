#!/usr/bin/env bash
# Clone the neovim configuration from johnmathews/neovim into ~/.config/nvim.
# If the directory already exists it is pulled to the latest commit instead.

set -euo pipefail

log() { echo "[neovim-config] $*"; }

NVIM_CONFIG_DIR="${HOME}/.config/nvim"
NVIM_REPO="https://github.com/johnmathews/neovim.git"

if [[ -d "${NVIM_CONFIG_DIR}/.git" ]]; then
  log "Neovim config already cloned, pulling latest changes..."
  if ! git -C "${NVIM_CONFIG_DIR}" pull --rebase; then
    log "ERROR: 'git pull --rebase' failed in ${NVIM_CONFIG_DIR}."
    log "       The local Neovim config has uncommitted changes or has diverged"
    log "       from upstream, so it can't be fast-forwarded automatically."
    log "       Inspect it:   git -C ${NVIM_CONFIG_DIR} status"
    log "       Or re-clone:  rm -rf ${NVIM_CONFIG_DIR} && bash scripts/04-neovim-config.sh"
    exit 1
  fi
else
  if [[ -d "${NVIM_CONFIG_DIR}" ]]; then
    log "Backing up existing config to ${NVIM_CONFIG_DIR}.bak..."
    mv "${NVIM_CONFIG_DIR}" "${NVIM_CONFIG_DIR}.bak"
  fi
  log "Cloning ${NVIM_REPO} to ${NVIM_CONFIG_DIR}..."
  git clone "${NVIM_REPO}" "${NVIM_CONFIG_DIR}"
fi

log "Neovim config ready at ${NVIM_CONFIG_DIR}"
