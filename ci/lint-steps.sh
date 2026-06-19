#!/usr/bin/env bash
# Lint the relationship between scripts/ and the STEPS array in setup.sh.
#
# setup.sh does NOT run every file in scripts/ — it executes an explicit,
# ordered STEPS array. The numeric filename prefixes are labels, not the source
# of execution order. That makes one mistake very easy to make: add a new
# scripts/NN-name.sh and forget to wire it into STEPS, so it silently never
# runs. This linter catches that (and the inverse: a STEPS entry pointing at a
# script that doesn't exist).
#
# Scripts that are intentionally NOT in STEPS (launched some other way) must be
# listed in EXEMPT below, with a comment saying why.

set -euo pipefail

log() { echo "[lint-steps] $*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="${REPO_DIR}/setup.sh"
SCRIPTS_DIR="${REPO_DIR}/scripts"

# Scripts deliberately excluded from the STEPS array, with the reason:
declare -a EXEMPT=(
  "13-nvim-plugins.sh" # launched in the background at the end of setup.sh, not via run_step
)

is_exempt() {
  local name="$1"
  for e in "${EXEMPT[@]}"; do
    [[ "${name}" == "${e}" ]] && return 0
  done
  return 1
}

# Extract the script filenames referenced inside the STEPS=( ... ) array only
# (so we don't pick up the 13-nvim-plugins.sh reference elsewhere in the file).
# Avoid `mapfile` so this also runs under the bash 3.2 that ships on macOS.
declare -a step_scripts=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && step_scripts+=("${line}")
done < <(
  awk '/^STEPS=\(/{f=1; next} f && /^\)/{f=0} f' "${SETUP}" |
    grep -oE '[0-9]{2}-[a-z0-9-]+\.sh' || true
)

if [[ "${#step_scripts[@]}" -eq 0 ]]; then
  log "ERROR: could not parse any scripts from the STEPS array in ${SETUP}"
  exit 1
fi

errors=0

# 1. Every STEPS entry must point at a real script.
for s in "${step_scripts[@]}"; do
  if [[ ! -f "${SCRIPTS_DIR}/${s}" ]]; then
    log "ERROR: STEPS references '${s}' but scripts/${s} does not exist"
    errors=$((errors + 1))
  fi
done

# 2. Every script in scripts/ must be in STEPS or explicitly EXEMPT.
for path in "${SCRIPTS_DIR}"/*.sh; do
  name="$(basename "${path}")"
  if printf '%s\n' "${step_scripts[@]}" | grep -qx "${name}"; then
    continue
  fi
  if is_exempt "${name}"; then
    log "ok (exempt): ${name}"
    continue
  fi
  log "ERROR: scripts/${name} is not in the STEPS array and not EXEMPT — it will never run."
  log "       Add it to STEPS in setup.sh, or add it to EXEMPT in this linter with a reason."
  errors=$((errors + 1))
done

if [[ "${errors}" -gt 0 ]]; then
  log "FAILED with ${errors} error(s)."
  exit 1
fi

log "OK: ${#step_scripts[@]} steps wired up, ${#EXEMPT[@]} exempt, no orphans."
