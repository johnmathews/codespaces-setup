#!/usr/bin/env bash
# Install the GitHub CLI (gh) from the official release tarball into /opt and
# symlink into /usr/local/bin.
#
# Why the tarball and not the cli.github.com apt repo:
#   Same reasoning as 02-nodejs.sh — behind a TLS-intercepting proxy, adding a
#   third-party apt source is fragile (key fetch / repo refresh can silently
#   fail). A plain HTTPS tarball download works via the system CA and matches
#   how eza/yazi/lazygit are installed here.
#
# Auth note: Codespaces auto-injects a restricted GITHUB_TOKEN that gh prefers
# over stored credentials, so `gh auth login` refuses to save your own token
# until it is cleared. configs/.zshrc unsets GITHUB_TOKEN/GH_TOKEN for
# interactive shells so you can run `gh auth login` and push as yourself.

set -euo pipefail

log() { echo "[gh] $*"; }

GH_VERSION="v2.95.0"
GH_VERSION_BARE="${GH_VERSION#v}"
INSTALL_DIR="/opt"
BIN_DIR="/usr/local/bin"

if command -v gh &>/dev/null; then
  CURRENT="$(gh --version 2>/dev/null | grep -oP 'gh version \K[0-9.]+' || true)"
  if [[ "${CURRENT}" == "${GH_VERSION_BARE}" ]]; then
    log "gh ${GH_VERSION} already installed, skipping."
    exit 0
  fi
  log "Found gh ${CURRENT:-unknown}, installing ${GH_VERSION_BARE}..."
fi

# Detect architecture
ARCH="$(uname -m)"
case "${ARCH}" in
  aarch64 | arm64) GH_ARCH="arm64" ;;
  *) GH_ARCH="amd64" ;;
esac

ASSET="gh_${GH_VERSION_BARE}_linux_${GH_ARCH}"
TARBALL="/tmp/${ASSET}.tar.gz"
URL="https://github.com/cli/cli/releases/download/${GH_VERSION}/${ASSET}.tar.gz"
GH_DIR="${INSTALL_DIR}/${ASSET}"

log "Downloading gh ${GH_VERSION} (${GH_ARCH})..."
curl -fsSL "${URL}" -o "${TARBALL}"

log "Extracting to ${GH_DIR}..."
sudo rm -rf "${GH_DIR}"
sudo mkdir -p "${GH_DIR}"
# Tarball contains a single gh_<version>_linux_<arch>/ top dir (bin/, share/).
sudo tar -xzf "${TARBALL}" -C "${GH_DIR}" --strip-components=1

log "Creating symlink ${BIN_DIR}/gh..."
sudo ln -sf "${GH_DIR}/bin/gh" "${BIN_DIR}/gh"

rm -f "${TARBALL}"
log "Installed: $(gh --version | head -1)"
