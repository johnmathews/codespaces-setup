#!/usr/bin/env bash
# Install the Azure CLI (az) via uv.
#
# uv is used (rather than pip or the Microsoft apt repo) for the same reasons
# other Python tools use it here: isolated environments avoid system-Python
# conflicts and the install works cleanly behind a TLS-intercepting proxy when
# SSL_CERT_FILE points at the system CA bundle.
#
# After installation the az shim (~/.local/bin/az) is symlinked into
# /usr/local/bin so it is available to all users and scripts regardless of
# whether ~/.local/bin is on PATH.

set -euo pipefail

log() { echo "[azure-cli] $*"; }

AZ_VERSION="2.68.0"
BIN_DIR="/usr/local/bin"

# Point uv at the system CA bundle so fetches succeed behind a
# TLS-intercepting proxy (the same approach used in 15-dev-tools.sh).
SYSTEM_CA="/etc/ssl/certs/ca-certificates.crt"
if [[ -f "${SYSTEM_CA}" ]]; then
  export SSL_CERT_FILE="${SYSTEM_CA}"
  export REQUESTS_CA_BUNDLE="${SYSTEM_CA}"
  log "Using system CA bundle: ${SYSTEM_CA}"
fi

if command -v az &>/dev/null; then
  CURRENT="$(az --version 2>/dev/null | grep -oP 'azure-cli\s+\K[0-9.]+' || true)"
  if [[ "${CURRENT}" == "${AZ_VERSION}" ]]; then
    log "azure-cli ${AZ_VERSION} already installed, skipping."
    exit 0
  fi
  log "Found azure-cli ${CURRENT:-unknown}, installing ${AZ_VERSION}..."
fi

if ! command -v uv &>/dev/null; then
  log "ERROR: uv not found; cannot install azure-cli."
  exit 1
fi

log "Installing azure-cli ${AZ_VERSION} via uv..."
uv tool install "azure-cli==${AZ_VERSION}"

AZ_SHIM="${HOME}/.local/bin/az"
if [[ -x "${AZ_SHIM}" ]]; then
  log "Creating symlink ${BIN_DIR}/az -> ${AZ_SHIM}..."
  sudo ln -sf "${AZ_SHIM}" "${BIN_DIR}/az"
else
  log "WARNING: az shim not found at ${AZ_SHIM}"
fi

log "Installed: $(az --version 2>/dev/null | head -1)"
