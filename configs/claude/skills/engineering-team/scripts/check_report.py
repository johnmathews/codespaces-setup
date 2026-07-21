#!/usr/bin/env python3
"""Structural gate for an engineering-team evaluation report.

Phase 1 runs this before announcing that the report exists. It is the one
control in this skill that can go red on its own, which is the point: every
other rule here is a sentence in a document that an agent may or may not have
loaded, and the skill's own record shows what that is worth — across 20 run
directories in one project, [VERIFIED] appeared 16 times in a single report
and [SUSPECTED] appeared zero times anywhere.

What it checks is deliberately narrow: **vocabulary and structure, not
prose quality**. No gate can tell you a finding is wrong. It can tell you a
finding is ungraded, unlocatable, uncorroborated, or missing entirely from
the index a human actually reads — and each of those was emitted by a real
run of this skill.

Two rules govern what is a hard failure and what is a warning:

1. A hard failure must be unambiguous and mechanically fixable. If a check
   can red an honest report, it will get switched off, and then it protects
   nothing.
2. "Zero [SUSPECTED] findings" is a WARNING, never a failure. The cheapest
   way to pass such a gate is to relabel a real finding as [SUSPECTED],
   which corrupts the exact vocabulary the gate exists to protect.

Usage:
    python3 check_report.py <path-to-evaluation-report.md>
    python3 check_report.py --selftest      # run the fixtures beside this file

Exit status: 0 if no hard failures (warnings may still be printed), 1 if any.
"""

from __future__ import annotations

import pathlib
import re
import sys

GRADES = ("VERIFIED", "SUPPORTED", "SUSPECTED")
SEVERITIES = ("Critical", "High", "Medium", "Low")
SEVERITY_RANK = {s.casefold(): i for i, s in enumerate(SEVERITIES)}

# Every section the template ships. A section that quietly stops being
# written is the failure this list exists to catch: the Dependency audit is
# the one evaluations most often drop, and nothing downstream notices.
REQUIRED_SECTIONS = (
    "executive summary",
    "findings index",
    "findings in detail",
    "test suite results",
    "project overview",
    "strengths",
    "weaknesses",
    "nfr register",
    "onboarding assessment",
    "assessment dimensions",
    "dependency audit",
    "gap analysis",
    "architectural assessment",
    "methodology and limitations",
)

HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
NUMBER_PREFIX_RE = re.compile(r"^\d[\d.]*\.?\s+")
DETAIL_ID_RE = re.compile(r"^(#{2,4})\s+(?:\d[\d.]*\.?\s+)?\[?(F\d+)\b")
SEPARATOR_CELL_RE = re.compile(r"^:?-{2,}:?$")
LIST_ITEM_RE = re.compile(r"^\s*(?:[-*]|\d+[.)])\s+")
SCORE_RE = re.compile(r"\b([0-5])\s*/\s*5\b")
FINDING_ID_RE = re.compile(r"\bF(\d+)\b")


class Report:
    """A parsed markdown report: headings, sections, and index rows."""

    def __init__(self, text: str):
        self.lines = text.splitlines()
        self.headings: list[tuple[int, int, str]] = []  # (line_no, level, text)
        for i, line in enumerate(self.lines, start=1):
            m = HEADING_RE.match(line)
            if m:
                self.headings.append((i, len(m.group(1)), m.group(2)))

    @staticmethod
    def normalise(heading: str) -> str:
        h = re.sub(r"[*`_]", "", heading)
        h = NUMBER_PREFIX_RE.sub("", h.strip())
        h = re.sub(r"[^a-z0-9 ]+", " ", h.casefold())
        return re.sub(r"\s+", " ", h).strip()

    def find_section(self, wanted: str) -> tuple[int, int] | None:
        """Return (first_body_line, end_line) 1-indexed, inclusive/exclusive."""
        for idx, (line_no, level, text) in enumerate(self.headings):
            if self.normalise(text) == wanted:
                end = len(self.lines) + 1
                for later_line, later_level, _ in self.headings[idx + 1 :]:
                    if later_level <= level:
                        end = later_line
                        break
                return line_no + 1, end
        return None

    def body_after(self, line_no: int, level: int) -> list[str]:
        end = len(self.lines) + 1
        for later_line, later_level, _ in self.headings:
            if later_line > line_no and later_level <= level:
                end = later_line
                break
        return self.lines[line_no : end - 1]


def _cells(line: str) -> list[str] | None:
    """Split an index row into fields, or None if the line is not a row."""
    stripped = line.strip()
    if stripped.startswith("|"):
        raw = [c.strip() for c in stripped.strip("|").split("|")]
        if raw and all(SEPARATOR_CELL_RE.match(c) for c in raw if c):
            return None
        return raw
    if LIST_ITEM_RE.match(line) and "·" in line:
        body = LIST_ITEM_RE.sub("", line).strip()
        return [c.strip() for c in body.split("·")]
    return None


def _clean(cell: str) -> str:
    return re.sub(r"[*`_]", "", cell).strip()


def index_rows(report: Report, start: int, end: int) -> list[tuple[int, list[str]]]:
    rows: list[tuple[int, list[str]]] = []
    for i in range(start, end):
        line = report.lines[i - 1]
        cells = _cells(line)
        if cells is None:
            continue
        # A table header is the row immediately above the `|---|` separator.
        if line.strip().startswith("|") and i < len(report.lines):
            nxt = _cells(report.lines[i])
            if nxt is None and report.lines[i].strip().startswith("|"):
                continue
        rows.append((i, cells))
    return rows


def check(path: pathlib.Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    text = path.read_text(encoding="utf-8")
    report = Report(text)

    def err(code: str, line: int | None, msg: str) -> None:
        where = f"{path}:{line}" if line else str(path)
        errors.append(f"ERROR {code} {where}: {msg}")

    def warn(code: str, line: int | None, msg: str) -> None:
        where = f"{path}:{line}" if line else str(path)
        warnings.append(f"WARN  {code} {where}: {msg}")

    # E1 — unfilled template.
    for i, line in enumerate(report.lines, start=1):
        if "<!--" in line:
            err("E1", i, "template instructions left in the report — section unfilled")
            break

    # E2 — a section quietly stopped being written.
    for wanted in REQUIRED_SECTIONS:
        if report.find_section(wanted) is None:
            err("E2", None, f"missing required section: '{wanted}'")

    span = report.find_section("findings index")
    if span is None:
        return errors, warnings
    rows = index_rows(report, *span)

    # E3 — an index with no findings in it is not an index.
    if not rows:
        err("E3", span[0], "findings index contains no parseable rows")

    seen: dict[str, int] = {}
    order: list[tuple[int, int]] = []
    graded: dict[str, str] = {}
    for line_no, cells in rows:
        clean = [_clean(c) for c in cells]
        excerpt = report.lines[line_no - 1].strip()
        if len(excerpt) > 90:
            excerpt = excerpt[:87] + "..."

        grades = [c for c in clean if c.strip("[]").upper() in GRADES]
        if len(grades) != 1:
            found = ", ".join(grades) if grades else "none"
            err(
                "E4",
                line_no,
                f"expected exactly one grade from {GRADES}, found {len(grades)} "
                f"({found}) — in: {excerpt}",
            )

        sevs = [c for c in clean if c.casefold() in SEVERITY_RANK]
        if len(sevs) != 1:
            found = ", ".join(sevs) if sevs else "none"
            err(
                "E5",
                line_no,
                f"expected exactly one severity from {SEVERITIES}, found {len(sevs)} "
                f"({found}) — in: {excerpt}",
            )

        ids = [m.group(0) for c in clean for m in [FINDING_ID_RE.search(c)] if m]
        if not ids:
            err("E6", line_no, "index row has no F<n> id, so it cannot be cross-referenced")
            continue
        fid = ids[0]
        if fid in seen:
            err("E6", line_no, f"duplicate finding id {fid} (first seen at line {seen[fid]})")
        seen[fid] = line_no
        if len(grades) == 1:
            graded[fid] = grades[0].strip("[]").upper()
        if len(sevs) == 1:
            order.append((SEVERITY_RANK[sevs[0].casefold()], line_no))

    # E7 — index and detail must correspond in both directions.
    details: dict[str, tuple[int, list[str]]] = {}
    for line_no, level, _ in report.headings:
        m = DETAIL_ID_RE.match(report.lines[line_no - 1])
        if m:
            details[m.group(2)] = (line_no, report.body_after(line_no, level))
    # If the whole detail section is absent, E2 has already said so; repeating
    # it once per finding buries the other failures under a wall of noise.
    if report.find_section("findings in detail") is not None:
        for fid, line_no in seen.items():
            if fid not in details:
                err("E7", line_no, f"{fid} is in the index with no matching detail block")
    for fid, (line_no, _) in details.items():
        if fid not in seen:
            err("E7", line_no, f"{fid} has a detail block with no line in the index")

    # E8 — a [VERIFIED] finding that quotes nothing is the commonest overclaim
    # in this skill's record. VERIFIED means you ran something and it showed
    # this; the output has to be in the report.
    for fid, grade in graded.items():
        if grade != "VERIFIED" or fid not in details:
            continue
        line_no, body = details[fid]
        if not any("```" in line for line in body):
            err(
                "E8",
                line_no,
                f"{fid} is [VERIFIED] but its detail block quotes no command output "
                "(no fenced block) — grade it [SUPPORTED] or quote what you ran",
            )

    # W1 — not a failure, on purpose. See the module docstring.
    if rows and not any(g == "SUSPECTED" for g in graded.values()):
        warn(
            "W1",
            span[0],
            "no [SUSPECTED] findings — a signal to re-read the report, not a sign it "
            "went well. Do NOT fix this by relabelling a real finding",
        )

    # W2 — the index is the layer a human reads; unordered, it is a list.
    for (rank_a, _), (rank_b, line_b) in zip(order, order[1:]):
        if rank_b < rank_a:
            warn("W2", line_b, "findings index is not ordered by severity (Critical first)")
            break

    # W3 — a score with no observation behind it is not a rating.
    dims = report.find_section("assessment dimensions")
    if dims:
        for i in range(dims[0], dims[1]):
            line = report.lines[i - 1]
            m = SCORE_RE.search(line)
            if m and len(line[m.end() :].strip(" -—:.")) < 15:
                warn("W3", i, "dimension score with no justification naming an observation")

    # W4 — a row we could not parse is a row we could not check.
    if span:
        for i in range(*span):
            line = report.lines[i - 1]
            if LIST_ITEM_RE.match(line) and "·" not in line and not line.strip().startswith("|"):
                warn("W4", i, "list item in the findings index is not a `·`-delimited row")

    return errors, warnings


def run(path: pathlib.Path) -> int:
    errors, warnings = check(path)
    for line in errors + warnings:
        print(line)
    if errors:
        print(f"\nFAIL: {len(errors)} hard failure(s) in {path}")
        return 1
    print(f"OK: {path} passes the structural gate" + (f" ({len(warnings)} warning(s))" if warnings else ""))
    return 0


def selftest() -> int:
    """Every hard failure has a fixture that turns it red, and one good report
    that must stay green. A gate whose tests are one happy path is a gate that
    passes loudest when it is blind."""
    fixtures = pathlib.Path(__file__).parent / "fixtures"
    if not fixtures.is_dir():
        print(f"FAIL: no fixtures directory at {fixtures}")
        return 1
    failed = 0
    for fixture in sorted(fixtures.glob("*.md")):
        errors, warnings = check(fixture)
        codes = {line.split()[1] for line in errors}
        warn_codes = {line.split()[1] for line in warnings}
        name = fixture.stem
        if name.startswith("good"):
            if errors:
                print(f"FAIL {fixture.name}: expected green, got {sorted(codes)}")
                failed += 1
            else:
                print(f"ok   {fixture.name}: green ({sorted(warn_codes) or 'no warnings'})")
            continue
        expected = name.split("_")[0].upper()  # e.g. "e4_two_grades" -> "E4"
        pool = codes | warn_codes
        if expected in pool:
            print(f"ok   {fixture.name}: {expected} raised")
        else:
            print(f"FAIL {fixture.name}: expected {expected}, got {sorted(pool) or 'nothing'}")
            failed += 1
    print()
    if failed:
        print(f"FAIL: {failed} fixture(s) did not behave as specified")
        return 1
    print("OK: every fixture behaves as specified")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-4], file=sys.stderr)
        print("usage: check_report.py <report.md> | --selftest", file=sys.stderr)
        return 2
    if argv[1] == "--selftest":
        return selftest()
    path = pathlib.Path(argv[1])
    if not path.is_file():
        print(f"ERROR: no such report: {path}", file=sys.stderr)
        return 2
    return run(path)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
