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
CONTAINER_USER="${CONTAINER_USER:-vscode}"

log "Running setup.sh end to end (this takes several minutes)..."
set +e
docker run --rm \
  -v "${REPO_DIR}:/workspace:ro" \
  -e DEBIAN_FRONTEND=noninteractive \
  -e SETUP_LOG_DIR=/tmp/setup-logs \
  "${IMAGE}" \
  bash -lc '
    set -uo pipefail
    id -u '"${CONTAINER_USER}"' >/dev/null 2>&1 || CONTAINER_USER=root
    # The mount is read-only so the run cannot mutate the checkout; copy it out.
    cp -a /workspace /tmp/repo
    chown -R '"${CONTAINER_USER}"':'"${CONTAINER_USER}"' /tmp/repo 2>/dev/null || true
    sudo -n true 2>/dev/null || echo "[smoke] note: running without passwordless sudo"
    # Run ONCE. An earlier version had a `|| su - ... setup.sh` fallback, which
    # re-ran the entire install on failure — doubling a ~15 minute job to learn
    # nothing new, since a genuine failure fails the same way twice. setup.sh
    # already retries internally, both per-download and as an end-of-run pass.
    RC=0
    su - '"${CONTAINER_USER}"' -c "SETUP_LOG_DIR=/tmp/setup-logs bash /tmp/repo/setup.sh" || RC=$?
    echo "[smoke] setup.sh exit code: ${RC}"
    echo "[smoke] ---- run record ----"
    cat /tmp/setup-logs/latest.json 2>/dev/null || echo "[smoke] NO RUN RECORD WRITTEN"
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
