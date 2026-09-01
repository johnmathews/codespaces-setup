#!/usr/bin/env bash
# Install Claude Code CLI via the official Anthropic installer.
# Installer source: https://claude.ai/install.sh (official Anthropic endpoint)
# The same curl-to-bash pattern is used by the other installers in this repo
# (atuin, uv, nodejs) where an official vendor script is trusted.

set -euo pipefail

log() { echo "[claude-code] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Download and run the official installer (retryable) instead of `curl | bash`,
# so a transient network failure retries rather than piping a truncated script.
install_claude() {
  local installer
  installer="$(mktemp)"
  retry net_curl https://claude.ai/install.sh -o "${installer}"
  # `bash -n` proves the download is complete before it is executed.
  if ! bash -n "${installer}"; then
    log "ERROR: the downloaded Claude Code installer is not valid shell (truncated download?)."
    rm -f "${installer}"
    return 1
  fi
  # Retry the installer itself, not only its download: the retried curl fetches a
  # small shell script, while the multi-megabyte bundle is fetched inside it.
  retry bash "${installer}"
  rm -f "${installer}"
}

if command -v claude &>/dev/null; then
  before="$(claude --version 2>/dev/null || echo 'unknown version')"
  log "Claude Code already installed (${before}); updating to latest..."
  # Prefer the CLI's built-in self-updater; fall back to re-running the official
  # installer if it is missing or fails (e.g. an old build without `update`).
  if claude update 2>&1; then
    log "Up to date: $(claude --version 2>/dev/null || echo 'unknown version') (was ${before})"
  else
    log "WARNING: 'claude update' failed; re-running official installer..."
    install_claude
    log "Reinstalled: $(claude --version 2>/dev/null || echo 'installed') (was ${before})"
  fi
  exit 0
fi

log "Installing Claude Code..."
install_claude

# The installer puts claude in ~/.local/bin, which is NOT on the PATH of a
# non-login shell — so the end-of-run verification reported `claude` missing even
# though the step had just succeeded, and the step's own version line printed a
# useless "installed". Symlink it globally, exactly as 09-uv.sh does for uv.
CLAUDE_LOCAL="${HOME}/.local/bin/claude"
if [[ -x "${CLAUDE_LOCAL}" ]]; then
  sudo ln -sf "${CLAUDE_LOCAL}" /usr/local/bin/claude
fi

hash -r 2>/dev/null || true

if ! command -v claude >/dev/null 2>&1; then
  log "ERROR: claude is not on PATH after install (looked for ${CLAUDE_LOCAL})."
  exit 1
fi

log "Installed: $(claude --version 2>/dev/null || echo 'unknown version')"
