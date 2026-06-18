#!/usr/bin/env bash
# Main setup script for GitHub Codespace environment.
# Clone this repo and run: bash setup.sh
# Safe to run multiple times (idempotent).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${REPO_DIR}/scripts"

log() { echo "[setup] $*"; }
die() { echo "[setup] ERROR: $*" >&2; exit 1; }

log "Starting codespace setup..."
log "Running as: $(whoami)"
log "Home: ${HOME}"

# Ensure scripts are executable
chmod +x "${SCRIPTS_DIR}"/*.sh

run_step() {
  local script="$1"
  local name="$2"
  log "--- ${name} ---"
  bash "${SCRIPTS_DIR}/${script}"
}

run_step "01-apt-packages.sh"   "Installing apt packages and CLI tools"
run_step "02-nodejs.sh"         "Installing Node.js 20"
run_step "03-neovim.sh"         "Installing Neovim"
run_step "04-neovim-config.sh"  "Setting up Neovim configuration"
run_step "05-eza.sh"            "Installing eza (modern ls)"
run_step "06-yazi.sh"           "Installing yazi (file manager)"
run_step "07-lazygit.sh"        "Installing lazygit"
run_step "08-atuin.sh"          "Installing atuin (shell history)"
run_step "09-uv.sh"             "Installing uv (Python package manager)"
run_step "10-zsh-setup.sh"      "Setting up Zsh + Oh My Zsh + Powerlevel10k"
run_step "11-dotfiles.sh"       "Deploying dotfiles (.zshrc, aliases, gitconfig)"

log ""
log "Setup complete!"
log ""
log "To finish: open a new shell or run: exec zsh"
