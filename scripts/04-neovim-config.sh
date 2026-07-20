#!/usr/bin/env bash
# Clone the neovim configuration from johnmathews/neovim into ~/.config/nvim.
# If the directory already exists it is reset to match the latest upstream commit.
#
# Why a hard reset instead of `git pull --rebase`: this is a *managed* clone of
# an upstream config repo, and running Neovim writes into the tree (e.g. plugin
# managers rewrite lazy-lock.json), so after a few weeks the checkout drifts with
# uncommitted/untracked changes. A rebase then aborts with "cannot pull with
# rebase: You have unstaged changes", breaking idempotency. We treat upstream as
# the source of truth and discard local drift so re-running always converges.

set -euo pipefail

log() { echo "[neovim-config] $*"; }

NVIM_CONFIG_DIR="${HOME}/.config/nvim"
NVIM_REPO="https://github.com/johnmathews/neovim.git"

if [[ -d "${NVIM_CONFIG_DIR}/.git" ]]; then
  log "Neovim config already cloned, resetting to latest upstream..."
  git -C "${NVIM_CONFIG_DIR}" fetch origin
  # Make sure origin/HEAD points at the remote's default branch (it may be unset
  # in older clones), then resolve which branch that is. Fall back to the current
  # branch, then main, so we reset to whatever the repo's default branch is.
  git -C "${NVIM_CONFIG_DIR}" remote set-head origin --auto >/dev/null 2>&1 || true
  remote_branch="$(git -C "${NVIM_CONFIG_DIR}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  remote_branch="${remote_branch#origin/}"
  if [[ -z "${remote_branch}" ]]; then
    remote_branch="$(git -C "${NVIM_CONFIG_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi
  [[ -z "${remote_branch}" || "${remote_branch}" == "HEAD" ]] && remote_branch="main"
  log "Resetting to origin/${remote_branch} (discarding any local drift)..."
  git -C "${NVIM_CONFIG_DIR}" checkout -f "${remote_branch}"
  git -C "${NVIM_CONFIG_DIR}" reset --hard "origin/${remote_branch}"
  git -C "${NVIM_CONFIG_DIR}" clean -fd
else
  if [[ -d "${NVIM_CONFIG_DIR}" ]]; then
    log "Backing up existing config to ${NVIM_CONFIG_DIR}.bak..."
    mv "${NVIM_CONFIG_DIR}" "${NVIM_CONFIG_DIR}.bak"
  fi
  log "Cloning ${NVIM_REPO} to ${NVIM_CONFIG_DIR}..."
  git clone "${NVIM_REPO}" "${NVIM_CONFIG_DIR}"
fi

log "Neovim config ready at ${NVIM_CONFIG_DIR}"

# Ensure the sqlite-backed Telescope history directory exists.
#
# The neovim config points telescope-smart-history at
# ~/.local/share/nvim/databases/telescope_history.sqlite3. sqlite.lua opens that
# DB with sqlite3_open_v2 in "rwc" mode, which creates the *file* but not its
# parent directory, so a missing directory surfaces as
# "sqlite.lua: couldn't connect to sql database, ERR: unable to open database"
# the first time a picker cycles its history. Create it here (a synchronous
# foreground step) so it always exists before nvim is opened, rather than
# relying on the background 13-nvim-plugins.sh preload having run first.
NVIM_DB_DIR="${HOME}/.local/share/nvim/databases"
mkdir -p "${NVIM_DB_DIR}"
log "Ensured Neovim sqlite database directory exists: ${NVIM_DB_DIR}"
