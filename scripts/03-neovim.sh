#!/usr/bin/env bash
# Install Neovim from AppImage.
# Matches shell_environment role: neovim_version = v0.11.5.

set -euo pipefail

log() { echo "[neovim] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NVIM_VERSION="v0.11.5"
INSTALL_DIR="/opt"
BIN_DIR="/usr/local/bin"
NVIM_DIR="${INSTALL_DIR}/nvim-${NVIM_VERSION}"
NVIM_BIN="${NVIM_DIR}/usr/bin/nvim"

# Guard on the binary RUNNING, not merely existing — see scripts/lib.sh. The
# symlink re-creation is load-bearing: it repairs /usr/local/bin/nvim when a
# later step clobbered it.
if installed_version_is "${NVIM_BIN}" "${NVIM_VERSION}"; then
  log "Neovim ${NVIM_VERSION} already installed at ${NVIM_BIN}, skipping."
  sudo ln -sf "${NVIM_BIN}" "${BIN_DIR}/nvim"
  exit 0
fi
if [[ -e "${NVIM_BIN}" ]]; then
  log "Found a broken or wrong Neovim at ${NVIM_BIN} (${INSTALLED_VERSION:-does not run}); reinstalling ${NVIM_VERSION}..."
fi

# Detect architecture
ARCH="$(uname -m)"
if [[ "${ARCH}" == "aarch64" ]]; then
  NVIM_ARCH="arm64"
else
  NVIM_ARCH="${ARCH}"
fi

APPIMAGE_URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${NVIM_ARCH}.appimage"
# A private staging dir, not a fixed /tmp path: a file left there by another
# user would make `curl -o` fail outright.
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
APPIMAGE_TMP="${TMP}/nvim.appimage"

log "Removing old apt neovim (if any)..."
sudo apt-get remove -y neovim 2>/dev/null || true

log "Downloading Neovim ${NVIM_VERSION} (${NVIM_ARCH})..."
# An AppImage is neither tar.gz nor zip, so fetch_verified only asserts
# non-empty here; the extraction below is the real completeness check.
fetch_verified "${APPIMAGE_URL}" "${APPIMAGE_TMP}"
chmod +x "${APPIMAGE_TMP}"

log "Extracting AppImage..."
# Extract into a version-specific tmp dir to avoid /tmp/squashfs-root conflicts
EXTRACT_TMP="${TMP}/extract"
mkdir -p "${EXTRACT_TMP}"
cd "${EXTRACT_TMP}"
"${APPIMAGE_TMP}" --appimage-extract >/dev/null 2>&1

if [[ ! -d "${EXTRACT_TMP}/squashfs-root" ]]; then
  echo "[neovim] ERROR: AppImage extraction failed – squashfs-root not found in ${EXTRACT_TMP}" >&2
  exit 1
fi

# Prove the extracted binary runs before it replaces a working install. The
# mv below crosses filesystems (/tmp -> /opt) so it is a copy, not an atomic
# rename; the functional guard above is what makes a half-copy survivable.
if ! "${EXTRACT_TMP}/squashfs-root/usr/bin/nvim" --version >/dev/null 2>&1; then
  log "ERROR: the extracted nvim does not run; refusing to install it."
  exit 1
fi

log "Moving to ${NVIM_DIR}..."
sudo rm -rf "${NVIM_DIR}"
sudo mv "${EXTRACT_TMP}/squashfs-root" "${NVIM_DIR}"

log "Creating symlink ${BIN_DIR}/nvim..."
sudo ln -sf "${NVIM_BIN}" "${BIN_DIR}/nvim"

log "Installed: $(nvim --version | head -1)"
