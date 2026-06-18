#!/usr/bin/env bash
# Install eza (modern ls replacement) from prebuilt binary.
# Matches shell_environment role: eza_version = v0.20.14.

set -euo pipefail

log() { echo "[eza] $*"; }

EZA_VERSION="v0.20.14"
INSTALL_DIR="/opt"
BIN_DIR="/usr/local/bin"
EZA_DIR="${INSTALL_DIR}/eza-${EZA_VERSION}"

if [[ -x "${EZA_DIR}/eza" ]]; then
  log "eza ${EZA_VERSION} already installed, skipping."
  sudo ln -sf "${EZA_DIR}/eza" "${BIN_DIR}/eza"
  exit 0
fi

# Detect architecture
ARCH="$(uname -m)"
if [[ "${ARCH}" == "aarch64" ]]; then
  EZA_ARCH="aarch64-unknown-linux-gnu"
else
  EZA_ARCH="x86_64-unknown-linux-gnu"
fi

TARBALL="/tmp/eza-${EZA_VERSION}.tar.gz"
URL="https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_${EZA_ARCH}.tar.gz"

log "Downloading eza ${EZA_VERSION}..."
curl -fsSL "${URL}" -o "${TARBALL}"

log "Extracting..."
sudo mkdir -p "${EZA_DIR}"
sudo tar -xzf "${TARBALL}" -C "${EZA_DIR}"

log "Creating symlink ${BIN_DIR}/eza..."
sudo ln -sf "${EZA_DIR}/eza" "${BIN_DIR}/eza"

rm -f "${TARBALL}"
log "Installed: $(eza --version | head -1)"
