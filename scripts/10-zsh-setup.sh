#!/usr/bin/env bash
# Install Zsh, Oh My Zsh, third-party plugins, and Powerlevel10k.
# Matches shell_environment role: omz_enabled, p10k_enabled, omz_plugins.

set -euo pipefail

log() { echo "[zsh-setup] $*"; }

OMZ_DIR="${HOME}/.oh-my-zsh"
OMZ_CUSTOM="${OMZ_DIR}/custom"
ZSH_PLUGINS_DIR="${OMZ_CUSTOM}/plugins"
ZSH_THEMES_DIR="${OMZ_CUSTOM}/themes"

# Zsh is already installed by 01-apt-packages.sh
log "Zsh version: $(zsh --version)"

# Install Oh My Zsh (unattended, skip shell change - handled by 11-dotfiles.sh)
if [[ ! -d "${OMZ_DIR}" ]]; then
  log "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  log "Oh My Zsh already installed, skipping."
fi

# Install third-party plugins
install_plugin() {
  local name="$1"
  local repo="$2"
  local dest="${ZSH_PLUGINS_DIR}/${name}"
  if [[ -d "${dest}/.git" ]]; then
    log "Plugin ${name}: updating..."
    git -C "${dest}" pull --ff-only -q
  else
    log "Plugin ${name}: cloning..."
    git clone --depth=1 "${repo}" "${dest}"
  fi
}

mkdir -p "${ZSH_PLUGINS_DIR}"

install_plugin "zsh-autosuggestions" \
  "https://github.com/zsh-users/zsh-autosuggestions.git"

install_plugin "zsh-syntax-highlighting" \
  "https://github.com/zsh-users/zsh-syntax-highlighting.git"

# Install Powerlevel10k theme
P10K_DIR="${ZSH_THEMES_DIR}/powerlevel10k"
if [[ -d "${P10K_DIR}/.git" ]]; then
  log "Powerlevel10k: updating..."
  git -C "${P10K_DIR}" pull --ff-only -q
else
  log "Powerlevel10k: cloning..."
  mkdir -p "${ZSH_THEMES_DIR}"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${P10K_DIR}"
fi

# Deploy Powerlevel10k lean preset as ~/.p10k.zsh if not already present
P10K_PRESET="${P10K_DIR}/config/p10k-lean.zsh"
P10K_CONFIG="${HOME}/.p10k.zsh"
if [[ ! -f "${P10K_CONFIG}" ]]; then
  if [[ -f "${P10K_PRESET}" ]]; then
    log "Copying lean p10k preset to ${P10K_CONFIG}..."
    cp "${P10K_PRESET}" "${P10K_CONFIG}"
  else
    log "WARNING: lean preset not found at ${P10K_PRESET}, skipping .p10k.zsh deploy."
  fi
else
  log "${P10K_CONFIG}: already exists, skipping."
fi

log "Zsh setup complete."
