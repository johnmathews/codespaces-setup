#!/usr/bin/env bash
# Install Zsh, Oh My Zsh, third-party plugins, and Powerlevel10k.
# Matches shell_environment role: omz_enabled, p10k_enabled, omz_plugins.

set -euo pipefail

log() { echo "[zsh-setup] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OMZ_DIR="${HOME}/.oh-my-zsh"
OMZ_CUSTOM="${OMZ_DIR}/custom"
ZSH_PLUGINS_DIR="${OMZ_CUSTOM}/plugins"
ZSH_THEMES_DIR="${OMZ_CUSTOM}/themes"

# Zsh is already installed by 01-apt-packages.sh
log "Zsh version: $(zsh --version)"

# "Installed" means the file zsh actually sources exists, not that the directory
# does. A killed installer leaves ~/.oh-my-zsh behind, and a directory test then
# reports it installed forever — while configs/.zshrc:31 sources
# ${OMZ_DIR}/oh-my-zsh.sh and errors on every shell start.
omz_installed() {
  [[ -r "${OMZ_DIR}/oh-my-zsh.sh" && -d "${OMZ_DIR}/lib" && -d "${OMZ_DIR}/plugins" ]]
}

# Install Oh My Zsh (unattended, skip shell change - handled by 11-dotfiles.sh)
if omz_installed; then
  log "Oh My Zsh already installed, skipping."
else
  if [[ -d "${OMZ_DIR}" ]]; then
    # The upstream installer refuses to run into an existing directory, so an
    # incomplete one has to go or every future run fails here. custom/plugins and
    # custom/themes are re-cloned further down this same script.
    log "Found an incomplete ${OMZ_DIR} (no oh-my-zsh.sh); removing it and reinstalling..."
    rm -rf "${OMZ_DIR}"
  fi
  log "Installing Oh My Zsh..."
  # Download the installer to a file first (retryable) rather than piping curl
  # into sh, then run it with the same unattended flags.
  OMZ_INSTALLER="$(mktemp)"
  trap 'rm -f "${OMZ_INSTALLER}"' EXIT
  retry net_curl https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "${OMZ_INSTALLER}"
  if ! bash -n "${OMZ_INSTALLER}"; then
    log "ERROR: the downloaded Oh My Zsh installer is not valid shell (truncated download?)."
    exit 1
  fi
  # Retry the installer: it git-clones the whole oh-my-zsh repo internally, which
  # is the slow hop, and the retried curl above only covered the wrapper script.
  # bash rather than sh for every vendor installer — see 08-atuin.sh.
  RUNZSH=no CHSH=no retry bash "${OMZ_INSTALLER}" "" --unattended
  if ! omz_installed; then
    log "ERROR: the Oh My Zsh installer did not produce ${OMZ_DIR}/oh-my-zsh.sh."
    exit 1
  fi
fi

# Install third-party plugins
install_plugin() {
  local name="$1"
  local repo="$2"
  local dest="${ZSH_PLUGINS_DIR}/${name}"
  if [[ -d "${dest}/.git" ]]; then
    log "Plugin ${name}: updating..."
    if ! retry git -C "${dest}" pull --ff-only -q; then
      log "ERROR: failed to fast-forward plugin ${name} in ${dest}."
      log "       It has local commits or has diverged from upstream."
      log "       Re-clone it:  rm -rf ${dest} && bash scripts/10-zsh-setup.sh"
      exit 1
    fi
  else
    log "Plugin ${name}: cloning..."
    retry git clone --depth=1 "${repo}" "${dest}"
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
  if ! retry git -C "${P10K_DIR}" pull --ff-only -q; then
    log "ERROR: failed to fast-forward Powerlevel10k in ${P10K_DIR}."
    log "       It has local commits or has diverged from upstream."
    log "       Re-clone it:  rm -rf ${P10K_DIR} && bash scripts/10-zsh-setup.sh"
    exit 1
  fi
else
  log "Powerlevel10k: cloning..."
  mkdir -p "${ZSH_THEMES_DIR}"
  retry git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${P10K_DIR}"
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
