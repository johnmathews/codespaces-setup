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

# Change default shell to zsh if it is currently something else.
#
# Guarded, and deliberately non-fatal. Two things bite here:
#
#  1. `ZSH_PATH="$(command -v zsh)"` was unguarded under `set -e`, so on a
#     machine without zsh this line ALONE failed the whole step — after the
#     .zshrc had already been deployed above.
#  2. This step runs 2nd while 10-zsh-setup.sh (oh-my-zsh) runs 12th. Since a
#     non-required failure no longer aborts the run, switching the login shell
#     here can hand the user a zsh whose config is not fully installed. The
#     .zshrc now guards its oh-my-zsh source for exactly this reason, so the
#     shell degrades rather than erroring — but there is no reason to make the
#     switch fatal either.
ZSH_PATH="$(command -v zsh || true)"
if [[ -z "${ZSH_PATH}" ]]; then
  log "WARNING: zsh not found; leaving the default shell unchanged."
  log "         01-apt-packages.sh installs it — check whether that step failed."
else
  CURRENT_SHELL="$(getent passwd "$(whoami)" 2>/dev/null | cut -d: -f7 || true)"
  if [[ "${CURRENT_SHELL}" != "${ZSH_PATH}" ]]; then
    log "Changing default shell to zsh (${ZSH_PATH})..."
    if sudo chsh -s "${ZSH_PATH}" "$(whoami)"; then
      log "Default shell changed to zsh."
    else
      # Not fatal: the bash->zsh handoff block below still gets the user into
      # zsh for interactive shells, so a PAM-refused chsh degrades rather than
      # failing a step that has already done its real work.
      log "WARNING: 'chsh' failed; relying on the ~/.bashrc handoff instead."
    fi
  else
    log "Default shell is already zsh."
  fi
fi

# Put setup-status on PATH. It is the answer to "what happened during setup?"
# from inside the VM, and it must be reachable without knowing any file paths —
# which was the whole problem it exists to fix. Deployed here rather than as its
# own step because it is a dotfile-shaped concern and this step already runs
# second, so the command is available even when later steps fail.
STATUS_SRC="${REPO_DIR}/bin/setup-status"
if [[ -f "${STATUS_SRC}" ]]; then
  if sudo install -m 755 "${STATUS_SRC}" /usr/local/bin/setup-status 2>/dev/null; then
    log "Installed setup-status to /usr/local/bin/setup-status."
  else
    # No sudo (or a read-only /usr/local): fall back to ~/.local/bin, which
    # configs/.zshrc already puts on PATH.
    mkdir -p "${HOME}/.local/bin"
    install -m 755 "${STATUS_SRC}" "${HOME}/.local/bin/setup-status"
    log "Installed setup-status to ${HOME}/.local/bin/setup-status."
  fi
else
  log "WARNING: ${STATUS_SRC} not found; setup-status not installed."
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
# Surface an incomplete setup here too, BEFORE handing off to zsh. The notice in
# .zshrc was the signal's only reader in the whole repo, which meant it was
# invisible in bash, over 'gh cs ssh', and — worst — on exactly the machines
# where the dotfiles or zsh step is what failed, since then no zsh handoff
# happens and that .zshrc may never be sourced at all.
if [[ -n "\${BASH_VERSION:-}" && \$- == *i* && -f ~/.cache/codespaces-setup.failed ]]; then
  printf '\\033[31m\\033[1m⚠️  Codespaces setup did not finish cleanly:\\033[0m\\n'
  cat ~/.cache/codespaces-setup.failed
  command -v setup-status >/dev/null 2>&1 && printf "Run 'setup-status' for per-step detail.\\n"
fi
if [[ -n "\${BASH_VERSION:-}" && -z "\${ZSH_VERSION:-}" && \$- == *i* ]] && command -v zsh >/dev/null 2>&1; then
  exec zsh -l
fi
${BASH_MARKER_END}
EOF
else
  log "${BASHRC}: zsh handoff block already present."
fi
