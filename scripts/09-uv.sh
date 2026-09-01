#!/usr/bin/env bash
# Install uv (Python package manager) via official installer script.
# Matches shell_environment role: uv_enabled = true.

set -euo pipefail

log() { echo "[uv] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# No pinned version for uv, so the guard proves the binary EXECUTES. See lib.sh.
if installed_runs uv; then
  log "uv already installed (${INSTALLED_VERSION}), skipping."
  exit 0
fi

log "Installing uv via official installer..."
# Download then run (with retries) instead of `curl | sh`, so a transient
# network failure can be retried rather than piping a truncated script to sh.
UV_INSTALLER="$(mktemp)"
trap 'rm -f "${UV_INSTALLER}"' EXIT
retry net_curl https://astral.sh/uv/install.sh -o "${UV_INSTALLER}"
# `sh -n` proves the download is complete before it is executed.
if ! sh -n "${UV_INSTALLER}"; then
  log "ERROR: the downloaded uv installer is not valid shell (truncated download?)."
  exit 1
fi
# Retry the installer too: the retried curl above fetches ~10 KB of shell, while
# the uv binary itself is fetched inside this script and is the slow, flaky hop.
retry sh "${UV_INSTALLER}"

# The installer puts uv in ~/.local/bin; make it globally available
UV_LOCAL="${HOME}/.local/bin/uv"
if [[ -x "${UV_LOCAL}" ]]; then
  sudo ln -sf "${UV_LOCAL}" /usr/local/bin/uv
else
  # uv is a hard dependency of 15-dev-tools.sh (ruff, mypy) and 18-azure-cli.sh,
  # both of which only warn when it is missing — so a silent no-op here degrades
  # three steps quietly. Fail loudly instead.
  log "ERROR: the uv installer did not produce ${UV_LOCAL}."
  exit 1
fi

log "Installed: $(uv --version)"
