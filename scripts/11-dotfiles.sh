#!/usr/bin/env bash
# Deploy dotfiles: .zshrc, .zsh_aliases, .gitconfig_managed, and p10k config.
# Source files live in the configs/ directory of this repo.
# Each file is only written when it differs from what's on disk (idempotent).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGS_DIR="${REPO_DIR}/configs"

log() { echo "[dotfiles] $*"; }

deploy() {
  local src="$1"
  local dest="$2"
  if [[ ! -f "${src}" ]]; then
    log "WARNING: source not found: ${src}, skipping."
    return
  fi
  if [[ -f "${dest}" ]] && diff -q "${src}" "${dest}" &>/dev/null; then
    log "${dest}: already up-to-date."
    return
  fi
  if [[ -f "${dest}" ]]; then
    log "${dest}: updating (backup at ${dest}.bak)..."
    cp "${dest}" "${dest}.bak"
  else
    log "${dest}: deploying..."
  fi
  cp "${src}" "${dest}"
}

deploy "${CONFIGS_DIR}/.zshrc"             "${HOME}/.zshrc"
deploy "${CONFIGS_DIR}/.zsh_aliases"       "${HOME}/.zsh_aliases"
deploy "${CONFIGS_DIR}/.gitconfig_managed" "${HOME}/.gitconfig_managed"

# Include managed git config from ~/.gitconfig
GITCONFIG="${HOME}/.gitconfig"
# Make sure every location `git config --global` might write to actually exists,
# so configuring git can't fail with "could not lock config file ... No such
# file or directory" on a fresh/unusual Codespace home.
mkdir -p "$(dirname "${GITCONFIG}")"
mkdir -p "${HOME}/.config/git"
[[ -n "${XDG_CONFIG_HOME:-}" ]] && mkdir -p "${XDG_CONFIG_HOME}/git"
touch "${GITCONFIG}"
MARKER_START="# BEGIN codespaces-setup git include"
MARKER_END="# END codespaces-setup git include"
GIT_USER_NAME="John Mathews"
GIT_USER_EMAIL="john.mathews@simmons-simmons.com"

if ! grep -qF "${MARKER_START}" "${GITCONFIG}" 2>/dev/null; then
  log "Adding git include to ${GITCONFIG}..."
  cat >>"${GITCONFIG}"  <<EOF

${MARKER_START}
[include]
	path = ~/.gitconfig_managed
${MARKER_END}
EOF
else
  log "${GITCONFIG}: git include already present."
fi

set_git_config() {
  local key="$1"
  local value="$2"
  local current_value
  current_value="$(git config --global --get "${key}" || true)"

  if [[ "${current_value}" == "${value}" ]]; then
    log "git ${key}: already set to ${value}."
    return
  fi

  git config --global "${key}" "${value}"
  log "git ${key}: set to ${value}."
}

set_git_config "user.name" "${GIT_USER_NAME}"
set_git_config "user.email" "${GIT_USER_EMAIL}"

# Change default shell to zsh if it is currently something else
ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="$(getent passwd "$(whoami)" | cut -d: -f7)"
if [[ "${CURRENT_SHELL}" != "${ZSH_PATH}" ]]; then
  log "Changing default shell to zsh (${ZSH_PATH})..."
  sudo chsh -s "${ZSH_PATH}" "$(whoami)"
else
  log "Default shell is already zsh."
fi

log "Dotfiles deployed."

# Ensure bash terminals hand off to zsh automatically for interactive sessions.
# This avoids requiring a manual `exec zsh` in each new terminal.
BASHRC="${HOME}/.bashrc"
BASH_MARKER_START="# BEGIN codespaces-setup zsh handoff"
BASH_MARKER_END="# END codespaces-setup zsh handoff"

if ! grep -qF "${BASH_MARKER_START}" "${BASHRC}" 2>/dev/null; then
  log "Adding zsh handoff block to ${BASHRC}..."
  cat >>"${BASHRC}"  <<EOF

${BASH_MARKER_START}
if [[ -n "\${BASH_VERSION:-}" && -z "\${ZSH_VERSION:-}" && \$- == *i* ]] && command -v zsh >/dev/null 2>&1; then
  exec zsh -l
fi
${BASH_MARKER_END}
EOF
else
  log "${BASHRC}: zsh handoff block already present."
fi
