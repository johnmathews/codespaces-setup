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
2. Softer signals are WARNINGS: a lane with no status file yet (it may simply
   not have started).

What this gate implements: E1 (no status board rows), E2 (an Owns cell that
reads as prose, not a footprint), E3 (definite footprint overlap between
lanes), E4 (a contract names a lane not on the board), E6 (a non-empty
contract register with no U0), E7 (the coordinator listed as a lane owner),
and W1 (a lane with no status file yet).

E4 and E6 read the register's **Interfaces** table only. The `## 3. Contract
register` section carries a second table, Reservations, whose rows are prose
(`| Config keys / env vars | same key, different meaning | namespaced per lane |`)
and are not seams a U0 could land — see `_interfaces()` for the shape test and
the false positive it exists to close.

Deliberately NOT implemented: E5 (reservation-range overlap) and E8 (gate
round ≥ 3) from the wider spec, and W2/W3/W4. E5 in particular is left out on
purpose rather than approximated — the reservations table in
`coordination-protocol.md` §4.2 has no defined grammar to parse, so any
attempt at E5 would either miss real overlaps or false-positive on honest
reservations. A smaller honest gate beats a larger over-promised one.

Usage:
    python3 check_board.py <run_dir>     # gate a real run
    python3 check_board.py --selftest    # run the fixtures beside this file
"""

from __future__ import annotations

import pathlib
import re
import sys

ROW = re.compile(r"^\|(?P<cells>.+)\|\s*$")
UNESCAPED_PIPE = re.compile(r"(?<!\\)\|")

# An interface row in the contract register: `| C1 | producer | consumers | … | … |`.
# The ID shape is what separates it from the *reservations* table that shares the
# same `## 3. Contract register` section — see `_interfaces()`.
CONTRACT_ID = re.compile(r"^C\d+$")


def _cells(line: str) -> list[str]:
    """Split a markdown table row into cells.

    Splits on **unescaped** `|` only. A contract cell legitimately contains an
    escaped pipe (`Account \\| None` — a union type), and splitting on it would
    make an interface row look five-and-a-bit columns wide, which the shape test
    below relies on being exactly five."""
    m = ROW.match(line.rstrip())
    if not m:
        return []
    return [c.replace("\\|", "|").strip().strip("`")
            for c in UNESCAPED_PIPE.split(m.group("cells"))]


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


def _looks_like_footprint(cell: str) -> bool:
    """A footprint is a comma-separated list of paths. Prose has spaces inside an
    entry ("the auth stuff"); a path usually does not. A separator-only test wrongly
    rejects honest single-name footprints (README.md, docs, pyproject.toml). This is
    a heuristic, not a guarantee: a bare word with no space (TBD, misc) passes as a
    valid-looking footprint, and a genuine path containing a space would be rejected
    as prose."""
    entries = [e.strip().strip("`") for e in cell.split(",") if e.strip()]
    return bool(entries) and all(e not in ("—", "-") and " " not in e for e in entries)


def _interfaces(text: str) -> list[list[str]]:
    """The **Interfaces** rows of the contract register, and only those.

    `## 3. Contract register` holds two tables (`coordination-protocol.md` §4.2):

        Interfaces   | ID | Producer | Consumers | Contract | Frozen at |
        Reservations | Kind | Example collision | Allocation |

    Only the first declares cross-lane seams, so only it drives E4 (a contract
    naming an off-board lane) and E6 (a non-empty register with no U0). U0 exists
    to land seams "as stubs and types" (§4.4) — a port range or a flag-name
    namespace is not something a stub can land, so a reservations-only register
    needs no U0.

    Selection is by **row shape, not by position**: exactly five cells and an ID
    matching `C<digits>`. A reservations row has three cells and a prose Kind, so
    it can never be read as a contract — which it was, when selection was
    `startswith("C")`: `| Config keys / env vars | … | … |` parsed as contract
    "Config keys / env vars" with lanes "same key, different meaning" and
    "namespaced per lane", three hard errors on an entirely honest board.

    Gate-design rule 1 is why the test is this strict rather than positional: a
    board that lists the two tables in the other order, or under its own
    sub-headings, is honest and must stay clean. The cost is a real false
    negative — an interfaces table whose ID column is worded some other way
    (`IF-1`, `contract-1`) is skipped, so E4/E6 go quiet on it. Silence on an
    unrecognised shape is the correct side to fail on here; a hard error on an
    honest board is what switches the gate off."""
    rows = [c for line in _section(text, r"Contract register") if (c := _cells(line))]
    return [r for r in rows if len(r) == 5 and CONTRACT_ID.match(r[0])]


def _definite_overlap(a: str, b: str) -> bool:
    """True only for unambiguous overlap: identical, or one a dir-prefix of the
    other. Glob subtleties are deliberately not attempted."""
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

    board_lanes: set[str] = set()  # every lane named in a row, regardless of footprint parsing
    owns: dict[str, list[str]] = {}
    for r in body:
        unit, lane, cell = r[0], r[1], r[2]
        if lane.lower() == "coordinator":
            errors.append(f"ERROR E7 {unit}: the coordinator is listed as a lane owner "
                          "(a coordinator writes no code — multi-session.md §5.1)")
            continue  # a coordinator row is not a lane: no board_lanes, no owns, no W1
        board_lanes.add(lane)
        if not _looks_like_footprint(cell):
            errors.append(f"ERROR E2 {unit}: Owns cell {cell!r} is prose, not a file footprint")
            continue
        owns.setdefault(lane, []).extend(_footprints(cell))

    # W1 is per lane, not per row: a lane with three units must not warn three times.
    # Uses board_lanes (every lane on the board), not owns (only footprint-validated
    # lanes) — a lane whose footprint failed E2 still deserves its own W1 check.
    for lane in sorted(board_lanes):
        if not (run_dir / f"status-{lane}.md").is_file():
            warnings.append(f"WARN  W1 lane {lane}: no status-{lane}.md yet")

    owned_lanes = sorted(owns)
    for i, la in enumerate(owned_lanes):
        for lb in owned_lanes[i + 1:]:
            for pa in owns[la]:
                for pb in owns[lb]:
                    if _definite_overlap(pa, pb):
                        errors.append(f"ERROR E3 lanes {la}/{lb}: footprints overlap "
                                      f"({pa} vs {pb}) — any overlap means one lane")

    entries = _interfaces(text)
    if entries and not any(r[0].upper() == "U0" for r in body):
        errors.append("ERROR E6 progress.md: contract register is non-empty but the "
                      "board declares no U0 (coordination-protocol.md §4)")
    for r in entries:
        for lane in (r[1], *(x.strip() for x in r[2].split(","))):
            if lane and lane not in board_lanes:
                errors.append(f"ERROR E4 contract {r[0]}: names lane {lane!r}, not on the board")

    return errors, warnings


# ---------------------------------------------------------------------------
# The `/done` gate barrier predicate.
#
# This is not part of the board check. It lives here because `--selftest` is the
# thing CI already runs, and the predicate had no committed test at all: it is the
# branch's only enforcement of "no PR without a PASS verdict", it has broken three
# times (twice fail-open), and every proof of it until now was a manual shell
# demonstration that vanished with the terminal.
#
# The authority is `commands/done.md` §`8a` item 1 — see `references/rule-ownership.md`
# §4, edit-together pair 4. The ERE below is a *copy* of the one that ships there, and
# `_done_md_pass_predicate()` re-reads `done.md` and asserts the two are byte-identical,
# so the copy cannot drift away from the original unnoticed.

GATE_PASS_ERE = r"^_Requested.*·[[:space:]]*Verdict PASS[[:space:]]*·"
GATE_HEAD_LINES = 5  # `head -5` — the header block, per coordination-protocol.md §3.6

# `grep -qE '<GATE_PASS_ERE>'` — matched against each of the first GATE_HEAD_LINES lines.
_DONE_GREP = re.compile(r"grep -qE '([^']*Verdict PASS[^']*)'")


def _ere_to_python(ere: str) -> str:
    """Translate the POSIX ERE `done.md` hands to `grep -E` into Python regex syntax.

    Only one construct differs: the POSIX class `[[:space:]]`, which Python's `re`
    does not know. Everything else in this predicate (`^`, `.`, `*`, a literal `·`)
    means the same in both. Translating rather than hand-writing a lookalike is the
    point — a hand-written equivalent is exactly how the two would drift."""
    return ere.replace("[[:space:]]", "[ \\t\\n\\r\\f\\v]")


def gate_clears(gate_file: pathlib.Path) -> bool:
    """True iff this gate file clears the `/done` barrier.

    Mirrors `head -5 <file> | grep -qE '<GATE_PASS_ERE>'` exactly: the search is
    bounded to the header block, and anchored to the status line's `_Requested`
    opener. Both bounds are load-bearing and each catches what the other misses —
    the bound stops a `Verdict PASS` in a finding or a fenced example far down the
    body, the anchor stops one on a prose line inside the header block."""
    pattern = re.compile(_ere_to_python(GATE_PASS_ERE))
    try:
        with gate_file.open(encoding="utf-8") as fh:
            head = [next(fh, "") for _ in range(GATE_HEAD_LINES)]
    except OSError:
        return False  # a missing gate file blocks, exactly as `head`'s failure does
    return any(pattern.search(line) for line in head)


def _done_md_pass_predicate() -> tuple[str | None, str]:
    """The PASS predicate as it is actually written in `commands/done.md`.

    Returns (ere, where). `ere` is None when `done.md` cannot be located — which
    happens in the deployed skill (`~/.claude/skills/…` sits beside `~/.claude/commands/`
    at a different depth than the repo does) but never in the repo, which is where CI
    runs. A None is reported loudly, never treated as agreement."""
    here = pathlib.Path(__file__).resolve().parent
    candidates = [
        here.parents[3] / "commands/done.md",  # repo:     configs/claude/{skills/engineering-team/scripts,commands}
        here.parents[2] / "commands/done.md",  # deployed: ~/.claude/{skills/engineering-team/scripts,commands}
    ]
    for cand in candidates:
        if cand.is_file():
            m = _DONE_GREP.search(cand.read_text())
            return (m.group(1) if m else None), str(cand)
    return None, " or ".join(str(c) for c in candidates)


def gate_selftest() -> list[str]:
    """Run the barrier predicate against `fixtures_gate/`, and prove it has not
    drifted from `done.md`. Fixture names state the expectation: `clear_*` must
    clear the barrier, `block_*` must block it."""
    fails: list[str] = []
    fixtures = pathlib.Path(__file__).parent / "fixtures_gate"
    if not fixtures.is_dir():
        return [f"no gate fixtures at {fixtures}"]

    cases = sorted(p for p in fixtures.glob("*.md") if p.name != "README.md")
    if not cases:
        return [f"no gate fixtures in {fixtures}"]
    for case in cases:
        expected = case.name.startswith("clear_")
        actual = gate_clears(case)
        verdict = "CLEARS" if actual else "BLOCKS"
        print(f"  {'ok  ' if actual == expected else 'FAIL'} {case.name}: {verdict}")
        if actual != expected:
            fails.append(f"{case.name}: expected {'CLEARS' if expected else 'BLOCKS'}, got {verdict}")

    shipped, where = _done_md_pass_predicate()
    if shipped is None:
        fails.append(f"cannot read the PASS predicate from done.md ({where}) — "
                     "the drift link between this test and the barrier is broken")
    elif shipped != GATE_PASS_ERE:
        fails.append(f"predicate drift: done.md ships {shipped!r}, this test uses "
                     f"{GATE_PASS_ERE!r} ({where})")
    else:
        print(f"  ok   predicate matches {where} byte-for-byte: {GATE_PASS_ERE}")
    return fails


def selftest() -> int:
    fixtures = pathlib.Path(__file__).parent / "fixtures_board"
    if not fixtures.is_dir():
        print(f"FAIL: no fixtures directory at {fixtures}")
        return 1
    fails: list[str] = []
    for case in sorted(p for p in fixtures.iterdir() if (p / "progress.md").is_file()):
        errors, warnings = check(case)
        name = case.name
        if name.startswith("good"):
            if errors:
                fails.append(f"{name}: expected clean, got {errors}")
            if warnings:
                fails.append(f"{name}: expected clean, got warnings {warnings}")
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
    print("board fixtures: " + (f"{len(fails)} failure(s)" if fails else "all behave as specified"))

    print("gate barrier predicate (commands/done.md §`8a` item 1):")
    fails += gate_selftest()

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
