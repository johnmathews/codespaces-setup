#!/usr/bin/env bash
# Run the REAL setup.sh, with the REAL installers, inside the REAL base image.
#
# WHY THIS EXISTS: nothing else in CI executes a single line of the 17 installer
# scripts. shellcheck and shfmt read them, ci/lint-steps.sh checks their wiring,
# ci/lint-conventions.sh checks their shape, and tests/setup-resilience/ drives
# the runner over FAKE steps via SETUP_SCRIPTS_DIR. So ~2000 lines of the thing
# this repo actually ships were exercised by nothing, and every defect in them
# stayed latent until someone created a Codespace — a slow and expensive way to
# find out. A green PR was not evidence about the Codespace-creation path.
#
# Three of the four defects behind the 2026-09-01 resilience work would have been
# caught here (a broken install guard, a step reporting success with tools
# missing, and the apt hardening).
#
# This is deliberately NOT part of the fast `lint` job: it is slow and it needs
# the network. Run it in its own job so the quick gates stay quick.
#
# Usage:
#   bash ci/smoke-container.sh              # uses the image from devcontainer.json
#   IMAGE=ubuntu:24.04 bash ci/smoke-container.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { echo "[smoke] $*"; }

if ! command -v docker >/dev/null 2>&1; then
  log "ERROR: docker is required to run the container smoke test."
  exit 1
fi

# Read the image from devcontainer.json rather than hardcoding it, so this test
# always exercises the image the project actually ships on.
IMAGE="${IMAGE:-$(python3 -c '
import json
with open("'"${REPO_DIR}"'/.devcontainer/devcontainer.json") as fh:
    print(json.load(fh)["image"])
')}"
log "Base image: ${IMAGE}"

# The container runs as a non-root user with passwordless sudo, matching a real
# Codespace — running as root would skip every sudo path and prove nothing about
# the environment the scripts actually meet.
#
# The user differs per image: base:ubuntu ships `vscode`, universal:2 ships
# `codespace`. Resolved INSIDE the container below, because an earlier version
# interpolated the name into the container command from out here and then had a
# `|| CONTAINER_USER=root` fallback that could never fire — so on universal:2 it
# ran `su - vscode`, which does not exist, and setup.sh never started at all.
# The job failed with no run record and no output, which looked like a setup
# failure and was a bug in this script.

log "Running setup.sh end to end (this takes several minutes)..."
set +e
docker run --rm \
  -v "${REPO_DIR}:/workspace:ro" \
  -e DEBIAN_FRONTEND=noninteractive \
  -e SETUP_LOG_DIR=/tmp/setup-logs \
  "${IMAGE}" \
  bash -lc '
    set -uo pipefail
    # Resolve the unprivileged user that this image actually has.
    for u in ${CONTAINER_USER:-} vscode codespace ubuntu; do
      if [ -n "${u}" ] && id -u "${u}" >/dev/null 2>&1; then
        RUN_AS="${u}"
        break
      fi
    done
    RUN_AS="${RUN_AS:-root}"
    echo "[smoke] running as: ${RUN_AS}"
    # The mount is read-only so the run cannot mutate the checkout; copy it out.
    cp -a /workspace /tmp/repo
    chown -R "${RUN_AS}":"${RUN_AS}" /tmp/repo 2>/dev/null || true
    su - "${RUN_AS}" -c "sudo -n true" 2>/dev/null ||
      echo "[smoke] note: ${RUN_AS} does not have passwordless sudo"
    # Exercise the devcontainer entrypoint, which delegates to the same runner
    # GitHub uses for account-wide dotfiles.
    RC=0
    su - "${RUN_AS}" -c "SETUP_LOG_DIR=/tmp/setup-logs bash /tmp/repo/.devcontainer/post-create.sh" || RC=$?
    echo "[smoke] setup.sh exit code: ${RC}"
    echo "[smoke] ---- run record ----"
    cat /tmp/setup-logs/latest.json 2>/dev/null || echo "[smoke] NO RUN RECORD WRITTEN"
    if [ "${RC}" -eq 0 ]; then
      su - "${RUN_AS}" -s /bin/bash -c '"'"'
        set -euo pipefail
        export PATH="${HOME}/.local/bin:${PATH}"
        timeout 1800 bash -c '"'"'"'"'"'"'"'"'
          while [[ ! -f "${HOME}/.cache/nvim-setup.status" ]] ||
            [[ "$(head -1 "${HOME}/.cache/nvim-setup.status")" == running ]]; do
            sleep 2
          done
          [[ "$(head -1 "${HOME}/.cache/nvim-setup.status")" == ok ]]
        '"'"'"'"'"'"'"'"'
        cd "${HOME}/.config/nvim"
        source scripts/versions.env
        [[ "$(command -v nvim)" == "${HOME}/.local/bin/nvim" ]]
        [[ "$(nvim --version | head -1)" == "NVIM v${NVIM_PIN}" ]]
        git diff --exit-code -- lazy-lock.json
        before="$(sha256sum lazy-lock.json)"
        # Re-run the managed checkout, bootstrap and sync after initial preload.
        bash /tmp/repo/scripts/04-neovim-config.sh
        bash /tmp/repo/scripts/03-neovim.sh
        bash /tmp/repo/scripts/13-nvim-plugins.sh
        [[ "$(head -1 "${HOME}/.cache/nvim-setup.status")" == ok ]]
        [[ "$(sha256sum lazy-lock.json)" == "${before}" ]]
        git diff --exit-code -- lazy-lock.json
        echo "[smoke] PASS: Neovim pins, fresh synchronization and idempotent rerun"
      '"'"' || RC=$?
    fi
    exit "${RC}"
  '
RC=$?
set -e

if ((RC == 0)); then
  log "PASS: setup.sh completed cleanly in ${IMAGE}."
else
  log "FAIL: setup.sh exited ${RC} in ${IMAGE}."
  log "      That exit code is now meaningful: it accounts for failed steps AND"
  log "      for tools that are missing despite their step reporting success."
fi
exit "${RC}"
