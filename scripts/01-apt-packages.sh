#!/usr/bin/env bash
# Install apt packages and CLI tools.
# Matches shell_environment role: cli_tools list.

set -euo pipefail

log() { echo "[apt-packages] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PACKAGES=(
  git
  curl
  wget
  unzip
  build-essential
  cmake
  python3-pip
  python3-venv
  htop
  jq
  fd-find
  ripgrep
  fzf
  zoxide
  tree
  bat
  tmux
  rsync
  imagemagick
  ffmpeg
  p7zip-full
  poppler-utils
  sqlite3
  acl
  zsh
  tig
)

# Every later step assumes passwordless sudo. Without this preflight a missing
# sudoers entry shows up as a *password prompt* — and in the unattended
# Codespaces creation path there is no tty to answer it, so the step hangs
# rather than failing. One clear error now beats a stalled run later.
if ! sudo -n true 2>/dev/null; then
  log "ERROR: passwordless sudo is not available for $(whoami)."
  log "       Every install step needs it. Fix sudoers, then re-run."
  exit 1
fi

# apt tunables that matter specifically on a freshly-created Codespace VM:
#   DEBIAN_FRONTEND  -y answers yes/no prompts but NOT debconf/conffile dialogs.
#                    With no tty those dialogs block forever, which is a hang and
#                    not a failure — nothing retries or times out a hang.
#   Lock::Timeout    a new VM is very likely still running unattended-upgrades /
#                    apt-daily, which holds the dpkg lock for minutes. The shared
#                    `retry` helper only gives ~21s of backoff, so without this
#                    apt loses the race — and since this is the one REQUIRED step,
#                    losing it aborts the entire run.
#   Acquire::Retries apt's own transport-level retry, complementary to `retry`.
export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(-o DPkg::Lock::Timeout=300 -o Acquire::Retries=3)

log "Updating apt cache..."
# Don't let a single broken third-party repo (e.g. an expired yarn/deadsnakes
# GPG key) abort the whole setup. The packages we need come from the Debian/
# Ubuntu main repos, which still update fine, so a partial failure here is OK.
# NOTE: this tolerance is for a *partial* failure. A total network outage leaves
# the cache stale or empty and the install below then fails with "Unable to
# locate package" — which is fatal, because this step is REQUIRED. The
# post-install verification is what turns that into a clear message.
if ! retry sudo apt-get "${APT_OPTS[@]}" update -q; then
  log "WARNING: 'apt-get update' reported errors (often a broken third-party repo)."
  log "Continuing — required packages come from the main repos."
fi

log "Installing packages: ${PACKAGES[*]}"
retry sudo apt-get "${APT_OPTS[@]}" install -y -q "${PACKAGES[@]}"

# `apt-get install` returning 0 was previously taken on faith. Verify the
# handful that every later step puts on its critical path, so a partial install
# fails here — loudly, with the missing names — instead of surfacing as a
# confusing cascade of derived failures in steps 2 through 17.
log "Verifying foundational tools..."
MISSING=()
for cmd in curl git unzip tar zsh; do
  command -v "${cmd}" >/dev/null 2>&1 || MISSING+=("${cmd}")
done
if ((${#MISSING[@]} > 0)); then
  log "ERROR: apt reported success but these are still missing: ${MISSING[*]}"
  log "       Every later step depends on them; aborting rather than cascading."
  exit 1
fi

log "Done."
