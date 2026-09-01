#!/usr/bin/env bash
# Lint scripts/ against setup.sh — two properties, both invisible until they bite.
#
# 1. WIRING. setup.sh does NOT run every file in scripts/ — it executes an
#    explicit, ordered STEPS array. The numeric filename prefixes are labels,
#    not the source of execution order. That makes one mistake very easy to
#    make: add a new scripts/NN-name.sh and forget to wire it into STEPS, so it
#    silently never runs. This linter catches that (and the inverse: a STEPS
#    entry pointing at a script that doesn't exist).
#
#    Scripts that are intentionally NOT in STEPS (launched some other way) must
#    be listed in EXEMPT below, with a comment saying why.
#
# 2. FILE MODE. setup.sh runs `chmod +x "${SCRIPTS_DIR}"/*.sh` on every run, so
#    any script committed 100644 turns 755 on disk and git then reports it
#    modified on every machine, forever. Worse, that permanent dirt aborts
#    `git pull` ("Please commit your changes or stash them before you merge")
#    whenever an incoming commit touches the file. Nothing surfaces the mistake
#    at the point it is made, because the exec bit is never actually consulted —
#    setup.sh invokes each step as `bash "${script}"` — so three scripts in a
#    row were committed 644 and the cost showed up somewhere else entirely.
#    This linter closes that loop: every scripts/*.sh must be committed 100755.
#
#    Scope is deliberately narrow. setup.sh and .devcontainer/post-create.sh are
#    committed 644 and that is fine — nothing chmods them, so they never drift.
#
#    THAT REASONING WAS WRONG for the repo-root entry points, and it cost a
#    real user a broken `git pull`. GitHub's dotfiles mechanism chmods the
#    install script before running it, so setup.sh arrived as 100644 and became
#    100755 on every Codespace; `git pull` then refused because of a mode-only
#    change the user could not see in a content diff. They are now checked too.
#    The invariant is not "shell scripts are executable", it is "files setup.sh
#    chmods must be committed the way setup.sh will leave them".

set -euo pipefail

log() { echo "[lint-steps] $*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="${REPO_DIR}/setup.sh"
SCRIPTS_DIR="${REPO_DIR}/scripts"

# Scripts deliberately excluded from the STEPS array, with the reason:
declare -a EXEMPT=(
  "13-nvim-plugins.sh" # launched in the background at the end of setup.sh, not via run_step
  "lib.sh"             # sourced by the other scripts (shared retry helper), never run as a step
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

# 0. No duplicate STEPS entries. A duplicate is harmless in effect (the steps are
#    idempotent) but it inflates TOTAL_STEPS, so the [NN/TT] counter and the
#    progress bar lie, and it doubles that step's network cost on every run.
dupes="$(printf '%s\n' "${step_scripts[@]}" | sort | uniq -d || true)"
if [[ -n "${dupes}" ]]; then
  while IFS= read -r d; do
    [[ -n "${d}" ]] || continue
    log "ERROR: '${d}' appears more than once in the STEPS array"
    errors=$((errors + 1))
  done <<<"${dupes}"
fi

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
    # An EXEMPT entry asserts "this runs some other way". Check that claim,
    # rather than taking it on trust: this linter exists to catch "a script that
    # would silently never run", and for the ONE script launched outside STEPS
    # that guarantee was previously a comment. Deleting the 13-nvim-plugins.sh
    # launch block from setup.sh left this gate green — defeating its whole
    # stated purpose at exactly the point it was supposed to apply.
    #
    # lib.sh is the exception to the exception: it is SOURCED by the steps, so it
    # is referenced from scripts/, not from setup.sh.
    if [[ "${name}" == "lib.sh" ]]; then
      if grep -qE 'lib\.sh' "${SCRIPTS_DIR}"/*.sh; then
        log "ok (exempt, sourced by steps): ${name}"
      else
        log "ERROR: ${name} is EXEMPT as 'sourced by the other scripts', but nothing in scripts/ sources it."
        errors=$((errors + 1))
      fi
    elif grep -qF "${name}" "${SETUP}"; then
      log "ok (exempt, referenced by setup.sh): ${name}"
    else
      log "ERROR: ${name} is EXEMPT (runs outside STEPS), but setup.sh does not mention it."
      log "       Either its launch site was deleted — in which case it now never runs —"
      log "       or the EXEMPT entry is stale. Both are the failure this linter exists to catch."
      errors=$((errors + 1))
    fi
    continue
  fi
  log "ERROR: scripts/${name} is not in the STEPS array and not EXEMPT — it will never run."
  log "       Add it to STEPS in setup.sh, or add it to EXEMPT in this linter with a reason."
  errors=$((errors + 1))
done

# 2b. The repo-root entry points must be committed 100755 too. They are chmod'ed
#     by things outside this repo — GitHub's dotfiles installer makes the install
#     script executable before running it — so a 100644 commit shows up as a
#     mode-only local modification on every machine, and blocks `git pull` with a
#     diff that looks empty.
for path in "${REPO_DIR}/setup.sh" "${REPO_DIR}/deploy-engineering-team-skill.sh" \
  "${REPO_DIR}/.devcontainer/post-create.sh" "${REPO_DIR}/bin/setup-status"; do
  [[ -f "${path}" ]] || continue
  rel="${path#"${REPO_DIR}/"}"
  mode="$(git -C "${REPO_DIR}" ls-files -s -- "${rel}" | awk '{print $1}')"
  if [[ -z "${mode}" ]]; then
    continue # untracked; nothing to assert
  fi
  if [[ "${mode}" != "100755" ]]; then
    log "ERROR: ${rel} is committed ${mode}, expected 100755."
    log "       It is executed directly and gets chmod'ed outside this repo, so a"
    log "       644 commit becomes a mode-only local change that blocks 'git pull'."
    log "       Fix: git update-index --chmod=+x ${rel}"
    errors=$((errors + 1))
  fi
done

# 3. Every script in scripts/ must be COMMITTED executable (100755), because
#    setup.sh chmods them to 755 on disk on every run. See the header.
#    We read the mode from the git index, not the filesystem: the filesystem
#    mode is what setup.sh already changed, so checking it would compare setup.sh
#    against itself and pass no matter what is committed.
if ! git -C "${REPO_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
  log "ERROR: not a git repo (or git unavailable) — cannot read committed file modes."
  log "       This check reads the index, so it cannot be skipped silently."
  errors=$((errors + 1))
else
  checked=0
  while IFS= read -r entry; do
    # `git ls-files -s` prints: <mode> <sha> <stage>\t<path>
    mode="${entry%% *}"
    path="${entry#*$'\t'}"
    [[ "${path}" == *.sh ]] || continue
    checked=$((checked + 1))
    if [[ "${mode}" != "100755" ]]; then
      log "ERROR: ${path} is committed ${mode}, expected 100755."
      log "       setup.sh runs 'chmod +x scripts/*.sh', so this file will show as"
      log "       modified on every machine forever and will abort 'git pull'."
      log "       Fix: git update-index --chmod=+x ${path}"
      errors=$((errors + 1))
    fi
  done < <(git -C "${REPO_DIR}" ls-files -s scripts)

  # A scanner that matches nothing passes loudest when it is blind. If the
  # parse above ever breaks (renamed dir, changed ls-files format), `checked`
  # goes to 0 and this check would silently approve everything. Pin it against
  # what is actually on disk.
  on_disk=$(find "${SCRIPTS_DIR}" -maxdepth 1 -name '*.sh' | wc -l | tr -d ' ')
  if [[ "${checked}" -ne "${on_disk}" ]]; then
    log "ERROR: mode check inspected ${checked} script(s) but ${on_disk} exist on disk."
    log "       The check is not seeing what it claims to — treat it as broken, not as passing."
    errors=$((errors + 1))
  fi
fi

if [[ "${errors}" -gt 0 ]]; then
  log "FAILED with ${errors} error(s)."
  exit 1
fi

log "OK: ${#step_scripts[@]} steps wired up, ${#EXEMPT[@]} exempt, no orphans; ${checked} scripts committed 100755."
