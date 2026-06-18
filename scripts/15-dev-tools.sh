#!/usr/bin/env bash
# Install developer CLI tools that Neovim expects to find on PATH.
#
# These mirror the mason-tool-installer list in johnmathews/neovim (formatters
# and linters) plus `glow`, which glow.nvim looks up on PATH directly. Installing
# them at the system level means the editor's formatting / linting / markdown
# preview features work even when Mason cannot install them inside Neovim.
#
# Installed here:
#   npm     : prettierd, biome, eslint_d, markdownlint
#   uv      : ruff, mypy
#   release : glow, stylua, shfmt

set -euo pipefail

log() { echo "[dev-tools] $*"; }

BIN_DIR="/usr/local/bin"

# Behind a TLS-intercepting proxy (common on corporate networks / restrictive
# Codespace network policies), npm and pip reject the proxy's CA because they
# ship their own trust store, failing with SELF_SIGNED_CERT_IN_CHAIN. Point them
# at the system CA bundle (which does include the proxy CA) so installs succeed.
SYSTEM_CA="/etc/ssl/certs/ca-certificates.crt"
if [[ -f "${SYSTEM_CA}" ]]; then
  export NODE_EXTRA_CA_CERTS="${SYSTEM_CA}"
  export SSL_CERT_FILE="${SYSTEM_CA}"
  export REQUESTS_CA_BUNDLE="${SYSTEM_CA}"
  log "Using system CA bundle for npm/pip/uv TLS: ${SYSTEM_CA}"
fi

GLOW_VERSION="v2.1.1"
STYLUA_VERSION="v2.1.0"
SHFMT_VERSION="v3.10.0"

ARCH="$(uname -m)"
case "${ARCH}" in
  aarch64 | arm64)
    GLOW_ARCH="arm64"
    STYLUA_ARCH="aarch64"
    SHFMT_ARCH="arm64"
    ;;
  *)
    GLOW_ARCH="x86_64"
    STYLUA_ARCH="x86_64"
    SHFMT_ARCH="amd64"
    ;;
esac

# ---------------------------------------------------------------------------
# npm-based tools: prettierd, biome, eslint_d, markdownlint
# ---------------------------------------------------------------------------
if command -v npm >/dev/null 2>&1; then
  log "Installing npm CLI tools globally (prettierd, biome, eslint_d, markdownlint)..."
  # `sudo env PATH=...` keeps node/npm resolvable regardless of where they live.
  sudo env "PATH=${PATH}" npm install -g --no-fund --no-audit \
    @fsouza/prettierd \
    @biomejs/biome \
    eslint_d \
    markdownlint-cli
else
  log "WARNING: npm not found; skipping prettierd, biome, eslint_d, markdownlint."
fi

# ---------------------------------------------------------------------------
# Python tools via uv: ruff, mypy
# ---------------------------------------------------------------------------
if command -v uv >/dev/null 2>&1; then
  log "Installing Python tools via uv (ruff, mypy)..."
  uv tool install --quiet ruff || log "WARNING: failed to install ruff."
  uv tool install --quiet mypy || log "WARNING: failed to install mypy."
  # Expose the uv tool shims on the global PATH, matching scripts/09-uv.sh.
  for tool in ruff mypy; do
    if [[ -x "${HOME}/.local/bin/${tool}" ]]; then
      sudo ln -sf "${HOME}/.local/bin/${tool}" "${BIN_DIR}/${tool}"
    fi
  done
else
  log "WARNING: uv not found; skipping ruff, mypy."
fi

# ---------------------------------------------------------------------------
# Release-binary tools: glow, stylua, shfmt
# ---------------------------------------------------------------------------
install_glow() {
  if command -v glow >/dev/null 2>&1; then
    log "glow already installed, skipping."
    return
  fi
  local ver="${GLOW_VERSION#v}"
  local url="https://github.com/charmbracelet/glow/releases/download/${GLOW_VERSION}/glow_${ver}_Linux_${GLOW_ARCH}.tar.gz"
  local tmp
  tmp="$(mktemp -d)"
  log "Installing glow ${GLOW_VERSION}..."
  curl -fsSL "${url}" -o "${tmp}/glow.tar.gz"
  tar -xzf "${tmp}/glow.tar.gz" -C "${tmp}"
  sudo install -m 755 "$(find "${tmp}" -type f -name glow | head -1)" "${BIN_DIR}/glow"
  rm -rf "${tmp}"
}

install_stylua() {
  if command -v stylua >/dev/null 2>&1; then
    log "stylua already installed, skipping."
    return
  fi
  local url="https://github.com/JohnnyMorganz/StyLua/releases/download/${STYLUA_VERSION}/stylua-linux-${STYLUA_ARCH}.zip"
  local tmp
  tmp="$(mktemp -d)"
  log "Installing stylua ${STYLUA_VERSION}..."
  curl -fsSL "${url}" -o "${tmp}/stylua.zip"
  unzip -q "${tmp}/stylua.zip" -d "${tmp}"
  sudo install -m 755 "${tmp}/stylua" "${BIN_DIR}/stylua"
  rm -rf "${tmp}"
}

install_shfmt() {
  if command -v shfmt >/dev/null 2>&1; then
    log "shfmt already installed, skipping."
    return
  fi
  local url="https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_${SHFMT_ARCH}"
  local tmp
  tmp="$(mktemp -d)"
  log "Installing shfmt ${SHFMT_VERSION}..."
  curl -fsSL "${url}" -o "${tmp}/shfmt"
  sudo install -m 755 "${tmp}/shfmt" "${BIN_DIR}/shfmt"
  rm -rf "${tmp}"
}

install_glow
install_stylua
install_shfmt

log "Verification:"
for tool in prettierd biome eslint_d markdownlint ruff mypy glow stylua shfmt; do
  if command -v "${tool}" >/dev/null 2>&1; then
    printf "  ✅ %s\n" "${tool}"
  else
    printf "  ❌ %s (not found)\n" "${tool}"
  fi
done

log "Done."
