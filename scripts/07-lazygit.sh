#!/usr/bin/env bash
# Install lazygit from prebuilt binary.
# Matches shell_environment role: lazygit_version = v0.60.0.

set -euo pipefail

log() { echo "[lazygit] $*"; }

LAZYGIT_VERSION="v0.60.0"
LAZYGIT_VERSION_BARE="${LAZYGIT_VERSION#v}"
BIN_DIR="/usr/local/bin"

if command -v lazygit &>/dev/null; then
  CURRENT="$(lazygit --version 2>/dev/null | grep -oP 'version=\K[^,]+' || true)"
  if [[ "${CURRENT}" == "${LAZYGIT_VERSION_BARE}" ]]; then
    log "lazygit ${LAZYGIT_VERSION} already installed, skipping."
    exit 0
  fi
  log "Found lazygit ${CURRENT}, upgrading to ${LAZYGIT_VERSION_BARE}..."
fi

# Detect architecture
ARCH="$(uname -m)"
if [[ "${ARCH}" == "aarch64" ]]; then
  LAZYGIT_ARCH="arm64"
else
  LAZYGIT_ARCH="x86_64"
fi

TARBALL="/tmp/lazygit-${LAZYGIT_VERSION}.tar.gz"
URL="https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION_BARE}_linux_${LAZYGIT_ARCH}.tar.gz"

log "Downloading lazygit ${LAZYGIT_VERSION}..."
curl -fsSL "${URL}" -o "${TARBALL}"

EXTRACT_DIR="/tmp/lazygit-${LAZYGIT_VERSION}"
mkdir -p "${EXTRACT_DIR}"
tar -xzf "${TARBALL}" -C "${EXTRACT_DIR}"

log "Installing to ${BIN_DIR}/lazygit..."
sudo install -m 755 "${EXTRACT_DIR}/lazygit" "${BIN_DIR}/lazygit"

rm -rf "${TARBALL}" "${EXTRACT_DIR}"
log "Installed: $(lazygit --version | head -1)"
