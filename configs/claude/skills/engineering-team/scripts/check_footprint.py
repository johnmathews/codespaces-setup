#!/usr/bin/env python3
"""Footprint gate: did a diff stay inside the paths its plan units declared?

The pre-PR gate (`references/coordination-protocol.md` §3.3) always runs a
footprint check, the scope-creep guard. It is a string comparison: the files a
branch changed, against each unit's **Files (footprint):** field in the plan.
An agent used to do it. A script does it exactly, every time, at no cost, so
the check is this file and no model is involved.

What counts as inside a footprint entry:

- an exact path: `src/widget.py` matches only that file;
- a directory: `docs` or `docs/` matches everything under it;
- a glob: `*` and `?` stay inside one path segment, `**` crosses segments
  (`src/auth/**` matches `src/auth/a/b.py`; `tests/test_*.py` does not match
  `tests/sub/test_x.py`).

When the field uses backticks, only the backticked spans are paths, so a repo
name or a note beside a path is ignored. `{a,b}` expands as in a shell.

Several unit IDs may be given; their footprints are joined. A lane that ships
more than one unit in a PR is checked against all of them together.

The diff is `git diff --name-only --no-renames <base>...HEAD`, so it covers what
the branch committed since it left the base, and a rename counts as both the old
and the new path. Uncommitted edits are not in it: commit before running it.

Same two gate-design rules as the sibling gates:

1. A hard failure is unambiguous and mechanically fixable: a changed file no
   declared entry matches. Exit 1, and each such file is listed.
2. A footprint that cannot be checked is reported as that, never as a pass or a
   fail: a unit with no section, no footprint field, or a footprint written as
   prose ("the auth stuff"). Exit 2. A footprint of `none` declares that the
   unit touches nothing, so any changed file is outside it.

Stdlib only, like the sibling gates.

Usage:
    python3 check_footprint.py <run-dir | improvement-plan.md> W1 [W2 ...] \\
        [--repo <worktree>] [--base origin/main]
    python3 check_footprint.py --selftest

Exit status: 0 inside the footprint, 1 a file outside it, 2 cannot check.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
import tempfile

HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
# The field label needs its colon, inside or outside the bold:
# "- **Files (footprint):** a", "- **Footprint**: a", "Files: a".
FIELD_RE = re.compile(
    r"^\s*(?:[-*+]\s+)?[*_]*\s*(?:files(?:\s*\(footprint\))?|footprint)\s*[*_]*\s*:\s*[*_]*\s*(.*)$",
    re.IGNORECASE,
)
NEW_FIELD_RE = re.compile(r"^\s*[-*+]\s")
EMPTY_FOOTPRINTS = {"none", "—", "-", "n/a"}


class CannotCheck(Exception):
    """The footprint is missing or unreadable, so no verdict is possible."""


def unit_footprint(plan_text: str, unit: str) -> list[str]:
    """The entries of one unit's **Files (footprint):** field."""
    lines = plan_text.splitlines()
    start, level = None, 0
    for i, line in enumerate(lines):
        m = HEADING_RE.match(line)
        if m and re.match(rf"(?:[\d.]+\s+)?{re.escape(unit)}\b", m.group(2)):  # "W1 —" or "2.1 W1 —"
            start, level = i + 1, len(m.group(1))
            break
    if start is None:
        raise CannotCheck(f"{unit}: no section headed `{unit}` in the plan")
    end = len(lines)
    for j in range(start, len(lines)):
        m = HEADING_RE.match(lines[j])
        if m and len(m.group(1)) <= level:
            end = j
            break
    section = lines[start:end]
    for k, line in enumerate(section):
        m = FIELD_RE.match(line)
        if not m:
            continue
        value = m.group(1)
        for more in section[k + 1:]:  # a value wrapped onto indented lines
            if not more.strip() or NEW_FIELD_RE.match(more) or HEADING_RE.match(more):
                break
            value += " " + more.strip()
        return parse_entries(unit, value)
    raise CannotCheck(f"{unit}: no **Files (footprint):** field in its section")


def _split_outside_braces(value: str) -> list[str]:
    parts, depth, cur = [], 0, ""
    for ch in value:
        depth += (ch == "{") - (ch == "}")
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    return [*parts, cur]


def _expand_braces(entry: str) -> list[str]:
    m = re.search(r"\{([^{}]*)\}", entry)
    if not m:
        return [entry]
    head, tail = entry[: m.start()], entry[m.end():]
    return [x for alt in m.group(1).split(",") for x in _expand_braces(head + alt + tail)]


def parse_entries(unit: str, value: str) -> list[str]:
    """Paths from a footprint value. When the value uses backticks, only the
    backticked spans are paths, so `api `src/a.py` (new)` yields src/a.py."""
    spans = re.findall(r"`([^`]+)`", value)
    raw = spans if spans else _split_outside_braces(value)
    entries = [x.strip() for e in raw for x in _expand_braces(e.strip())]
    entries = [e for e in entries if e]
    if not entries:
        raise CannotCheck(f"{unit}: the footprint field is empty")
    if len(entries) == 1 and entries[0].lower() in EMPTY_FOOTPRINTS:
        return []
    prose = [e for e in entries if " " in e]
    if prose:
        raise CannotCheck(f"{unit}: footprint entry reads as prose, not a path: {prose[0]!r}")
    return entries


def _glob_regex(pattern: str) -> re.Pattern[str]:
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append(r"(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(r".*")
            i += 2
        elif pattern[i] == "*":
            out.append(r"[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append(r"[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("".join(out) + r"\Z")


def matches(entry: str, path: str) -> bool:
    entry = entry.removeprefix("./")
    if any(c in entry for c in "*?"):
        return bool(_glob_regex(entry).match(path))
    base = entry.rstrip("/")
    return path == base or path.startswith(base + "/")


def outside(footprint: list[str], files: list[str]) -> list[str]:
    return [f for f in files if not any(matches(e, f) for e in footprint)]


def changed_files(repo: pathlib.Path, base: str) -> list[str]:
    cmd = ["git", "-C", str(repo), "diff", "--name-only", "--no-renames", f"{base}...HEAD"]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        raise CannotCheck(f"git diff against {base} failed: {proc.stderr.strip()}")
    return [line for line in proc.stdout.splitlines() if line]


def _resolve(arg: str) -> pathlib.Path | None:
    p = pathlib.Path(arg)
    if p.is_dir() and (p / "improvement-plan.md").is_file():
        return p / "improvement-plan.md"
    if p.is_file():
        return p
    return None


def check(plan: pathlib.Path, units: list[str], repo: pathlib.Path, base: str) -> int:
    try:
        text = plan.read_text(encoding="utf-8")
        footprint = [e for u in units for e in unit_footprint(text, u)]
        files = changed_files(repo, base)
    except CannotCheck as exc:
        print(f"CANNOT CHECK: {exc}")
        return 2
    label = ", ".join(units)
    if not files:
        print(f"OK: no files changed since {base}; nothing to check for {label}")
        return 0
    stray = outside(footprint, files)
    for f in stray:
        print(f"ERROR outside footprint: {f}")
    if stray:
        print(f"\nFAIL: {len(stray)} of {len(files)} changed file(s) are outside the footprint of {label}")
        print(f"declared: {', '.join(footprint) or 'none'}")
        return 1
    print(f"OK: all {len(files)} changed file(s) are inside the footprint of {label}")
    return 0


PLAN = """---
plan: selftest
units:
  - id: W1
    title: One
  - id: W2
    title: Two
---

# Plan

## W1: One

- **Size:** S
- **Files (footprint):** `src/widget.py`, `docs/`,
  `tests/test_*.py`
- **Dependencies:** none

### W1 notes

Still part of W1.

## W2: Two

- **Files (footprint):** `src/auth/**`

## W3: Prose

- **Files (footprint):** the auth stuff

## W4: Nothing

- **Files (footprint):** none

## W5: No field

- **Size:** S
- Footprint check is a later concern.

## W6: Bold colon outside

- **Footprint**: `Makefile`

## 2.7 W7 — Numbered heading

- **Files (footprint):** sre-agent `src/a.py` (new), `roles/{x,y}/tasks/main.yml`
"""


def selftest() -> int:
    failed = 0

    def expect(cond: bool, msg: str) -> None:
        nonlocal failed
        print(("ok   " if cond else "FAIL ") + msg)
        failed += not cond

    expect(matches("src/widget.py", "src/widget.py"), "exact path matches itself")
    expect(not matches("src/widget.py", "src/widget.pyc"), "exact path is not a prefix")
    expect(matches("docs", "docs/a/b.md") and matches("docs/", "docs/a.md"), "directory matches what is under it")
    expect(not matches("docs", "docsite/a.md"), "directory match stops at a segment boundary")
    expect(matches("tests/test_*.py", "tests/test_x.py"), "* matches inside one segment")
    expect(not matches("tests/test_*.py", "tests/sub/test_x.py"), "* does not cross a segment")
    expect(matches("src/auth/**", "src/auth/a/b.py"), "** crosses segments")
    expect(matches("**/conftest.py", "conftest.py") and matches("**/conftest.py", "a/b/conftest.py"),
           "**/ matches zero or more directories")
    expect(matches("./src/widget.py", "src/widget.py"), "a leading ./ is ignored")

    w1 = unit_footprint(PLAN, "W1")
    expect(w1 == ["src/widget.py", "docs/", "tests/test_*.py"], f"W1 footprint parsed, wrapped line included: {w1}")
    expect(unit_footprint(PLAN, "W2") == ["src/auth/**"], "W2 footprint parsed")
    expect(unit_footprint(PLAN, "W4") == [], "`none` is an empty footprint")
    expect(unit_footprint(PLAN, "W6") == ["Makefile"], "label with the colon outside the bold parsed")
    w7 = unit_footprint(PLAN, "W7")
    expect(w7 == ["src/a.py", "roles/x/tasks/main.yml", "roles/y/tasks/main.yml"],
           f"numbered heading, text beside backticks ignored, braces expanded: {w7}")
    for unit, why in (("W3", "prose"), ("W5", "no field"), ("W9", "no section")):
        try:
            unit_footprint(PLAN, unit)
            expect(False, f"{unit} ({why}) raises CannotCheck")
        except CannotCheck:
            expect(True, f"{unit} ({why}) raises CannotCheck")
    expect(outside([], ["a.py"]) == ["a.py"], "an empty footprint leaves every file outside")

    with tempfile.TemporaryDirectory() as tmp:
        repo = pathlib.Path(tmp) / "repo"
        repo.mkdir()
        plan = pathlib.Path(tmp) / "improvement-plan.md"
        plan.write_text(PLAN, encoding="utf-8")

        def git(*args: str) -> None:
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t",
                            "-c", "commit.gpgsign=false", *args], check=True, capture_output=True)

        def write(rel: str) -> None:
            p = repo / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(rel, encoding="utf-8")

        git("init", "-q", "-b", "base")
        write("README.md")
        write("src/old.py")
        git("add", "-A")
        git("commit", "-q", "-m", "base")
        git("checkout", "-q", "-b", "work")
        expect(check(plan, ["W1"], repo, "base") == 0, "no changes: exit 0")
        write("src/widget.py")
        write("docs/guide.md")
        git("add", "-A")
        git("commit", "-q", "-m", "inside")
        expect(check(plan, ["W1"], repo, "base") == 0, "changes inside W1: exit 0")
        write("src/auth/token.py")
        git("add", "-A")
        git("commit", "-q", "-m", "auth")
        expect(check(plan, ["W1"], repo, "base") == 1, "a W2 file against W1 alone: exit 1")
        expect(check(plan, ["W1", "W2"], repo, "base") == 0, "W1 + W2 joined: exit 0")
        git("mv", "src/old.py", "src/widget_old.py")
        git("commit", "-q", "-m", "rename")
        expect(check(plan, ["W1", "W2"], repo, "base") == 1, "a rename counts its old path: exit 1")
        expect(check(plan, ["W3"], repo, "base") == 2, "prose footprint: exit 2")
        expect(check(plan, ["W1"], repo, "no-such-ref") == 2, "unknown base: exit 2")

    print()
    if failed:
        print(f"FAIL: {failed} selftest case(s) did not behave as specified")
        return 1
    print("OK: every selftest case behaves as specified")
    return 0


def main(argv: list[str]) -> int:
    if argv[1:] == ["--selftest"]:
        return selftest()
    ap = argparse.ArgumentParser(description="Check a branch's diff against plan unit footprints.")
    ap.add_argument("plan", help="run dir, or a path to improvement-plan.md")
    ap.add_argument("units", nargs="+", help="unit IDs whose footprints the diff must stay inside")
    ap.add_argument("--repo", default=".", help="the worktree whose branch is checked (default: .)")
    ap.add_argument("--base", default="origin/main", help="the ref the branch is compared with (default: origin/main)")
    args = ap.parse_args(argv[1:])
    plan = _resolve(args.plan)
    if plan is None:
        print(f"CANNOT CHECK: no improvement-plan.md at {args.plan}")
        return 2
    return check(plan, args.units, pathlib.Path(args.repo), args.base)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
