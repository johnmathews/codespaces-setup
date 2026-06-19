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
#
# Idempotent: a skill dir / command file is only (re)written when it differs
# from what is already on disk, backing up any changed target to .bak first
# (same convention as 11-dotfiles.sh).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${REPO_DIR}/configs/claude"

log() { echo "[claude-skills] $*"; }

CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
COMMANDS_DIR="${CLAUDE_DIR}/commands"
mkdir -p "${SKILLS_DIR}" "${COMMANDS_DIR}"

# Deploy a single file, only when it differs; back up a changed target to .bak.
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
  if [[ -f "${dest}" ]]; then
    log "${dest}: updating (backup at ${dest}.bak)..."
    cp "${dest}" "${dest}.bak"
  else
    log "${dest}: deploying..."
  fi
  cp "${src}" "${dest}"
}

# Deploy a skill directory, only when its contents differ; back up a changed
# target tree to .bak. diff -rq compares the two trees recursively.
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
  if [[ -d "${dest}" ]]; then
    log "skill ${name}: updating (backup at ${dest}.bak)..."
    rm -rf "${dest}.bak"
    cp -a "${dest}" "${dest}.bak"
    rm -rf "${dest}"
  else
    log "skill ${name}: deploying..."
  fi
  cp -a "${src}" "${dest}"
}

deploy_skill "${SRC_DIR}/skills/engineering-team" "${SKILLS_DIR}/engineering-team"

deploy_file "${SRC_DIR}/commands/done.md"       "${COMMANDS_DIR}/done.md"
deploy_file "${SRC_DIR}/commands/merge-push.md" "${COMMANDS_DIR}/merge-push.md"

log "Claude skills and commands deployed."
