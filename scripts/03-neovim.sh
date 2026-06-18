#!/usr/bin/env bash
# Install Neovim from AppImage.
# Matches shell_environment role: neovim_version = v0.11.5.

set -euo pipefail

log() { echo "[neovim] $*"; }

NVIM_VERSION="v0.11.5"
INSTALL_DIR="/opt"
BIN_DIR="/usr/local/bin"
NVIM_DIR="${INSTALL_DIR}/nvim-${NVIM_VERSION}"
NVIM_BIN="${NVIM_DIR}/usr/bin/nvim"

if [[ -x "${NVIM_BIN}" ]]; then
  log "Neovim ${NVIM_VERSION} already installed at ${NVIM_BIN}, skipping."
  sudo ln -sf "${NVIM_BIN}" "${BIN_DIR}/nvim"
  exit 0
fi

# Detect architecture
ARCH="$(uname -m)"
if [[ "${ARCH}" == "aarch64" ]]; then
  NVIM_ARCH="arm64"
else
  NVIM_ARCH="${ARCH}"
fi

APPIMAGE_URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${NVIM_ARCH}.appimage"
APPIMAGE_TMP="/tmp/nvim-${NVIM_VERSION}.appimage"

log "Removing old apt neovim (if any)..."
sudo apt-get remove -y neovim 2>/dev/null || true

log "Downloading Neovim ${NVIM_VERSION} (${NVIM_ARCH})..."
curl -fsSL "${APPIMAGE_URL}" -o "${APPIMAGE_TMP}"
chmod +x "${APPIMAGE_TMP}"

log "Extracting AppImage..."
# Extract into a version-specific tmp dir to avoid /tmp/squashfs-root conflicts
EXTRACT_TMP="/tmp/nvim-extract-${NVIM_VERSION}-$$"
mkdir -p "${EXTRACT_TMP}"
cd "${EXTRACT_TMP}"
"${APPIMAGE_TMP}" --appimage-extract >/dev/null 2>&1

if [[ ! -d "${EXTRACT_TMP}/squashfs-root" ]]; then
  echo "[neovim] ERROR: AppImage extraction failed – squashfs-root not found in ${EXTRACT_TMP}" >&2
  exit 1
fi

log "Moving to ${NVIM_DIR}..."
sudo rm -rf "${NVIM_DIR}"
sudo mv "${EXTRACT_TMP}/squashfs-root" "${NVIM_DIR}"

log "Creating symlink ${BIN_DIR}/nvim..."
sudo ln -sf "${NVIM_BIN}" "${BIN_DIR}/nvim"

log "Cleaning up..."
rm -f "${APPIMAGE_TMP}"
rm -rf "${EXTRACT_TMP}"

log "Installed: $(nvim --version | head -1)"
