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
lanes), E4 (a contract names a lane not on the board), E5 (two lanes reserving
the same range or token), E6 (a non-empty contract register with no U0), E7
(the coordinator listed as a lane owner), W1 (a lane with no status file yet),
and W5 (a reservation row that could not be checked).

The `## 3. Contract register` section carries two tables and they are read
separately: **Interfaces** drives E4 and E6 (`_interfaces()`), **Reservations**
drives E5 (`_reservations()`). Each selects by row shape, so a board that lists
them in either order, or under its own sub-headings, stays clean.

E5 is why the reservations table has a fixed shape. Migration numbers, ports,
config keys and error codes collide *without sharing a file*, so E3 — which
compares file footprints — cannot see them at all. Two lanes both claiming
migration `0007` is a clean merge and a broken schema, and it is the case the
whole contract register exists for.

The grammar in `coordination-protocol.md` §4.2 is deliberately narrow: a
numeric range, a backtick-escaped opaque token, or one of a small fixed set of
placeholders — `—`, `-`, `none`, `n/a`, or empty mean "this lane reserves
nothing of this Kind" and are silently skipped; `TBD` or `?` mean "not decided
yet" and are **W5**. A cell that parses as none of these is also **W5**, not an
error — the gate reports that it could not check the row rather than guessing
at an overlap. That is gate-design rule 1: this check previously did not exist
at all because the table was free text, and an approximated parser would have
false-positived on honest boards and been switched off.

Deliberately NOT implemented: E8 (gate round ≥ 3) from the wider spec, and
W2/W3/W4. A smaller honest gate beats a larger over-promised one.

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


def _raw_cells(line: str) -> list[str]:
    """Like `_cells`, but keeps backticks intact.

    Every column except one treats a backtick as markdown styling to discard.
    The Reserved column in a Reservations row is the exception: a backtick there
    is the escape that forces token interpretation (`_parse_reserved()`,
    coordination-protocol.md §4.2), so stripping it before parsing — which
    `_cells()` does — throws away the one signal that distinguishes a token like
    `` `08-2026` `` from the range `08-2026`."""
    m = ROW.match(line.rstrip())
    if not m:
        return []
    return [c.replace("\\|", "|").strip() for c in UNESCAPED_PIPE.split(m.group("cells"))]


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
        Reservations | Kind | Lane | Reserved |

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


RANGE = re.compile(r"^(\d+)\s*-\s*(\d+)$")
SINGLE = re.compile(r"^(\d+)$")
# Looks like someone meant a range but did not use a plain hyphen — an en dash
# (0007–0009) is the common one, and it has no space to reject it on, so without
# this it would be silently accepted as an opaque token and never compared.
RANGEISH = re.compile(r"^\d+\s*\D{1,3}\s*\d+$")


_HEADER_WORDS = {
    "id", "kind", "lane", "reserved", "producer", "consumer", "consumers",
    "contract", "frozen at",
}
_SEPARATOR_CELL = re.compile(r"^:?-+:?$")


def _is_header_cells(cells: list[str]) -> bool:
    """True iff every non-empty cell is one of the contract-register column
    names, in either table and at either width (`| Kind | Lane | Reserved |` or
    the full five-column Interfaces header, or its three-column-only variant
    `| ID | Producer | Consumer |`). Order-independent and width-independent on
    purpose: it only needs to recognise a header, not validate one."""
    return bool(cells) and any(c.strip() for c in cells) and \
        all(not c.strip() or c.strip().casefold() in _HEADER_WORDS for c in cells)


def _is_separator_cells(cells: list[str]) -> bool:
    """True iff every cell is a markdown table separator (`---`, `:--`, `--:`)."""
    return bool(cells) and all(_SEPARATOR_CELL.match(c.strip()) for c in cells)


def _valid_reservation_cells(cells: list[str]) -> bool:
    """True iff cells is a genuine 3-cell Reservations row: not a header, not a
    separator, Kind present, and Lane a single lane id (no whitespace — a list
    like `a, b` is not one lane, and prose is not a lane id either)."""
    if len(cells) != 3 or _is_header_cells(cells) or _is_separator_cells(cells):
        return False
    kind, lane = cells[0].strip(), cells[1].strip()
    if not kind or not lane or kind.casefold() == "kind":
        return False
    return " " not in lane


def _reservations(text: str) -> list[list[str]]:
    """The **Reservations** rows of the contract register, and only those.

    Shape is fixed by `coordination-protocol.md` §4.2 precisely so this can be
    machine-read: exactly three cells, one row per lane per kind, and a Lane cell
    holding a single lane id. The header row and the `---` separator are dropped
    by `_valid_reservation_cells()`.

    Selection is by shape, like `_interfaces()`. A board that words its columns
    differently is skipped rather than hard-failed — gate-design rule 1. Rows
    that are table-shaped but match neither table are not silently dropped here
    — `check()` reports them as W5 separately, because a dropped row here is the
    payload E5 exists to catch, not a cosmetic miss.

    The Reserved cell is returned with backticks intact (`_raw_cells()`, not
    `_cells()`) — `_parse_reserved()` needs to see them to tell a backtick-escaped
    token from a plain numeric range."""
    out: list[list[str]] = []
    for line in _section(text, r"Contract register"):
        cells = _cells(line)
        if not _valid_reservation_cells(cells):
            continue
        kind, lane = cells[0].strip(), cells[1].strip()
        raw = _raw_cells(line)
        reserved = raw[2].strip() if len(raw) == 3 else cells[2].strip()
        out.append([kind, lane, reserved])
    return out


def _parse_reserved(cell: str) -> tuple[int, int] | str | None:
    """A Reserved cell is a numeric range, a (possibly backtick-escaped) opaque
    token, or unreadable. Placeholders ("nothing reserved" / "not decided") are
    handled by the caller before this is reached — see `check()`.

    **Backticks force token interpretation.** `` `08-2026` `` is always a token,
    never a range, even though its digits-separator-digits shape would otherwise
    match `RANGE` or `RANGEISH`. Without this escape, any two-part numeric
    identifier — a date prefix, a tenant id like `01-99` — is indistinguishable
    from an interval, and §4.2 offered no way to say "this is not a range."
    Unbackticked, `08-2026` still parses as the range `(8, 2026)`: the plain
    grammar is unchanged, only the escape is new. This is why the cell must reach
    here with backticks intact (`_raw_cells()`, not `_cells()`).

    `(lo, hi)` for `8080` or `0007-0009` (inclusive; a plain hyphen). A single
    bare word is an opaque token. Anything else returns None and becomes W5: the
    gate says it could not check the row rather than guessing an overlap.

    An en-dashed range (`0007–0009`) is rejected rather than read as a token.
    §4.2 asks for a plain hyphen, but the failure mode matters more than the rule:
    an en dash contains no space, so the token branch would happily accept it, and
    it would then only ever clash with a byte-identical string — `0007–0009` and
    `0008–0010` would pass silently. A warning the coordinator can act on beats a
    check that quietly stops checking."""
    c = cell.strip()
    if len(c) >= 2 and c.startswith("`") and c.endswith("`"):
        token = c[1:-1].strip()
        return token if token and " " not in token else None
    c = c.strip("`")
    if not c:
        return None
    if m := SINGLE.match(c):
        n = int(m.group(1))
        return (n, n)
    if m := RANGE.match(c):
        lo, hi = int(m.group(1)), int(m.group(2))
        return (lo, hi) if lo <= hi else None
    if RANGEISH.match(c):
        # number-separator-number, but not a plain hyphen. Do NOT fall through to
        # the token branch: an en-dashed range would then only ever clash with an
        # identical string, so 0007–0009 vs 0008–0010 would pass silently.
        return None
    return c if " " not in c else None


# Reserved-cell placeholders (coordination-protocol.md §4.2). Matched casefolded
# after stripping backticks — a placeholder is never itself backtick-escaped.
_NOTHING_RESERVED = {"—", "-", "none", "n/a", ""}   # this lane reserves nothing of this Kind
_UNDECIDED_RESERVED = {"tbd", "?"}                   # not decided yet — W5


def _normalize_kind(kind: str) -> str:
    """Kind for **comparison** only — casefolded and stripped of surrounding
    markdown emphasis and trailing punctuation, so `Ports`, `**Ports**`, and
    `Ports:` are recognised as the same Kind (coordination-protocol.md §4.2: "Two
    rows only conflict if their Kind matches" — matches after this normalisation,
    not byte-for-byte). Callers keep the original, un-normalised spelling for
    error messages."""
    k = kind.strip()
    k = re.sub(r"^[*_`]+|[*_`]+$", "", k).strip()
    k = k.rstrip(":.,;").strip()
    return k.casefold()


def _reservations_clash(a: tuple[int, int] | str, b: tuple[int, int] | str) -> bool:
    """Ranges overlap numerically; tokens clash only when identical. A range
    against a token is not a definite clash — mixed units inside one Kind are a
    modelling problem, not something to hard-fail on."""
    if isinstance(a, tuple) and isinstance(b, tuple):
        return a[0] <= b[1] and b[0] <= a[1]
    if isinstance(a, str) and isinstance(b, str):
        return a == b
    return False


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

    # W5 — any contract-register row that is table-shaped but reads as neither a
    # valid Interfaces row nor a valid Reservations row. Interfaces rows (5 cells)
    # are exempted wholesale, including ones with a non-"C<digits>" ID convention
    # — E4/E6 already go quiet on those deliberately (see `_interfaces()`), and
    # this pass must not contradict that. A dropped Reservations-shaped row is the
    # failure mode E5 exists to prevent, so — unlike `_interfaces()`'s silent
    # shape filter — it is not silent here.
    for line in _section(text, r"Contract register"):
        cells = _cells(line)
        if not cells or _is_header_cells(cells) or _is_separator_cells(cells):
            continue
        if len(cells) == 5 or _valid_reservation_cells(cells):
            continue
        warnings.append("WARN  W5 contract register row could not be read as an "
                        f"interface or a reservation: {line.strip()!r}")

    # E5 / W5 — reservations. Two lanes must not reserve the same migration
    # numbers, ports, keys or codes: those collide without sharing a file, so the
    # disjoint-footprint rule (E3) cannot see them at all.
    parsed: list[tuple[str, str, tuple[int, int] | str, str]] = []
    for kind, lane, cell in _reservations(text):
        if lane not in board_lanes:
            warnings.append(f"WARN  W5 reservation {kind}/{lane}: lane is not on the "
                            "board, so its reservation cannot be checked")
            continue
        plain = cell.strip().strip("`").strip()
        if plain.casefold() in _NOTHING_RESERVED:
            continue  # this lane reserves nothing of this Kind — not an error, not a warning
        if plain.casefold() in _UNDECIDED_RESERVED:
            warnings.append(f"WARN  W5 reservation {kind}/{lane}: not yet decided "
                            f"({plain!r}) — coordination-protocol.md §4.2")
            continue
        value = _parse_reserved(cell)
        if value is None:
            warnings.append(f"WARN  W5 reservation {kind}/{lane}: cannot read {cell!r} "
                            "as a range or a token (coordination-protocol.md §4.2)")
            continue
        parsed.append((kind, lane, value, plain))

    for i, (kind_a, lane_a, val_a, raw_a) in enumerate(parsed):
        for kind_b, lane_b, val_b, raw_b in parsed[i + 1:]:
            if (_normalize_kind(kind_a) == _normalize_kind(kind_b) and lane_a != lane_b
                    and _reservations_clash(val_a, val_b)):
                errors.append(f"ERROR E5 {kind_a}: lane {lane_a} reserves {raw_a} and lane "
                              f"{lane_b} reserves {raw_b} — these collide without sharing a "
                              "file, so E3 cannot catch them")

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
