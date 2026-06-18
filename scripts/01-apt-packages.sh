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
)

log "Updating apt cache..."
sudo apt-get update -q

log "Installing packages: ${PACKAGES[*]}"
sudo apt-get install -y -q "${PACKAGES[@]}"

log "Done."
