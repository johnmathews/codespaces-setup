# engineering-team skill — rule-ownership drift-scan

A mechanical check over the `engineering-team` skill's **rule-ownership index**
(`configs/claude/skills/engineering-team/references/rule-ownership.md`). It answers
one question: **does the index still tell the truth about where each rule lives,
and have the guarded duplications drifted?**

The index maps each load-bearing invariant to its single canonical home so
restatements elsewhere are pointers, not competing sources. An index that lies
about where truth lives is worse than none — this is the scan that stops it lying,
and the mechanical half the index's own §5 promises.

## Why this one *is* in CI (unlike the other two `tests/` suites)

The [router probes](../engineering-team-probes/) and the
[triggering eval](../engineering-team-triggering/) are LLM-in-the-loop, so they run
on-demand. This scan is **pure text analysis — no model** — so it runs in headless
CI on every push and PR, alongside the skill gates. It still lives at repo level
rather than inside the skill for the same reason those do: its value is
skill-*editing*, not skill-*use*, so it must not deploy to `~/.claude`.

## What it checks

`drift_scan.py`, stdlib only. **HARD** checks exit non-zero; **WARN** checks print
and pass.

- **A. Worktree idiom (HARD).** Every `git rev-parse` referencing `--git-dir` or
  `--git-common-dir` *inside a bash block* must carry `--path-format=absolute` —
  dropping it is the exact bug the idiom guards (a path correct where computed,
  silently wrong after a `cd`). Prose that shows the flagless form to explain it is
  ignored. The `$RUN_DIR`-resolution one-liner must also be identical across every
  copy. This is what makes the SKILL.md ↔ worktree.md duplication *safe*. **Its
  corpus also includes the vendored slash commands** (`configs/claude/commands/*.md`
  — `/done`, `/merge-push`, `/prompt`), which carry their own copies of the idiom
  and ship on a separate track from the skill, so they'd otherwise be unguarded.
  (Checks B–D stay skill-scoped; only A spans the commands.)
- **B. Index homes resolve (HARD).** Every `` `<file>` §"Heading" `` home the index
  cites must resolve to a real heading in that file. Directly enforces "the index
  doesn't lie about where truth lives."
- **C. Signature at home (HARD).** Each curated invariant's signature phrase must
  still appear at its declared home file, so a home that lost its canonical
  statement reds.
- **D. Un-pointered restatement (WARN).** A curated signature appearing in a
  non-home file that never references the home is *reported*. Whether a restatement
  should have been a pointer is a judgement call, not a mechanical fault — so it
  warns, it doesn't fail (the skill's own "anything gameable is a warning" rule).

## Running it

```bash
python3 tests/engineering-team-drift/drift_scan.py            # scan; exit 1 on any HARD failure
python3 tests/engineering-team-drift/drift_scan.py --selftest # prove each check catches a seeded violation
```

CI runs both (`--selftest` first, then the scan) — see `.github/workflows/ci.yml`.

## Maintaining it

- **The curated `SIGNATURES` table is intentionally small** — the load-bearing
  cross-cutting invariants, not all ~50 in the index. Add an entry when the index
  gains a cross-cutting invariant worth guarding, with a signature phrase distinctive
  enough not to match by accident.
- **When you move a rule's home or rename a section**, update `rule-ownership.md`
  *and* re-run this scan — check B will red if the index now points at a heading
  that no longer exists, which is exactly the drift it exists to catch.
- **A new check ships with a seeded red test** in `--selftest`, per the skill's own
  rule that a gate tested only on clean input passes loudest when blind.
