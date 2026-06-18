#!/usr/bin/env bash
# Install yazi (terminal file manager) from prebuilt binary.
# Matches shell_environment role: yazi_version = v0.4.2.

set -euo pipefail

log() { echo "[yazi] $*"; }

YAZI_VERSION="v0.4.2"
INSTALL_DIR="/opt"
BIN_DIR="/usr/local/bin"
YAZI_DIR="${INSTALL_DIR}/yazi-${YAZI_VERSION}"

if [[ -x "${YAZI_DIR}/yazi" ]]; then
  log "yazi ${YAZI_VERSION} already installed, skipping."
  sudo ln -sf "${YAZI_DIR}/yazi" "${BIN_DIR}/yazi"
  sudo ln -sf "${YAZI_DIR}/ya" "${BIN_DIR}/ya"
  exit 0
fi

# Detect architecture
ARCH="$(uname -m)"
if [[ "${ARCH}" == "aarch64" ]]; then
  YAZI_ARCH="aarch64-unknown-linux-gnu"
else
  YAZI_ARCH="x86_64-unknown-linux-gnu"
fi

ZIP="/tmp/yazi-${YAZI_VERSION}.zip"
URL="https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${YAZI_ARCH}.zip"

log "Installing image preview dependency (chafa)..."
sudo apt-get install -y -q chafa 2>/dev/null || true

log "Downloading yazi ${YAZI_VERSION}..."
curl -fsSL "${URL}" -o "${ZIP}"

log "Extracting..."
sudo unzip -q "${ZIP}" -d "${INSTALL_DIR}/"
sudo mv "${INSTALL_DIR}/yazi-${YAZI_ARCH}" "${YAZI_DIR}"

log "Creating symlinks..."
sudo ln -sf "${YAZI_DIR}/yazi" "${BIN_DIR}/yazi"
sudo ln -sf "${YAZI_DIR}/ya" "${BIN_DIR}/ya"

log "Creating default yazi config..."
mkdir -p "${HOME}/.config/yazi"

rm -f "${ZIP}"
log "Installed: $(yazi --version 2>&1 | head -1)"
