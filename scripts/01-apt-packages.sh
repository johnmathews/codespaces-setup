#!/usr/bin/env bash
# Install apt packages and CLI tools.
# Matches shell_environment role: cli_tools list.

set -euo pipefail

log() { echo "[apt-packages] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Tools every LATER step puts on its critical path. If one of these is missing
# the run genuinely cannot continue, so their absence is fatal.
ESSENTIAL=(
  git
  curl
  wget
  unzip
  zsh
)

# Everything else. These make the environment nice; none of them gates another
# step. A single one being unavailable must NOT stop the other 20 installing,
# which is exactly what used to happen: `apt-get install` fails the whole
# transaction on one unknown package name, so `zoxide` (absent from Ubuntu
# 20.04 focal, where this kit is also expected to run) took down the entire
# list — and because this step is REQUIRED, it aborted the whole run at step 1.
OPTIONAL=(
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

# Retrying is for TRANSIENT failures. Some apt errors are deterministic and will
# fail identically on every attempt — a third-party repo whose signing key is
# missing, or a package name that does not exist on this Ubuntu release. Burning
# five attempts with backoff on those wastes 75-110 seconds and changes nothing,
# which is precisely the "slow" half of the problem this kit is meant to solve.
#
# Returns 0 (do not retry) when the output shows a permanent failure.
apt_error_is_permanent() {
  grep -qE 'NO_PUBKEY|is not signed|Unable to locate package|has no installation candidate' "$1"
}

# Run an apt command, retrying only while the failure looks transient.
apt_try() {
  local out rc attempt=1 max="${APT_ATTEMPTS:-4}" delay=5
  out="$(mktemp)"
  while true; do
    rc=0
    # shellcheck disable=SC2024  # the redirect is the CALLER's, into a
    # user-owned mktemp file — which is what we want; sudo only elevates apt.
    sudo apt-get "${APT_OPTS[@]}" "$@" >"${out}" 2>&1 || rc=$?
    cat "${out}"
    if ((rc == 0)); then
      rm -f "${out}"
      return 0
    fi
    if apt_error_is_permanent "${out}"; then
      log "apt failed permanently (exit ${rc}) — not retrying, the error cannot resolve on its own."
      rm -f "${out}"
      return "${rc}"
    fi
    if ((attempt >= max)); then
      log "apt failed after ${attempt} attempt(s) (exit ${rc})."
      rm -f "${out}"
      return "${rc}"
    fi
    log "apt attempt ${attempt}/${max} failed (exit ${rc}); retrying in ${delay}s..."
    sleep "${delay}"
    delay=$((delay * 2))
    attempt=$((attempt + 1))
  done
}

log "Updating apt cache..."
# Don't let a single broken third-party repo (e.g. the yarn source shipped in
# some Codespaces base images, whose signing key has expired) abort the setup.
# The packages we need come from the Debian/Ubuntu main repos, which still
# update fine, so a partial failure here is tolerable.
if ! apt_try update -q; then
  log "WARNING: 'apt-get update' reported errors (often a broken third-party repo)."
  log "Continuing — required packages come from the main repos."
fi

# Filter to what this Ubuntu release actually has. Asking apt to install a name
# it does not know fails the ENTIRE transaction, so one package missing on an
# older release would otherwise cost all the others.
available=()
unavailable=()
for pkg in "${ESSENTIAL[@]}" "${OPTIONAL[@]}"; do
  if apt-cache show "${pkg}" >/dev/null 2>&1; then
    available+=("${pkg}")
  else
    unavailable+=("${pkg}")
  fi
done

if ((${#unavailable[@]} > 0)); then
  log "NOTE: not available on this release, skipping: ${unavailable[*]}"
  # shellcheck disable=SC1091  # runtime file, not part of this repo
  log "      ($(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}"))"
fi

log "Installing packages: ${available[*]}"
if ! apt_try install -y -q "${available[@]}"; then
  # Fall back to installing one at a time, so a single broken package does not
  # cost the rest. Slower, and only reached when the batch already failed.
  log "WARNING: batch install failed; retrying package by package..."
  for pkg in "${available[@]}"; do
    apt_try install -y -q "${pkg}" >/dev/null 2>&1 ||
      log "  WARNING: failed to install ${pkg}"
  done
fi

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
  log "ERROR: these are still missing after install: ${MISSING[*]}"
  log "       Every later step depends on them; aborting rather than cascading."
  exit 1
fi
if ((${#unavailable[@]} > 0)); then
  log "Done, with ${#unavailable[@]} optional package(s) unavailable on this release: ${unavailable[*]}"
  log "They are conveniences, not dependencies — no later step needs them."
fi

log "Done."
