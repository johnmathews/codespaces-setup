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

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

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
npm_install_global() {
  # Prefer a non-root install: it inherits this script's NODE_EXTRA_CA_CERTS
  # (so it works behind a TLS-intercepting proxy) and avoids leaving root-owned
  # files in a user-writable nvm prefix. Fall back to sudo for root-owned
  # prefixes, explicitly forwarding PATH *and* the CA env (sudo strips it).
  if retry npm install -g --no-fund --no-audit "$@" 2>/dev/null; then
    return 0
  fi
  log "Non-root npm install failed; retrying with sudo..."
  local env_args=("PATH=${PATH}")
  [[ -f "${SYSTEM_CA}" ]] && env_args+=("NODE_EXTRA_CA_CERTS=${SYSTEM_CA}")
  retry sudo env "${env_args[@]}" npm install -g --no-fund --no-audit "$@"
}

if command -v npm >/dev/null 2>&1; then
  log "Installing npm CLI tools globally (prettierd, biome, eslint_d, markdownlint)..."
  # Warn and continue rather than aborting the whole run (matches the uv/release
  # tools below). The editor still works; Mason can install these inside Neovim.
  if ! npm_install_global \
    @fsouza/prettierd \
    @biomejs/biome \
    eslint_d \
    markdownlint-cli; then
    log "WARNING: failed to install one or more npm tools (prettierd, biome, eslint_d, markdownlint)."
    log "         Check network/proxy reachability and NODE_EXTRA_CA_CERTS=${NODE_EXTRA_CA_CERTS:-unset}."
    log "         Neovim's Mason can install them as a fallback."
  fi
else
  log "WARNING: npm not found; skipping prettierd, biome, eslint_d, markdownlint."
fi

# ---------------------------------------------------------------------------
# Python tools via uv: ruff, mypy
# ---------------------------------------------------------------------------
if command -v uv >/dev/null 2>&1; then
  log "Installing Python tools via uv (ruff, mypy)..."
  retry uv tool install --quiet ruff || log "WARNING: failed to install ruff."
  retry uv tool install --quiet mypy || log "WARNING: failed to install mypy."
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
  if installed_version_is glow "${GLOW_VERSION}"; then
    log "glow ${GLOW_VERSION} already installed, skipping."
    return
  fi
  local ver="${GLOW_VERSION#v}"
  local url="https://github.com/charmbracelet/glow/releases/download/${GLOW_VERSION}/glow_${ver}_Linux_${GLOW_ARCH}.tar.gz"
  local tmp
  tmp="$(mktemp -d)"
  log "Installing glow ${GLOW_VERSION}..."
  if ! fetch_verified "${url}" "${tmp}/glow.tar.gz"; then
    rm -rf "${tmp}"
    return 1
  fi
  tar -xzf "${tmp}/glow.tar.gz" -C "${tmp}"
  local bin
  bin="$(find "${tmp}" -type f -name glow | head -1)"
  if [[ -z "${bin}" ]] || ! "${bin}" --version >/dev/null 2>&1; then
    log "ERROR: the downloaded glow does not run; refusing to install it."
    rm -rf "${tmp}"
    return 1
  fi
  sudo install -m 755 "${bin}" "${BIN_DIR}/glow"
  rm -rf "${tmp}"
}

install_stylua() {
  # stylua's release binary does not run on glibc 2.31 (Ubuntu 20.04) — verified
  # in CI, where its own installer reported "System glibc version (`2.31\') is
  # too old". Unlike a whole step, this is one tool among nine here, so it
  # declines locally rather than exiting: the other eight still install.
  if ! glibc_at_least 2.32; then
    log "stylua: needs glibc >= 2.32, this system has ${GLIBC_VERSION} — skipping."
    log "        Use a base image on Ubuntu 22.04+ (see the README)."
    return 0
  fi
  if installed_version_is stylua "${STYLUA_VERSION}"; then
    log "stylua ${STYLUA_VERSION} already installed, skipping."
    return
  fi
  local url="https://github.com/JohnnyMorganz/StyLua/releases/download/${STYLUA_VERSION}/stylua-linux-${STYLUA_ARCH}.zip"
  local tmp
  tmp="$(mktemp -d)"
  log "Installing stylua ${STYLUA_VERSION}..."
  if ! fetch_verified "${url}" "${tmp}/stylua.zip"; then
    rm -rf "${tmp}"
    return 1
  fi
  unzip -q "${tmp}/stylua.zip" -d "${tmp}"
  if ! "${tmp}/stylua" --version >/dev/null 2>&1; then
    log "ERROR: the downloaded stylua does not run; refusing to install it."
    rm -rf "${tmp}"
    return 1
  fi
  sudo install -m 755 "${tmp}/stylua" "${BIN_DIR}/stylua"
  rm -rf "${tmp}"
}

install_shfmt() {
  if installed_version_is shfmt "${SHFMT_VERSION}"; then
    log "shfmt ${SHFMT_VERSION} already installed, skipping."
    return
  fi
  local url="https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_${SHFMT_ARCH}"
  local tmp
  tmp="$(mktemp -d)"
  log "Installing shfmt ${SHFMT_VERSION}..."
  if ! fetch_verified "${url}" "${tmp}/shfmt"; then
    rm -rf "${tmp}"
    return 1
  fi
  # A bare binary, so fetch_verified only proved it is non-empty. Run it.
  chmod +x "${tmp}/shfmt"
  if ! "${tmp}/shfmt" --version >/dev/null 2>&1; then
    log "ERROR: the downloaded shfmt does not run; refusing to install it."
    rm -rf "${tmp}"
    return 1
  fi
  sudo install -m 755 "${tmp}/shfmt" "${BIN_DIR}/shfmt"
  rm -rf "${tmp}"
}

# Warn and continue, matching the npm/uv policy above. Called bare under
# `set -e`, a glow failure would abort the step and stylua/shfmt would never
# install at all.
install_glow || log "WARNING: failed to install glow."
install_stylua || log "WARNING: failed to install stylua."
install_shfmt || log "WARNING: failed to install shfmt."

# This loop already computed the right answer and then threw it away: the script
# exited 0 with tools missing, so setup.sh recorded the step as successful and
# printed the green COMPLETE banner. Per-tool failures still only warn (Mason can
# install them inside Neovim), but the STEP now reports the truth.
log "Verification:"
MISSING_TOOLS=()
for tool in prettierd biome eslint_d markdownlint ruff mypy glow stylua shfmt; do
  if command -v "${tool}" >/dev/null 2>&1; then
    printf "  ✅ %s\n" "${tool}"
  else
    printf "  ❌ %s (not found)\n" "${tool}"
    MISSING_TOOLS+=("${tool}")
  fi
done

if ((${#MISSING_TOOLS[@]} > 0)); then
  log "ERROR: ${#MISSING_TOOLS[@]} tool(s) did not install: ${MISSING_TOOLS[*]}"
  log "       Neovim's Mason can install them as a fallback, but this step did"
  log "       not do what it claims, so it reports failure."
  exit 1
fi

log "Done."
