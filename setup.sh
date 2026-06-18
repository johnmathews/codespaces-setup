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
run_step "11-dotfiles.sh"       "Deploying dotfiles (.zshrc, aliases, gitconfig)"
run_step "14-fonts.sh"          "Installing MesloLGS NF (Nerd Font)"
run_step "02-nodejs.sh"         "Installing Node.js 20"
run_step "03-neovim.sh"         "Installing Neovim"
run_step "04-neovim-config.sh"  "Setting up Neovim configuration"
run_step "05-eza.sh"            "Installing eza (modern ls)"
run_step "06-yazi.sh"           "Installing yazi (file manager)"
run_step "07-lazygit.sh"        "Installing lazygit"
run_step "08-atuin.sh"          "Installing atuin (shell history)"
run_step "09-uv.sh"             "Installing uv (Python package manager)"
run_step "10-zsh-setup.sh"      "Setting up Zsh + Oh My Zsh + Powerlevel10k"
run_step "12-claude-code.sh"    "Installing Claude Code"

log ""
log "Core setup complete. Starting Neovim plugin pre-load in background..."
mkdir -p "${HOME}/.cache"
NVIM_LOG="${HOME}/.cache/nvim-setup.log"
bash "${SCRIPTS_DIR}/13-nvim-plugins.sh" >"${NVIM_LOG}" 2>&1 &
NVIM_SETUP_PID=$!
log "Neovim plugin pre-load running in background (PID: ${NVIM_SETUP_PID})"
log "Monitor progress : tail -f ${NVIM_LOG}"
log "Wait for it      : wait ${NVIM_SETUP_PID}"

log ""
log "Setup complete!"
log ""
log "To finish: open a new shell or run: exec zsh"
log "Neovim plugins are pre-loading in the background – check ~/.cache/nvim-setup.log"

# Print a verification summary so the user can confirm every tool landed.
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              SETUP VERIFICATION SUMMARY              ║"
echo "╚══════════════════════════════════════════════════════╝"

check_tool() {
  local label="$1"
  local bin="$2"
  shift 2
  local version_output
  if version_output="$("$bin" "$@" 2>/dev/null | head -1)"; then
    printf "  ✅  %-18s %s\n" "${label}" "${version_output}"
  else
    printf "  ❌  %-18s not found\n" "${label}"
  fi
}

check_tool "zsh"        zsh        --version
check_tool "node"       node       --version
check_tool "nvim"       nvim       --version
check_tool "eza"        eza        --version
check_tool "yazi"       yazi       --version
check_tool "lazygit"    lazygit    --version
check_tool "atuin"      atuin      --version
check_tool "uv"         uv         --version
check_tool "claude"     claude     --version

FONT_DIR="${HOME}/.local/share/fonts/MesloLGS-NF"
if [[ -f "${FONT_DIR}/MesloLGS NF Regular.ttf" ]]; then
  printf "  ✅  %-18s installed in %s\n" "MesloLGS NF" "${FONT_DIR}"
else
  printf "  ❌  %-18s not found\n" "MesloLGS NF"
fi

NVIM_LOG="${NVIM_LOG:-${HOME}/.cache/nvim-setup.log}"

echo ""
echo "  Shell config : ${HOME}/.zshrc"
echo "  Aliases      : ${HOME}/.zsh_aliases"
echo "  Git config   : ${HOME}/.gitconfig"
echo "  Nvim plugins : tail -f ${NVIM_LOG}"
echo ""
