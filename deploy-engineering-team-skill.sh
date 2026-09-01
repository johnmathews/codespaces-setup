#!/usr/bin/env bash
# Deploy THIS repo's engineering-team skill over the local ~/.claude copy.
#
# A focused convenience wrapper for the common inner-loop task: you edited the
# skill in configs/claude/skills/engineering-team/ and want that version live in
# ~/.claude/skills/ right now, overwriting whatever is there. This repo is the
# source of truth for the skill (see CLAUDE.md), so the copy is one-directional:
# repo -> ~/.claude, never the reverse.
#
# This is deliberately NOT scripts/17-claude-skills.sh:
#   - 17-claude-skills.sh runs as part of `bash setup.sh`, also deploys the
#     slash commands, and SKIPS when the trees already match (diff -rq).
#   - This script does one thing — the engineering-team skill — and overwrites
#     UNCONDITIONALLY, so `git checkout` a change then re-run and you know the
#     bytes on disk are exactly the repo's, no diff-guessing.
#
# NO .bak — same reason 17-claude-skills.sh refuses one: ~/.claude/skills/ is
# scanned, so a backup dir registers as a duplicate skill rather than sitting
# inertly beside the original. The previous version is a `git show` away anyway.
#
# Usage: bash deploy-engineering-team-skill.sh

set -euo pipefail

log() { echo "[deploy-engteam] $*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${REPO_DIR}/configs/claude/skills/engineering-team"
DEST="${HOME}/.claude/skills/engineering-team"

if [[ ! -d "${SRC}" || ! -f "${SRC}/SKILL.md" ]]; then
  log "ERROR: no engineering-team skill at ${SRC} (missing SKILL.md?). Aborting."
  exit 1
fi

mkdir -p "$(dirname "${DEST}")"

log "source: ${SRC}"
log "dest:   ${DEST}"
rm -rf "${DEST}"
cp -a "${SRC}" "${DEST}" # -a preserves the subdirs (phases/, scripts/, templates/) and modes
log "deployed. ~/.claude/skills/engineering-team now matches this repo."
