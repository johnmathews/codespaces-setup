#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_DIR}/setup.sh" ]]; then
  echo "[post-create] ERROR: setup.sh not found in ${REPO_DIR}" >&2
  exit 1
fi

bash "${REPO_DIR}/setup.sh"
