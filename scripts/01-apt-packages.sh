#!/usr/bin/env bash
# Install apt packages and CLI tools.
# Matches shell_environment role: cli_tools list.

set -euo pipefail

log() { echo "[apt-packages] $*"; }

PACKAGES=(
  git
  curl
  wget
  unzip
  build-essential
  cmake
  python3-pip
  python3-venv
  htop
  jq
  fd-find
  ripgrep
  fzf
  zoxide
  tree
  bat
  tmux
  rsync
  imagemagick
  ffmpeg
  p7zip-full
  poppler-utils
  sqlite3
  acl
  zsh
  tig
)

log "Updating apt cache..."
# Don't let a single broken third-party repo (e.g. an expired yarn/deadsnakes
# GPG key) abort the whole setup. The packages we need come from the Debian/
# Ubuntu main repos, which still update fine, so a partial failure here is OK.
if ! sudo apt-get update -q; then
  log "WARNING: 'apt-get update' reported errors (often a broken third-party repo)."
  log "Continuing — required packages come from the main repos."
fi

log "Installing packages: ${PACKAGES[*]}"
sudo apt-get install -y -q "${PACKAGES[@]}"

log "Done."
