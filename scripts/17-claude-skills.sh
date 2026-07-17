#!/usr/bin/env bash
# Deploy personal Claude Code skills and slash commands into ~/.claude.
#
# Claude Code discovers user-level skills under ~/.claude/skills/<name>/ and
# user-level slash commands under ~/.claude/commands/<name>.md. We vendor the
# source files in this repo's configs/claude/ tree and copy them into place so a
# fresh Codespace has them available the moment Claude Code starts.
#
# Vendored here (keep in sync with the local ~/.claude copies):
#   - skills/engineering-team  -> /engineering-team
#   - commands/done.md         -> /done
#   - commands/merge-push.md   -> /merge-push
#   - commands/prompt.md       -> /prompt
#
# Idempotent: a skill dir / command file is only (re)written when it differs
# from what is already on disk.
#
# NO .bak HERE — this script deliberately breaks the .bak convention that
# 11-dotfiles.sh follows, and re-adding it would be a regression. Two reasons:
#
#   1. ~/.claude/skills/ is SCANNED. Claude Code registers every subdirectory
#      holding a SKILL.md, so a backup does not sit inertly beside the original
#      — it loads as a second skill with an identical name and description, and
#      the choice between the live skill and a stale copy becomes arbitrary.
#      A backup of a scanned directory is not a backup; it is a fork.
#   2. It is redundant anyway. These assets are version-controlled in this repo,
#      so the previous version is always a `git show` away. 11-dotfiles.sh backs
#      up ~/.zshrc because that file may hold hand edits that exist nowhere else;
#      nothing here does.
#
# The rule this generalises to, for anything added later: never write a
# non-asset into an assets directory that something else scans.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${REPO_DIR}/configs/claude"

log() { echo "[claude-skills] $*"; }

CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
COMMANDS_DIR="${CLAUDE_DIR}/commands"
mkdir -p "${SKILLS_DIR}" "${COMMANDS_DIR}"

# Remove backup artifacts left by older versions of this script.
#
# ~/.claude/skills/ is SCANNED: Claude Code registers every subdirectory that
# contains a SKILL.md. A backup copy therefore does not sit inertly beside the
# original — it loads as a SECOND skill, with a byte-identical `name:` and
# description, so selection between the real skill and a stale copy of it is
# arbitrary. Every deploy minted one, which is a duplicate whose whole purpose
# is to hold the version we just deliberately replaced.
#
# This function is the self-heal for machines that already have them. It is
# deliberately narrow: only `${SKILLS_DIR}/*.bak` and `${COMMANDS_DIR}/*.bak`,
# both of which are unambiguously this script's own leftovers. Anything else
# under ~/.claude is the user's and is never touched.
reap_stale_backups() {
  local path
  for path in "${SKILLS_DIR}"/*.bak "${COMMANDS_DIR}"/*.bak; do
    [[ -e "${path}" ]] || continue # unmatched glob
    log "removing stale backup: ${path}"
    rm -rf "${path}"
  done
}

# Deploy a single file, only when it differs.
#
# No .bak — see reap_stale_backups() above and the note at the top of the file.
deploy_file() {
  local src="$1"
  local dest="$2"
  if [[ ! -f "${src}" ]]; then
    log "WARNING: source not found: ${src}, skipping."
    return
  fi
  if [[ -f "${dest}" ]] && diff -q "${src}" "${dest}" &>/dev/null; then
    log "${dest}: already up-to-date."
    return
  fi
  log "${dest}: deploying..."
  cp "${src}" "${dest}"
}

# Deploy a skill directory, only when its contents differ.
# diff -rq compares the two trees recursively.
#
# No .bak — a backup here would register as a duplicate skill. See
# reap_stale_backups() above.
deploy_skill() {
  local src="$1"
  local dest="$2"
  local name
  name="$(basename "${dest}")"
  if [[ ! -d "${src}" ]]; then
    log "WARNING: source skill not found: ${src}, skipping."
    return
  fi
  if [[ -d "${dest}" ]] && diff -rq "${src}" "${dest}" &>/dev/null; then
    log "skill ${name}: already up-to-date."
    return
  fi
  log "skill ${name}: deploying..."
  rm -rf "${dest}"
  cp -a "${src}" "${dest}"
}

reap_stale_backups

deploy_skill "${SRC_DIR}/skills/engineering-team" "${SKILLS_DIR}/engineering-team"

deploy_file "${SRC_DIR}/commands/done.md"       "${COMMANDS_DIR}/done.md"
deploy_file "${SRC_DIR}/commands/merge-push.md" "${COMMANDS_DIR}/merge-push.md"
deploy_file "${SRC_DIR}/commands/prompt.md"     "${COMMANDS_DIR}/prompt.md"

log "Claude skills and commands deployed."
