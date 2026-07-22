#!/usr/bin/env python3
"""Link-check for the vendored slash commands' cross-references into the skill.

The `/done` and `/merge-push` commands (`configs/claude/commands/*.md`) reach into
the engineering-team skill by hardcoded path — e.g. `/done` cites
`references/documentation-model.md` (the six-type doc model) and both cite
`references/worktree.md`. Those files ship separately from the commands (the skill
tree vs `commands/`), so a rename or move inside the skill silently strands the
pointer: the command keeps telling every Codespace to read a file that no longer
exists, and nothing catches it. The skill's own rule-ownership drift-scan
(`tests/engineering-team-drift/`) guards references *within* the skill; its scope
stops at the skill boundary, so the commands' inbound links are unguarded. This is
that missing guard.

Check (HARD = non-zero exit): every skill-relative path a command file names —
any `<subdir>/….md` whose first segment is a real top-level skill subdir, or a
bare `SKILL.md`, with or without the deployed `~/.claude/skills/engineering-team/`
prefix — must resolve to a real file under the skill tree.

Like the drift-scan, this lives at repo level (its value is editing these assets,
not using them) and is fully headless, so it runs the real check in CI. Stdlib only.

Usage:
    python3 check_command_links.py            # check the real commands; exit 1 on any dangling ref
    python3 check_command_links.py --selftest # prove the check catches a seeded dangling ref
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SKILL = REPO / "configs/claude/skills/engineering-team"
COMMANDS = REPO / "configs/claude/commands"
DEPLOYED_PREFIX = "~/.claude/skills/engineering-team/"


def skill_subdirs(skill: Path) -> list[str]:
    """Top-level subdirectories of the skill (references, templates, phases, scripts…).
    Discovered, not hardcoded, so a new skill subdir is link-checked automatically."""
    return sorted(p.name for p in skill.iterdir() if p.is_dir() and not p.name.startswith("."))


def ref_pattern(skill: Path) -> re.Pattern[str]:
    """Match a skill-relative path a command may cite: `<subdir>/….md` for a real
    skill subdir, or a bare `SKILL.md`, optionally carrying the deployed prefix.
    Anchoring on real subdir names keeps project docs (`docs/foo.md`) out — those
    aren't skill cross-references."""
    subdirs = "|".join(re.escape(d) for d in skill_subdirs(skill))
    return re.compile(
        r"(?:~/\.claude/skills/engineering-team/)?"
        r"((?:" + subdirs + r")/[A-Za-z0-9_./-]+\.md|SKILL\.md)"
    )


def extract_refs(text: str, pat: re.Pattern[str]) -> list[tuple[str, int]]:
    """Return (skill-relative path, lineno) for each skill file the text cites."""
    out: list[tuple[str, int]] = []
    for i, ln in enumerate(text.splitlines(), 1):
        for m in pat.finditer(ln):
            out.append((m.group(1), i))
    return out


def check_command_links(skill: Path, commands: Path) -> list[str]:
    """One HARD failure string per dangling cross-reference. Empty = all resolve."""
    pat = ref_pattern(skill)
    failures: list[str] = []
    for cmd in sorted(commands.glob("*.md")):
        for rel, lineno in extract_refs(cmd.read_text(), pat):
            if not (skill / rel).is_file():
                failures.append(
                    f"{cmd.name}:{lineno}: cross-reference `{rel}` does not resolve "
                    f"under the skill ({DEPLOYED_PREFIX}{rel})"
                )
    return failures


def selftest() -> int:
    """Prove the check catches a dangling ref and passes a real one, against a
    temporary command dir so it never depends on the real commands' contents."""
    fails: list[str] = []

    def expect(cond: bool, msg: str) -> None:
        if not cond:
            fails.append(msg)

    pat = ref_pattern(SKILL)

    # A real skill file the commands actually cite must resolve.
    good = "See references/worktree.md and ~/.claude/skills/engineering-team/references/documentation-model.md"
    refs = extract_refs(good, pat)
    expect({r for r, _ in refs} == {"references/worktree.md", "references/documentation-model.md"},
           f"extractor missed/added refs: {refs}")
    expect(all((SKILL / r).is_file() for r, _ in refs), "real refs did not resolve")

    # A dangling ref must be caught; a project doc that isn't a skill path must be ignored.
    bad = "Read references/does-not-exist.md for details. Also see docs/roadmap.md."
    bad_refs = extract_refs(bad, pat)
    expect({r for r, _ in bad_refs} == {"references/does-not-exist.md"},
           f"extractor should match only the skill path, got: {bad_refs}")
    expect(not (SKILL / "references/does-not-exist.md").is_file(), "seed file unexpectedly exists")

    # End-to-end: a temp command with a dangling ref reds; the real commands are clean.
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        (Path(td) / "bogus.md").write_text("Read references/does-not-exist.md now.\n")
        expect(bool(check_command_links(SKILL, Path(td))), "end-to-end dangling ref not caught")
    expect(not check_command_links(SKILL, COMMANDS),
           f"real commands have dangling refs: {check_command_links(SKILL, COMMANDS)}")

    if fails:
        print("COMMAND-LINK SELFTEST FAILED:", file=sys.stderr)
        for f in fails:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print("command-link selftest OK (dangling ref seeded red, real refs resolve)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--selftest", action="store_true",
                    help="seed a dangling reference and prove detection")
    args = ap.parse_args()
    if args.selftest:
        return selftest()

    failures = check_command_links(SKILL, COMMANDS)
    for f in failures:
        print(f"[FAIL] {f}", file=sys.stderr)
    if failures:
        print(f"\ncommand-link check: {len(failures)} dangling reference(s)", file=sys.stderr)
        return 1
    print("command-link check OK (all command→skill cross-references resolve)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
