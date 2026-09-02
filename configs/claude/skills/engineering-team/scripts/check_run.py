#!/usr/bin/env python3
"""Structural gate for an engineering-team run's `run.yaml`.

`run.yaml` is the skill's own state file: what phase a run is in, what scope it
has, and what each work unit has done. The skill added it because everything
about run state used to be an *inference* — phase deduced from which files
existed, unit completion "reported" in chat prose that did not survive the
session. That is the exact failure the skill warns about for the projects it
reviews (a claim with no check behind it), and this gate applies the same
discipline to the skill's own bookkeeping.

It checks two things, both mechanical:

1. **Schema** — `run:` present, `phase:` and `scope:` in their enums, every
   unit has an `id` and a status in its enum, and an `abandoned` unit carries a
   `why`. These are unambiguous and machine-fixable, so they are hard failures.
2. **Reconciliation** — the skill's own stated invariant: a `phase:` of 2 or
   later means Phase 1 finished, so `evaluation-report.md` must exist; a `phase:`
   of 3 or later means Phase 2 finished, so `improvement-plan.md` must exist.
   `phase: complete` is the opposite case and it caught this checker out: closeout
   RETIRES the plan (deletes it), so a completed run is *expected* to have none, and
   a plan still sitting in a `complete` run means the retire step was skipped — a
   warning, not a failure. A stale `phase:` that claims an artifact which is not on
   disk is the "lies with authority" failure the skill calls out; this catches it.

Same two gate-design rules as `check_report.py`:

1. A hard failure must be unambiguous and mechanically fixable, or an honest run
   trips it and the gate gets switched off.
2. Anything a run could legitimately be mid-flight is a WARNING, not a failure
   (e.g. a `complete` run still carrying a `pending` unit — suspicious, but the
   fix is a human decision, not a mechanical one).

Parsing is deliberately a small hand-parser over the constrained format the
skill documents (flow-style unit dicts), with no PyYAML dependency — the same
stdlib-only choice `check_report.py` makes, so the gate runs wherever the skill
is deployed.

Usage:
    python3 check_run.py <run-dir | run.yaml>
    python3 check_run.py --selftest      # run the fixtures beside this file

Exit status: 0 if no hard failures (warnings may still print), 1 if any.
"""

from __future__ import annotations

import pathlib
import re
import sys

PHASES = ("1", "2", "3", "4", "complete")
SCOPES = ("evaluate", "plan", "full")
UNIT_STATUSES = ("pending", "in-progress", "done", "abandoned")

# A phase number at or past which each artifact must already exist. `phase: 2`
# means Phase 1 (evaluation) is done; `phase: 3` means Phase 2 (planning) is
# done. See the module docstring.
REPORT_FROM_PHASE = 2
PLAN_FROM_PHASE = 3

COMMENT_RE = re.compile(r"\s+#.*$")  # trailing comment, but not a '#' inside a value
SCALAR_RE = re.compile(r"^([A-Za-z_][\w-]*):\s*(.*)$")
UNIT_RE = re.compile(r"^\s*-\s*\{(.*)\}\s*$")


class RunFile:
    """A parsed run.yaml: the three scalars and the unit list.

    `units` entries are dicts with at least the keys that parsed; `_line`
    records where each unit sat so errors can point at it.
    """

    def __init__(self, text: str):
        self.scalars: dict[str, str] = {}
        self.units: list[dict[str, str]] = []
        self.malformed_units: list[int] = []  # line numbers of `- ...` lines we could not parse
        in_units = False
        for i, raw in enumerate(text.splitlines(), start=1):
            # Strip a trailing ` # comment` from every line, not just scalar
            # values — the skill's own run.yaml template comments both the
            # `units:` header and individual unit lines, and a gate that only
            # de-commented scalars would drop all units on a commented header
            # (silently no-op'ing E4/E5/W1) and false-flag a commented unit line.
            line = COMMENT_RE.sub("", raw).rstrip()
            if not line.strip() or line.strip().startswith("#"):
                continue
            if line.strip() == "units:":
                in_units = True
                continue
            stripped = line.strip()
            if in_units and stripped.startswith("-"):
                m = UNIT_RE.match(line)
                if not m:
                    self.malformed_units.append(i)
                    continue
                unit = self._parse_inline(m.group(1))
                unit["_line"] = str(i)
                self.units.append(unit)
                continue
            # A non-list, non-indented line ends the units block.
            m = SCALAR_RE.match(line)
            if m:
                in_units = False
                key, value = m.group(1), m.group(2).strip()
                self.scalars[key] = value.strip("'\"")

    @staticmethod
    def _parse_inline(body: str) -> dict[str, str]:
        """Parse `id: W3, status: abandoned, why: it was blocked` into a dict.
        Split on the first comma-separated `key: value` pairs; `why` may itself
        contain no comma (the skill keeps it to one line)."""
        out: dict[str, str] = {}
        for part in body.split(","):
            if ":" not in part:
                continue
            k, v = part.split(":", 1)
            out[k.strip()] = v.strip().strip("'\"")
        return out


def _phase_index(phase: str) -> int | None:
    """Numeric rank of a phase for reconciliation: 1..4, or None for 'complete'
    (which is scope-dependent and handled separately)."""
    return int(phase) if phase.isdigit() else None


def check(run_dir: pathlib.Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    run_yaml = run_dir / "run.yaml"

    def err(code: str, line: int | None, msg: str) -> None:
        where = f"{run_yaml}:{line}" if line else str(run_yaml)
        errors.append(f"ERROR {code} {where}: {msg}")

    def warn(code: str, line: int | None, msg: str) -> None:
        where = f"{run_yaml}:{line}" if line else str(run_yaml)
        warnings.append(f"WARN  {code} {where}: {msg}")

    rf = RunFile(run_yaml.read_text(encoding="utf-8"))
    phase = rf.scalars.get("phase", "")
    scope = rf.scalars.get("scope", "")

    # E1 — the run's own id. Without it a run dir cannot name itself.
    if not rf.scalars.get("run"):
        err("E1", None, "missing `run:` — the run has no id")

    # E2 — phase must be one of the five states.
    phase_ok = phase in PHASES
    if not phase_ok:
        err("E2", None, f"phase: '{phase or '(missing)'}' is not one of {PHASES}")

    # E3 — scope must be one of the three verbs.
    scope_ok = scope in SCOPES
    if not scope_ok:
        err("E3", None, f"scope: '{scope or '(missing)'}' is not one of {SCOPES}")

    # E4 — every unit needs an id and a status in the enum.
    for unit in rf.units:
        line = int(unit.get("_line", 0)) or None
        uid = unit.get("id", "")
        status = unit.get("status", "")
        if not uid:
            err("E4", line, "unit has no `id`")
        if status not in UNIT_STATUSES:
            err("E4", line, f"unit {uid or '?'}: status '{status or '(missing)'}' not in {UNIT_STATUSES}")
    for line in rf.malformed_units:
        err("E4", line, "unit is not the documented `- { id: W1, status: done }` form")

    # E5 — an abandoned unit must say why, or 'blocked' masquerades as 'not done'.
    for unit in rf.units:
        if unit.get("status") == "abandoned" and not unit.get("why"):
            err("E5", int(unit.get("_line", 0)) or None, f"unit {unit.get('id', '?')} is abandoned but has no `why`")

    # Reconciliation (E6/E7) needs a valid phase+scope to reason about; if either
    # is bad, E2/E3 already fired and reconciling against garbage adds only noise.
    if phase_ok and scope_ok:
        idx = _phase_index(phase)
        complete = phase == "complete"

        # A report is due once Phase 1 is finished: any numeric phase >= 2, or a
        # completed run (every scope runs Phase 1).
        report_due = (idx is not None and idx >= REPORT_FROM_PHASE) or complete
        # A plan is due once Phase 2 is finished and until the run closes: numeric
        # phase >= 3 only. `complete` is deliberately NOT here — closeout retires the
        # plan, so requiring one on a closed run demands the exact file the closeout
        # step deletes. This clause used to read `or (complete and scope in (...))`
        # and turned every correctly-closed run red.
        plan_due = idx is not None and idx >= PLAN_FROM_PHASE

        if report_due and not (run_dir / "evaluation-report.md").exists():
            err("E6", None, f"phase '{phase}' implies Phase 1 is done, but evaluation-report.md is missing from {run_dir}")
        if plan_due and not (run_dir / "improvement-plan.md").exists():
            err("E7", None, f"phase '{phase}' (scope {scope}) implies Phase 2 is done, but improvement-plan.md is missing from {run_dir}")

        # W2 — a closed run still carrying its plan: the retire step was skipped.
        # A warning, not a failure — the plan is harmless where it sits, and deleting
        # someone's file is not a call a checker gets to make.
        if complete and (run_dir / "improvement-plan.md").exists():
            warn("W2", None,
                 f"phase 'complete' but improvement-plan.md is still in {run_dir} — "
                 "closeout retires the plan (see \"Closing a run\" in SKILL.md)")

        # W1 — a closed run still carrying unfinished work. Not a hard failure:
        # the skill says a run that ended early should stay open, so if this is
        # `complete` the fix is a human call (reopen, or abandon-with-why), not
        # a mechanical one.
        if complete:
            for unit in rf.units:
                if unit.get("status") in ("pending", "in-progress"):
                    warn("W1", int(unit.get("_line", 0)) or None,
                         f"run is `complete` but unit {unit.get('id', '?')} is still '{unit.get('status')}'")

    return errors, warnings


def _resolve(arg: str) -> pathlib.Path | None:
    """Accept a run dir or a path to run.yaml; return the run dir or None."""
    p = pathlib.Path(arg)
    if p.is_dir() and (p / "run.yaml").is_file():
        return p
    if p.is_file() and p.name == "run.yaml":
        return p.parent
    return None


def run(run_dir: pathlib.Path) -> int:
    errors, warnings = check(run_dir)
    for line in errors + warnings:
        print(line)
    if errors:
        print(f"\nFAIL: {len(errors)} hard failure(s) in {run_dir}/run.yaml")
        return 1
    print(f"OK: {run_dir}/run.yaml passes the run-state gate" + (f" ({len(warnings)} warning(s))" if warnings else ""))
    return 0


def selftest() -> int:
    """Every hard failure and warning has a fixture that raises it, plus good
    runs that must stay green. A gate whose tests are one happy path passes
    loudest when it is blind."""
    fixtures = pathlib.Path(__file__).parent / "fixtures_run"
    if not fixtures.is_dir():
        print(f"FAIL: no fixtures directory at {fixtures}")
        return 1
    failed = 0
    for case in sorted(p for p in fixtures.iterdir() if (p / "run.yaml").is_file()):
        errors, warnings = check(case)
        codes = {line.split()[1] for line in errors}
        warn_codes = {line.split()[1] for line in warnings}
        name = case.name
        if name.startswith("good"):
            if errors:
                print(f"FAIL {name}: expected green, got {sorted(codes)}")
                failed += 1
            else:
                print(f"ok   {name}: green ({sorted(warn_codes) or 'no warnings'})")
            continue
        expected = name.split("_")[0].upper()  # "e6_phase2_no_report" -> "E6"
        pool = codes | warn_codes
        if expected in pool:
            print(f"ok   {name}: {expected} raised")
        else:
            print(f"FAIL {name}: expected {expected}, got {sorted(pool) or 'nothing'}")
            failed += 1
    print()
    if failed:
        print(f"FAIL: {failed} fixture(s) did not behave as specified")
        return 1
    print("OK: every fixture behaves as specified")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_run.py <run-dir | run.yaml> | --selftest", file=sys.stderr)
        return 2
    if argv[1] == "--selftest":
        return selftest()
    run_dir = _resolve(argv[1])
    if run_dir is None:
        print(f"ERROR: no run.yaml at {argv[1]} (pass a run dir or a run.yaml path)", file=sys.stderr)
        return 2
    return run(run_dir)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
