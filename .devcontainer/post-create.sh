#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_DIR}/setup.sh" ]]; then
  echo "[post-create] ERROR: setup.sh not found in ${REPO_DIR}" >&2
  exit 1
fi

# No self-update on this path. setup.sh fetches and fast-forwards its own
# checkout before running, which is the fix for the DOTFILES route — there the
# clone is frozen at Codespace creation, so re-running it silently re-applies
# old code. Here the container was just created from this very commit, so there
# is nothing to update, and attempting it would be actively wrong: the checkout
# is whatever ref the Codespace was created from (commonly a PR branch, or a
# detached HEAD), and pulling during creation would run code the user did not
# ask for.
export SETUP_NO_SELF_UPDATE=1

bash "${REPO_DIR}/setup.sh"
