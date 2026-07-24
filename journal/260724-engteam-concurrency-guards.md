# Concurrency guards: shared-singleton docs, stale-base pushes, and peer-session survey

**Date:** 2026-07-24. **PR:** feat/engteam-concurrency-guards. Implements a
design note (`engineering-skill-improvements.md`) that lived only in the deployed
`~/.claude` copy — three gaps found running the skill on a real project with two
independent sessions active at once. Point-in-time record; authoritative for
nothing.

The design note proposed three fixes (S1/S2/S3). The headline it stressed, and
that this change preserves: **worktrees worked** — file isolation was complete
across nine interleaved PRs, zero conflicts. Every gap is in coordinating state
worktrees genuinely cannot isolate. So nothing here touches the worktree
foundation. Each change was held to a bar the user set: *added complexity must be
paid for by reliability or efficiency.* Two proposals landed as written, one was
rejected as specified and rebuilt cheaper.

## S1 — shared-singleton docs (landed; `documentation-model.md` §9)

The problem is a `live-state`-style doc recording one global fact every merge
changes. Two sessions merging in parallel put it on a treadmill: whoever
refreshes it is stale the instant the other's merge deploys. Its `Covers:` is a
*runtime* fact that matches no path, so the change-driven freshness gate never
marks it due — which by the skill's own rule 1 is a check that cannot fail
wearing a status stamp. So this is not a new rule so much as an existing
invariant being violated. Homed the principle ("a shared-singleton doc has one
writer — automate from the source of truth or single-owner, never per-feature
sessions") in `documentation-model.md`, with the freshness-gate blind spot noted
at its own home in `worktree.md` "Documentation gates." Deliberately did **not**
mandate CI automation: under a strict merge ruleset it means a bot PR per deploy,
so it is recommended, not required.

## S2 — stale-base push guard (landed; `worktree.md`, and a diff-form bug fixed)

The one way concurrent sessions actively damage each other: a push whose tree is
missing what `origin/main` gained (`git reset --soft` on a stale ref, force-push,
rebase onto a stale base). It **deletes another session's merged files and every
check passes on the reverting tree.** The load-bearing fix is a habit — fetch,
then diff against a fresh `origin/main` before pushing.

**The design note's proposed diff form was wrong, and a reproduction caught it.**
It said `git diff --name-only origin/main...HEAD` (three-dot). Three-dot diffs
from the merge-base, so a file another session merged *after* your fork point is
invisible to it — exactly the file being reverted. Built the scenario (branch
from an old main; main then gains `newfile.py`; branch's tree lacks it):

- three-dot `origin/main...HEAD` → `M bar.py` only. **Misses the reversion.**
- two-endpoint `origin/main HEAD` → `M bar.py` **and `D newfile.py`.** Catches it.

So the rule ships as the two-endpoint form `git diff --name-status origin/main
HEAD | grep '^D'`. The `pre-push` hook ships as an *optional* backstop with its
reach documented honestly: it hard-blocks only a force-push that discards a
remote tip; the stale-base reversion trips only its advanced-base *warning*. So
the hook does not stop the motivating case on its own — the diff habit does.
Ranked rule-first, hook-second, and did not vendor the hook as an executable +
bash test into the skill (that is per-project scaffolding, not skill surface);
the "prove it goes red before relying on it" instruction carries the skill's own
gate standard into the recommendation.

## S3 — peer-session survey (rejected as specified; rebuilt cheaper; `multi-session.md` §11)

The note proposed a `.engineering-team/sessions/` registry: one file per session,
declared footprints, heartbeats, staleness heuristics, cleanup. Rejected as
specified — it failed the bar three ways: (1) by the note's own evidence
worktrees already prevented all *actual* damage, so the benefit is
efficiency-only and thinly evidenced; (2) an agent session is not a daemon, so
any heartbeat marks a live-but-idle session dead, and a registry that drifts
*lies*, which is worse than none; (3) it violates S1's own just-added rule — a
hand-maintained contended global.

The insight that replaced it: `git worktree list` **is** the peer registry —
authoritative, self-cleaning (a worktree exists exactly while its session lives),
and needs no heartbeat/footprint/cleanup. Confirmed on the live machine that
`gh pr list` was empty while four worktrees were active (this repo owner merges on
green immediately), so PRs are a weak signal and the survey leans on worktrees +
remote branches, deriving each footprint with a per-branch diff. Added a
read-only startup survey to the router's "Decide your role" and the full account
(including why not to build a registry) to `multi-session.md`.

## Enforcement

Each rule is homed once and pointed to elsewhere per `rule-ownership.md`; added an
index row for each (the drift-scan verifies every cited home heading resolves) and
three `SIGNATURES` entries to the drift-scan so a future edit that deletes a rule's
canonical statement reds. `drift_scan.py` selftest + real scan green (13
signatures, up from 10), alongside command-links, triggering, and the three skill
gates. The deployed `~/.claude` note is now implemented and will vanish on the
next deploy (`deploy-engineering-team-skill.sh` overwrites); this journal is its
provenance.
