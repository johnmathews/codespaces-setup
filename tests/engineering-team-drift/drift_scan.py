#!/usr/bin/env python3
"""Drift-scan for the engineering-team skill's rule-ownership invariants.

The skill restates load-bearing rules across ~13 files; `references/rule-ownership.md`
maps each to its canonical home. This scan mechanically enforces the parts of that
map that are unambiguous, so the index can't silently lie and a duplicated command
can't silently lose a flag. It is the mechanical half the index's §5 promises.

Checks (HARD = non-zero exit; WARN = printed, exit 0):

  A. Worktree idiom (HARD). Every `git rev-parse` referencing `--git-dir` or
     `--git-common-dir` *inside a bash code block* must carry
     `--path-format=absolute` — dropping it is the exact bug the idiom guards
     (a path correct where computed, silently wrong after a `cd`). Prose that
     shows the flagless anti-pattern to explain it is fine; only runnable command
     lines are checked. The `$RUN_DIR`-resolution one-liner must also be identical
     across every copy. This check's corpus spans the skill docs AND the vendored
     slash commands (`configs/claude/commands/*.md`): `/done`, `/merge-push`, and
     `/prompt` carry their own copies of the idiom and the one-liner, and ship on a
     separate deploy track, so they'd otherwise be unguarded. (B/C/D are about the
     skill's own rule-ownership index and stay skill-scoped.)
  B. Index homes resolve (HARD). Every `<file> §"Heading"` home that
     rule-ownership.md cites must resolve to a real heading in that file. This is
     the "the index doesn't lie about where truth lives" check.
  C. Signature at home (HARD). Each curated invariant's signature phrase must
     still appear at its declared home file — so a home that lost its canonical
     statement reds.
  D. Un-pointered restatement (WARN). A curated signature appearing in a non-home
     file that never references the home file is *reported* — a restatement that
     should be a pointer is a judgement call, not a mechanical fault.

This lives at repo level (not inside the skill): its value is skill-editing, not
skill-use, so it must not deploy to `~/.claude`. But unlike the probe/triggering
tests it is fully headless, so it runs in CI. Stdlib only.

Usage:
    python3 drift_scan.py            # scan the real skill; exit 1 on any HARD failure
    python3 drift_scan.py --selftest # prove each check catches a seeded violation
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SKILL = REPO / "configs/claude/skills/engineering-team"
INDEX = SKILL / "references/rule-ownership.md"
COMMANDS = REPO / "configs/claude/commands"

# Curated invariants: name -> (home file relative to SKILL, signature regex that
# must appear at the home). Kept small and load-bearing on purpose; extend it when
# rule-ownership.md gains a cross-cutting invariant worth guarding.
SIGNATURES: dict[str, tuple[str, str]] = {
    "claim-not-stronger-than-check": ("references/general-guidelines.md",
                                      r"claim may not be stronger than the check"),
    "status-stamp-method-matches": ("references/documentation-model.md",
                                    r"method must match the kind of claim"),
    "single-writer": ("references/multi-session.md", r"one artifact, one writer"),
    "worktree-idiom": ("references/worktree.md", r"--path-format=absolute"),
    "run-dir-main-checkout": ("SKILL.md",
                              r"\$RUN_DIR.{0,40}main checkout.{0,40}never|"
                              r"\$RUN_DIR.{0,40}never.{0,40}main checkout"),
    "evidence-grading": ("references/general-guidelines.md",
                         r"\[VERIFIED\].{0,80}\[SUPPORTED\].{0,80}\[SUSPECTED\]"),
    "findings-contract": ("references/team-structure.md", r"findings contract"),
    "closing-a-run": ("SKILL.md", r"Closing a run"),
    "heading-numbering": ("references/documentation-model.md", r"Heading numbering"),
    "announce-the-phase": ("SKILL.md", r"Announce phase transitions"),
    "messages-carry-no-state": ("references/coordination-protocol.md",
                                r"Every message carries a `ref`"),
    "no-assign-message": ("references/coordination-protocol.md",
                          r"No message type in the protocol can assign work"),
    "sense-dont-act": ("references/coordination-protocol.md",
                       r"(?i)sense autonomously; act only on request"),
}


class Finding:
    def __init__(self, hard: bool, check: str, msg: str) -> None:
        self.hard, self.check, self.msg = hard, check, msg

    def __str__(self) -> str:
        return f"[{'FAIL' if self.hard else 'warn'}] {self.check}: {self.msg}"


# ---- helpers ---------------------------------------------------------------

def skill_docs() -> dict[str, str]:
    """All skill prose markdown, keyed by SKILL-relative path. Excludes scripts/
    (gate code + fixtures) and design/ (design documents) — neither is rule prose.

    design/ matters specifically: a design doc argues *about* the rules and quotes
    their signature phrases verbatim, so including it would make every such doc
    self-report as a restatement of the rule it documents."""
    out: dict[str, str] = {}
    for p in sorted(SKILL.rglob("*.md")):
        rel = p.relative_to(SKILL).as_posix()
        if rel.startswith(("scripts/", "design/")):
            continue
        out[rel] = p.read_text()
    return out


def command_docs() -> dict[str, str]:
    """The vendored slash commands, keyed by `commands/<name>`. They carry their own
    copies of the worktree idiom + $RUN_DIR one-liner, so they join check A's corpus
    (only) — the commands ship separately from the skill and are otherwise unguarded."""
    out: dict[str, str] = {}
    if COMMANDS.is_dir():
        for p in sorted(COMMANDS.glob("*.md")):
            out[f"commands/{p.name}"] = p.read_text()
    return out


def bash_block_lines(text: str) -> list[str]:
    """Lines inside ```bash / ```sh fenced blocks (the runnable commands)."""
    lines, inside, out = text.splitlines(), False, []
    for ln in lines:
        stripped = ln.strip()
        if stripped.startswith("```"):
            fence = stripped[3:].strip().lower()
            inside = fence in ("bash", "sh", "shell") if not inside else False
            continue
        if inside:
            out.append(ln)
    return out


def join_continuations(lines: list[str]) -> list[str]:
    """Fold `\\`-continued shell lines into one logical line, so a `git rev-parse`
    wrapped across a line break is still seen as a single invocation."""
    out: list[str] = []
    buf = ""
    for ln in lines:
        if ln.rstrip().endswith("\\"):
            buf += ln.rstrip()[:-1] + " "
        else:
            out.append(buf + ln)
            buf = ""
    if buf:
        out.append(buf)
    return out


def headings(text: str) -> list[str]:
    """Markdown headings, skipping `#` lines inside fenced code blocks (bash
    comments, shebangs) so they can't masquerade as headings."""
    out, inside = [], False
    for ln in text.splitlines():
        if ln.strip().startswith("```"):
            inside = not inside
            continue
        if not inside and ln.lstrip().startswith("#"):
            out.append(ln.lstrip("#").strip())
    return out


# ---- check A: worktree idiom ----------------------------------------------

# One `git rev-parse` invocation: from the command up to the closing `)` or
# end of the logical line. Checked per-invocation, not per-line, so a detection
# idiom with TWO rev-parse calls is validated separately for each — a flag
# dropped on only one side is still caught.
_GITREV_CALL = re.compile(r"git rev-parse[^)]*")
_GITDIR = re.compile(r"--git-(?:common-)?dir\b")
_RUNDIR = re.compile(r'MAIN_CHECKOUT="\$\(dirname')


def check_worktree_idiom(docs: dict[str, str]) -> list[Finding]:
    findings: list[Finding] = []
    rundir_variants: dict[str, list[str]] = {}
    for rel, text in docs.items():
        for lline in join_continuations(bash_block_lines(text)):
            for call in _GITREV_CALL.findall(lline):
                if _GITDIR.search(call) and "--path-format=absolute" not in call:
                    findings.append(Finding(
                        True, "worktree-idiom",
                        f"{rel}: `git rev-parse` with --git-dir/--git-common-dir but no "
                        f"--path-format=absolute: {call.strip()}"))
            if _RUNDIR.search(lline):
                rundir_variants.setdefault(lline.strip(), []).append(rel)
    if len(rundir_variants) > 1:
        variants = "; ".join(f"{v!r} in {files}" for v, files in rundir_variants.items())
        findings.append(Finding(
            True, "worktree-idiom",
            f"$RUN_DIR resolution one-liner is not identical across copies: {variants}"))
    return findings


# ---- check B: index home citations resolve --------------------------------

_HOMED_IN = re.compile(r"^#{2,4}\s+Homed in\s+`([^`]+)`")
_FILE_TOKEN = re.compile(r"`([A-Za-z0-9_./-]+\.md)`|\b(SKILL\.md)\b")
_CITATION = re.compile(r'§\s*\d*\s*"([^"]+)"')


def parse_home_citations(index_text: str) -> list[tuple[str, str, int]]:
    """Return (file, heading, lineno) for each `<file> §"Heading"` the index cites.

    The file is the token on the same line, else the current "### Homed in `file`"
    group. Only quoted-heading citations are resolvable, so only those are returned.
    """
    out: list[tuple[str, str, int]] = []
    group: str | None = None
    for i, ln in enumerate(index_text.splitlines(), 1):
        m = _HOMED_IN.match(ln)
        if m:
            group = m.group(1)
            continue
        for cm in _CITATION.finditer(ln):
            heading = cm.group(1)
            # Scope the file-token search to the current table cell (text after
            # the last `|`), so a filename mentioned in another cell of the same
            # row can't be mis-attributed as this citation's home. Falls back to
            # the whole preceding text for non-table prose (no `|`).
            before = ln[:cm.start()]
            cell = before[before.rfind("|") + 1:]
            files = _FILE_TOKEN.findall(cell)
            file = None
            if files:
                last = files[-1]
                file = last[0] or last[1]
            file = file or group
            if file:
                out.append((file, heading, i))
    return out


def resolve_skill_file(file: str, skill: Path) -> Path | None:
    """Resolve a cited file to a real skill doc. The index cites by full relative
    path (`references/foo.md`) or bare basename (`foo.md`, `SKILL.md`); both are
    valid because skill basenames are unique. Ambiguous → None (a real fault)."""
    direct = skill / file
    if direct.is_file():
        return direct
    matches = [q for q in skill.rglob(Path(file).name)
               if q.is_file() and not q.relative_to(skill).as_posix().startswith("scripts/")]
    return matches[0] if len(matches) == 1 else None


def check_index_homes(index_text: str, skill: Path) -> list[Finding]:
    findings: list[Finding] = []
    for file, heading, lineno in parse_home_citations(index_text):
        target = resolve_skill_file(file, skill)
        if target is None:
            findings.append(Finding(True, "index-home",
                                    f"line {lineno}: cited home file `{file}` does not resolve"))
            continue
        # The index abbreviates long headings with a trailing ellipsis
        # (§"Grade every finding…"); match on the stem.
        stem = re.sub(r"[.…\s]+$", "", heading)
        if not any(stem in h for h in headings(target.read_text())):
            findings.append(Finding(
                True, "index-home",
                f'line {lineno}: `{file}` has no heading matching §"{heading}"'))
    return findings


# ---- check C: signature still at its home ---------------------------------

def check_signatures_at_home(docs: dict[str, str]) -> list[Finding]:
    findings: list[Finding] = []
    for name, (home, sig) in SIGNATURES.items():
        text = docs.get(home)
        if text is None:
            findings.append(Finding(True, "signature-home",
                                    f"{name}: home file {home} not found"))
        elif not re.search(sig, text, re.DOTALL):
            findings.append(Finding(True, "signature-home",
                                    f"{name}: signature /{sig}/ missing from its home {home}"))
    return findings


# ---- check D: un-pointered restatement (warn) -----------------------------

def check_restatements(docs: dict[str, str]) -> list[Finding]:
    findings: list[Finding] = []
    for name, (home, sig) in SIGNATURES.items():
        home_base = Path(home).name
        for rel, text in docs.items():
            if rel == home:
                continue
            if re.search(sig, text, re.DOTALL) and home_base not in text and home not in text:
                findings.append(Finding(
                    False, "restatement",
                    f"{name}: {rel} matches the signature but never references its "
                    f"home {home} — restatement that should point home?"))
    return findings


# ---- driver ----------------------------------------------------------------

def scan() -> list[Finding]:
    docs = skill_docs()
    # Check A spans the vendored commands too (they carry their own idiom copies and
    # ship separately, so they'd otherwise be unguarded); B/C/D stay skill-scoped.
    findings = check_worktree_idiom({**docs, **command_docs()})
    findings += check_index_homes(INDEX.read_text(), SKILL)
    findings += check_signatures_at_home(docs)
    findings += check_restatements(docs)
    return findings


def selftest() -> int:
    """Prove each HARD check catches a seeded violation and passes clean input."""
    fails: list[str] = []

    def expect(cond: bool, msg: str) -> None:
        if not cond:
            fails.append(msg)

    # A: flagless command must be caught; flagged must pass.
    bad = {"x.md": "```bash\nX=$(git rev-parse --git-common-dir)\n```"}
    good = {"x.md": "```bash\nX=$(git rev-parse --path-format=absolute --git-common-dir)\n```"}
    expect(any(f.check == "worktree-idiom" for f in check_worktree_idiom(bad)),
           "A: flagless git rev-parse not caught")
    expect(not check_worktree_idiom(good), "A: flagged command false-flagged")
    # A: prose (outside a bash block) showing the flagless form must NOT be caught.
    prose = {"x.md": "Without it, `git rev-parse --git-common-dir` returns a relative path."}
    expect(not check_worktree_idiom(prose), "A: prose anti-pattern false-flagged")
    # A: divergent $RUN_DIR one-liner across files must be caught.
    diverge = {
        "a.md": '```bash\nMAIN_CHECKOUT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"\n```',
        "b.md": '```bash\nMAIN_CHECKOUT="$(dirname "$(git rev-parse --git-common-dir)")"\n```',
    }
    expect(any("identical" in f.msg for f in check_worktree_idiom(diverge)),
           "A: divergent $RUN_DIR one-liner not caught")
    # A (review #2): a `\`-continued invocation missing the flag must be caught,
    # and a flag on only ONE of two rev-parse calls on a line must be caught.
    cont_bad = {"x.md": "```bash\nDIR=$(git rev-parse \\\n  --git-common-dir)\n```"}
    expect(any(f.check == "worktree-idiom" for f in check_worktree_idiom(cont_bad)),
           "A: continued flagless invocation not caught")
    cont_ok = {"x.md": "```bash\nDIR=$(git rev-parse --path-format=absolute \\\n  --git-common-dir)\n```"}
    expect(not check_worktree_idiom(cont_ok), "A: continued flagged invocation false-flagged")
    one_side = {"x.md": '```bash\n[ "$(git rev-parse --path-format=absolute --git-dir)" '
                        '!= "$(git rev-parse --git-common-dir)" ]\n```'}
    expect(any(f.check == "worktree-idiom" for f in check_worktree_idiom(one_side)),
           "A: flag on only one of two rev-parse calls not caught")

    # A (command corpus): the vendored commands must actually be in check A's corpus
    # (else the widening is inert), and their real idiom copies must be clean.
    cmds = command_docs()
    expect("commands/done.md" in cmds and "commands/merge-push.md" in cmds,
           "A: command corpus does not include the vendored commands")
    expect(not check_worktree_idiom(cmds),
           f"A: a real command copy of the idiom is flagless: {check_worktree_idiom(cmds)}")

    # design/ holds design docs, not rule prose: it must not enter the corpus,
    # or a design doc quoting a signature phrase self-reports as a restatement.
    docs = skill_docs()
    if any(rel.startswith("design/") for rel in docs):
        fails.append("skill_docs() must exclude design/ (design docs are not rule prose)")

    # B: a citation to a missing heading must be caught; a real one must pass.
    idx_bad = '### Homed in `SKILL.md`\n| rule | §"No Such Heading Here" | x |'
    idx_good = '### Homed in `SKILL.md`\n| rule | §"Closing a run" | x |'
    expect(any(f.check == "index-home" for f in check_index_homes(idx_bad, SKILL)),
           "B: dangling home citation not caught")
    expect(not check_index_homes(idx_good, SKILL), "B: valid home citation false-flagged")
    # B (review #1): a file token in a DIFFERENT cell of the row must not override
    # the `### Homed in` group fallback ("Verification integrity" lives in the group).
    idx_crosscell = ('### Homed in `general-guidelines.md`\n'
                     '| see `worktree.md` for context | §"Verification integrity" | x |')
    expect(not check_index_homes(idx_crosscell, SKILL),
           "B: cross-cell file token overrode the group (false red)")
    # B (review #4): a `#` comment inside a bash block must not count as a heading.
    hs = headings("```bash\n# not a heading\n```\n\n## Real Heading")
    expect("Real Heading" in hs and not any("not a heading" in h for h in hs),
           "B: bash-block comment leaked into headings()")

    # C: a home missing its signature must be caught; present must pass.
    expect(any(f.check == "signature-home"
               for f in check_signatures_at_home({"SKILL.md": "nothing here"})),
           "C: missing signature not caught")
    clean: dict[str, str] = {}
    for _name, (home, sig) in SIGNATURES.items():  # accumulate: a home may own several
        clean[home] = clean.get(home, "") + "\n" + _sig_literal(sig)
    expect(not check_signatures_at_home(clean), "C: present signatures false-flagged")
    # C (review #3): unrelated 'main checkout ... never' prose (branch policy) must
    # NOT satisfy the run-dir signature — dropping the real $RUN_DIR statement reds.
    rundir_sig = SIGNATURES["run-dir-main-checkout"][1]
    spoofed = dict(clean)
    spoofed["SKILL.md"] = (clean["SKILL.md"].replace(_sig_literal(rundir_sig), "")
                           + "\nnot in the project's main checkout, and never on `main`")
    expect(any("run-dir-main-checkout" in f.msg for f in check_signatures_at_home(spoofed)),
           "C: unrelated 'main checkout...never' masked a missing $RUN_DIR statement")

    # D (warn): a non-home file matching a signature without referencing the home
    # must warn; one that references the home must not. Proves D is not inert.
    unpointed = dict(clean)
    unpointed["phases/rogue.md"] = "we enforce one artifact, one writer here"  # no multi-session ref
    d = [f for f in check_restatements(unpointed) if not f.hard]
    expect(any("rogue.md" in f.msg for f in d), "D: un-pointered restatement not warned")
    pointed = dict(clean)
    pointed["phases/ok.md"] = "one artifact, one writer — see references/multi-session.md"
    expect(not any("ok.md" in f.msg for f in check_restatements(pointed)),
           "D: pointer to home false-warned")

    if fails:
        print("DRIFT-SCAN SELFTEST FAILED:", file=sys.stderr)
        for f in fails:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print(f"drift-scan selftest OK ({len(SIGNATURES)} signatures; A/B/C seeded red, D warns)")
    return 0


def _sig_literal(sig: str) -> str:
    """A minimal string that satisfies a curated signature regex, for the selftest."""
    samples = {
        r"\[VERIFIED\].{0,80}\[SUPPORTED\].{0,80}\[SUSPECTED\]": "[VERIFIED] [SUPPORTED] [SUSPECTED]",
        r"\$RUN_DIR.{0,40}main checkout.{0,40}never|"
        r"\$RUN_DIR.{0,40}never.{0,40}main checkout": "$RUN_DIR lives in the main checkout, never in a worktree",
    }
    return samples.get(sig, sig.replace("\\", ""))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--selftest", action="store_true", help="seed violations and prove detection")
    args = ap.parse_args()
    if args.selftest:
        return selftest()

    findings = scan()
    hard = [f for f in findings if f.hard]
    warn = [f for f in findings if not f.hard]
    for f in findings:
        print(f, file=sys.stderr if f.hard else sys.stdout)
    if hard:
        print(f"\ndrift-scan: {len(hard)} FAIL, {len(warn)} warn", file=sys.stderr)
        return 1
    print(f"drift-scan OK ({len(warn)} warning{'s' if len(warn) != 1 else ''}, no failures)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
