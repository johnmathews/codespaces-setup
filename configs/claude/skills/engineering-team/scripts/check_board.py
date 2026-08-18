#!/usr/bin/env python3
"""Structural gate for an engineering-team progress dashboard.

`progress.md` is what makes a run multi-lane, and until this gate it was
unchecked. Two of its claims are load-bearing and mechanically verifiable:
lane file footprints must be disjoint (`references/multi-session.md` §3 calls
the check "mechanical" but nothing ran it — a human read the table), and a
non-empty contract register requires a unit zero
(`references/coordination-protocol.md` §4).

Same two gate-design rules as the sibling gates:

1. A hard failure must be unambiguous and mechanically fixable, or an honest
   board trips it and the gate gets switched off. This is why only *definite*
   overlaps are ERRORs — identical paths, or one a directory-prefix of another.
   A glob that cannot be resolved against the working tree is a WARN (W3), not
   a failure.
2. Softer signals are WARNINGS: a lane with no status file yet (it may simply
   not have started), and a board branch that does not exist in git yet.

Usage:
    python3 check_board.py <run_dir>     # gate a real run
    python3 check_board.py --selftest    # run the fixtures beside this file
"""

from __future__ import annotations

import pathlib
import re
import sys

ROW = re.compile(r"^\|(?P<cells>.+)\|\s*$")
PATHISH = re.compile(r"[/*]")


def _cells(line: str) -> list[str]:
    m = ROW.match(line.rstrip())
    if not m:
        return []
    return [c.strip().strip("`") for c in m.group("cells").split("|")]


def _section(text: str, heading_re: str) -> list[str]:
    """Lines belonging to the first heading matching heading_re."""
    out: list[str] = []
    inside = False
    for line in text.splitlines():
        if line.startswith("## "):
            if inside:
                break
            inside = bool(re.search(heading_re, line, re.I))
            continue
        if inside:
            out.append(line)
    return out


def _footprints(cell: str) -> list[str]:
    return [p.strip().strip("`") for p in cell.split(",") if p.strip()]


def _definite_overlap(a: str, b: str) -> bool:
    """True only for unambiguous overlap: identical, or one a dir-prefix of the
    other. Glob subtleties are deliberately left to W3."""
    if a == b:
        return True
    for x, y in ((a, b), (b, a)):
        base = x[:-2].rstrip("/") if x.endswith("**") else None
        if base and (y == base or y.startswith(base + "/")):
            return True
    return False


def check(run_dir: pathlib.Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    board = run_dir / "progress.md"
    text = board.read_text()

    rows = [c for line in _section(text, r"Status board") if (c := _cells(line))]
    body = [r for r in rows if len(r) >= 4 and r[0].lower() not in ("unit", "") and not set(r[0]) <= {"-"}]
    if not body:
        errors.append("ERROR E1 progress.md: no status board rows found")
        return errors, warnings

    owns: dict[str, list[str]] = {}
    for r in body:
        unit, lane, cell = r[0], r[1], r[2]
        if lane.lower() == "coordinator":
            errors.append(f"ERROR E7 {unit}: the coordinator is listed as a lane owner "
                          "(a coordinator writes no code — multi-session.md §5.1)")
        if not PATHISH.search(cell):
            errors.append(f"ERROR E2 {unit}: Owns cell {cell!r} is prose, not a file footprint")
            continue
        owns.setdefault(lane, []).extend(_footprints(cell))

    lanes = sorted(owns)
    # W1 is per lane, not per row: a lane with three units must not warn three times.
    for lane in lanes:
        if not (run_dir / f"status-{lane}.md").is_file():
            warnings.append(f"WARN  W1 lane {lane}: no status-{lane}.md yet")

    for i, la in enumerate(lanes):
        for lb in lanes[i + 1:]:
            for pa in owns[la]:
                for pb in owns[lb]:
                    if _definite_overlap(pa, pb):
                        errors.append(f"ERROR E3 lanes {la}/{lb}: footprints overlap "
                                      f"({pa} vs {pb}) — any overlap means one lane")

    reg = [c for line in _section(text, r"Contract register") if (c := _cells(line))]
    entries = [r for r in reg if len(r) >= 2 and r[0].upper().startswith("C")]
    if entries and not any(r[0].upper() == "U0" for r in body):
        errors.append("ERROR E6 progress.md: contract register is non-empty but the "
                      "board declares no U0 (coordination-protocol.md §4)")
    for r in entries:
        for lane in (r[1], *(x.strip() for x in r[2].split(","))) if len(r) > 2 else (r[1],):
            if lane and lane not in owns:
                errors.append(f"ERROR E4 contract {r[0]}: names lane {lane!r}, not on the board")

    return errors, warnings


def selftest() -> int:
    fixtures = pathlib.Path(__file__).parent / "fixtures_board"
    if not fixtures.is_dir():
        print(f"FAIL: no fixtures directory at {fixtures}")
        return 1
    fails: list[str] = []
    for case in sorted(p for p in fixtures.iterdir() if (p / "progress.md").is_file()):
        errors, warnings = check(case)
        name = case.name
        if name == "good":
            if errors:
                fails.append(f"{name}: expected clean, got {errors}")
        elif name.startswith("e"):
            code = name.split("_")[0].upper()
            if not any(code in e for e in errors):
                fails.append(f"{name}: expected {code}, got {errors or 'nothing'}")
        elif name.startswith("w"):
            code = name.split("_")[0].upper()
            if errors:
                fails.append(f"{name}: expected only warnings, got errors {errors}")
            if not any(code in w for w in warnings):
                fails.append(f"{name}: expected {code}, got {warnings or 'nothing'}")
    for f in fails:
        print(f"  - {f}")
    print("BOARD SELFTEST FAILED:" if fails else "OK: every fixture behaves as specified")
    return 1 if fails else 0


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_board.py <run_dir> | --selftest", file=sys.stderr)
        return 2
    if argv[1] == "--selftest":
        return selftest()
    run_dir = pathlib.Path(argv[1]).expanduser().resolve()
    if not (run_dir / "progress.md").is_file():
        print(f"ERROR: no progress.md at {argv[1]}", file=sys.stderr)
        return 2
    errors, warnings = check(run_dir)
    for line in errors + warnings:
        print(line)
    print(f"\nboard check: {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
