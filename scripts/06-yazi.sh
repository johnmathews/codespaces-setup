#!/usr/bin/env bash
# Install yazi (terminal file manager) from prebuilt binary.
# Matches shell_environment role: yazi_version = v0.4.2.

set -euo pipefail

log() { echo "[yazi] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

YAZI_VERSION="v0.4.2"
INSTALL_DIR="/opt"
BIN_DIR="/usr/local/bin"
YAZI_DIR="${INSTALL_DIR}/yazi-${YAZI_VERSION}"

# Guard on the binary RUNNING, not merely existing — see scripts/lib.sh. `ya` is
# checked too, since both are symlinked below and a partial extract can leave one
# without the other. `ya` is the non-TUI companion, so it is the safer of the two
# to interrogate for a version.
if installed_version_is "${YAZI_DIR}/ya" "${YAZI_VERSION}" && [[ -x "${YAZI_DIR}/yazi" ]]; then
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

# Stage the zip in a private temp dir. The UNZIP target deliberately stays in
# ${INSTALL_DIR} so the `mv` below is a same-filesystem rename and therefore
# atomic; staging the extract in /tmp would silently turn it into a
# cross-filesystem copy.
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
ZIP="${TMP}/yazi.zip"
URL="https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${YAZI_ARCH}.zip"

log "Installing image preview dependency (chafa)..."
retry sudo apt-get -o DPkg::Lock::Timeout=300 install -y -q chafa 2>/dev/null || true

log "Downloading yazi ${YAZI_VERSION}..."
fetch_verified "${URL}" "${ZIP}"

log "Extracting..."
# Clear any leftovers from a previous partial run: a stale extract dir would make
# `mv` nest inside it, and a stale ${YAZI_DIR} would make `mv` nest there instead
# of replacing it. Matches the rm-before-install pattern in 03-neovim/16-gh.
sudo rm -rf "${INSTALL_DIR}/yazi-${YAZI_ARCH}" "${YAZI_DIR}"
sudo unzip -q "${ZIP}" -d "${INSTALL_DIR}/"
if ! sudo "${INSTALL_DIR}/yazi-${YAZI_ARCH}/ya" --version >/dev/null 2>&1; then
  log "ERROR: the extracted yazi does not run; refusing to install it."
  exit 1
fi
sudo mv "${INSTALL_DIR}/yazi-${YAZI_ARCH}" "${YAZI_DIR}"

log "Creating symlinks..."
sudo ln -sf "${YAZI_DIR}/yazi" "${BIN_DIR}/yazi"
sudo ln -sf "${YAZI_DIR}/ya" "${BIN_DIR}/ya"

log "Creating default yazi config..."
mkdir -p "${HOME}/.config/yazi"

log "Installed: $(yazi --version 2>&1 | head -1)"
