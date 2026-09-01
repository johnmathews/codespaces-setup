#!/usr/bin/env bash
# Install eza (modern ls replacement) from prebuilt binary.
# Matches shell_environment role: eza_version = v0.20.14.

set -euo pipefail

log() { echo "[eza] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

EZA_VERSION="v0.20.14"
INSTALL_DIR="/opt"
BIN_DIR="/usr/local/bin"
EZA_DIR="${INSTALL_DIR}/eza-${EZA_VERSION}"

# Guard on the binary RUNNING, not merely existing. A dropped transfer used to
# leave a truncated, executable eza at this exact path; `[[ -x ]]` then reported
# it installed on every later run, so re-running setup.sh — the documented
# remedy — never repaired it.
if installed_version_is "${EZA_DIR}/eza" "${EZA_VERSION}"; then
  log "eza ${EZA_VERSION} already installed, skipping."
  sudo ln -sf "${EZA_DIR}/eza" "${BIN_DIR}/eza"
  exit 0
fi
if [[ -e "${EZA_DIR}/eza" ]]; then
  log "Found a broken or wrong eza at ${EZA_DIR}/eza (${INSTALLED_VERSION:-does not run}); reinstalling ${EZA_VERSION}..."
fi

# Detect architecture
ARCH="$(uname -m)"
if [[ "${ARCH}" == "aarch64" ]]; then
  EZA_ARCH="aarch64-unknown-linux-gnu"
else
  EZA_ARCH="x86_64-unknown-linux-gnu"
fi

URL="https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_${EZA_ARCH}.tar.gz"

# Stage in a private temp dir: nothing unverified may reach the install path.
# Extraction is deliberately UNPRIVILEGED so the trap can clean up; only the
# final install and symlink need sudo.
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

log "Downloading eza ${EZA_VERSION}..."
fetch_verified "${URL}" "${TMP}/eza.tar.gz"

log "Extracting..."
tar -xzf "${TMP}/eza.tar.gz" -C "${TMP}"
if [[ ! -x "${TMP}/eza" ]]; then
  log "ERROR: eza binary not found in the downloaded archive."
  exit 1
fi
if ! "${TMP}/eza" --version >/dev/null 2>&1; then
  log "ERROR: the downloaded eza binary does not run; refusing to install it."
  exit 1
fi

log "Installing to ${EZA_DIR}/eza..."
sudo mkdir -p "${EZA_DIR}"
sudo install -m 755 "${TMP}/eza" "${EZA_DIR}/eza"

log "Creating symlink ${BIN_DIR}/eza..."
sudo ln -sf "${EZA_DIR}/eza" "${BIN_DIR}/eza"

log "Installed: $(eza --version | head -1)"
