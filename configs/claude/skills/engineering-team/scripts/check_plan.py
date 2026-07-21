#!/usr/bin/env python3
"""Structural gate for an engineering-team improvement plan.

`improvement-plan.md` is one of a run's two primary artifacts, and until this
gate it was the unchecked one — `check_report.py` gates the evaluation report,
`check_run.py` gates the run's state file, but nothing checked the plan. Its
frontmatter is load-bearing: Phase 3 progress reporting and `run.yaml` are both
keyed on the `W<n>` unit IDs declared there ("The IDs declared here are
authoritative"). A plan whose frontmatter is malformed, or whose IDs don't line
up with its own body or with `run.yaml`, breaks that keying silently.

What it checks is **structure and cross-file consistency, not plan quality**. No
gate can tell you a plan is wise. It can tell you the frontmatter is a valid
index, that every declared unit has a section (and vice versa), that no template
placeholder was left unfilled, and that `run.yaml` does not claim a unit the plan
never declared — each of which is unambiguous and mechanically fixable.

Same two gate-design rules as the sibling gates:

1. A hard failure must be unambiguous and mechanically fixable, or an honest
   plan trips it and the gate gets switched off. This is why the many *prose*
   fields the spec asks of each unit (Priority, Risk, Size, Reversibility, …)
   are deliberately NOT hard-checked here: their formatting varies enough that a
   presence check would red honest plans. Their completeness is a human-review
   judgement, not a gate's.
2. Softer signals are WARNINGS: a plan with no "Non-goals" section (the spec
   calls that "suspicious", not invalid), and a `run.yaml` that is merely behind
   the plan rather than contradicting it.

Cross-file: when a `run.yaml` sits beside the plan, its unit IDs must be a subset
of the plan's — a `run.yaml` unit the plan doesn't declare is a phantom (hard
failure); a plan unit missing from `run.yaml` is `run.yaml` lagging (warning).

Stdlib-only, a small hand-parser over the documented frontmatter — same choice
as the sibling gates so it runs wherever the skill is deployed.

Usage:
    python3 check_plan.py <run-dir | improvement-plan.md>
    python3 check_plan.py --selftest      # run the fixtures beside this file

Exit status: 0 if no hard failures (warnings may still print), 1 if any.
"""

from __future__ import annotations

import pathlib
import re
import sys

WID_RE = re.compile(r"^W\d+$")
HEADING_RE = re.compile(r"^#{1,6}\s+(.*?)\s*$")
BODY_WID_RE = re.compile(r"\bW\d+\b")
PLACEHOLDER_RE = re.compile(r"^<[^>\n]+>$")  # a WHOLE value like <short kebab-case name>, not a substring
RUN_ID_RE = re.compile(r"\bid:\s*(W\d+)")  # from run.yaml's flow-style unit dicts
SCALAR_RE = re.compile(r"^([A-Za-z_][\w-]*):\s*(.*)$")


class Plan:
    """A parsed improvement plan: frontmatter (plan name + unit list) and the
    `W<n>` IDs that head sections in the body."""

    def __init__(self, text: str):
        self.lines = text.splitlines()
        self.has_frontmatter = False
        self.fm_lines: list[str] = []
        self.plan_name: str = ""
        self.units: list[dict[str, str]] = []  # frontmatter units, in order
        self.body_ids: list[str] = []
        self.has_nongoals = False

        body_start = self._parse_frontmatter()
        if body_start is not None:
            self._parse_body(body_start)

    def _parse_frontmatter(self) -> int | None:
        """Populate plan_name/units/fm_lines; return the line index (0-based)
        where the body begins, or None if there is no valid frontmatter."""
        if not self.lines or self.lines[0].strip() != "---":
            return None
        close = None
        for i in range(1, len(self.lines)):
            if self.lines[i].strip() == "---":
                close = i
                break
        if close is None:
            return None
        self.has_frontmatter = True
        self.fm_lines = self.lines[1:close]

        in_units = False
        cur: dict[str, str] | None = None
        for raw in self.fm_lines:
            stripped = raw.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if stripped == "units:":
                in_units = True
                continue
            if in_units and stripped.startswith("-"):
                cur = {}
                self.units.append(cur)
                rest = stripped[1:].strip()  # e.g. "id: W1"
                if ":" in rest:
                    k, v = rest.split(":", 1)
                    cur[k.strip()] = v.strip()
                continue
            if in_units and cur is not None and ":" in stripped and not raw[:1].strip():
                k, v = stripped.split(":", 1)
                cur[k.strip()] = v.strip()
                continue
            m = SCALAR_RE.match(stripped)
            if m and not in_units:
                if m.group(1) == "plan":
                    self.plan_name = m.group(2).strip()
        return close + 1

    def _parse_body(self, start: int) -> None:
        for line in self.lines[start:]:
            m = HEADING_RE.match(line)
            if not m:
                continue
            heading = m.group(1)
            if re.sub(r"[*`_]", "", heading).strip().casefold() == "non-goals":
                self.has_nongoals = True
            wid = BODY_WID_RE.search(heading)
            if wid:
                self.body_ids.append(wid.group(0))


def check(plan_dir: pathlib.Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    plan_path = plan_dir / "improvement-plan.md"

    def err(code: str, line: int | None, msg: str) -> None:
        where = f"{plan_path}:{line}" if line else str(plan_path)
        errors.append(f"ERROR {code} {where}: {msg}")

    def warn(code: str, line: int | None, msg: str) -> None:
        where = f"{plan_path}:{line}" if line else str(plan_path)
        warnings.append(f"WARN  {code} {where}: {msg}")

    plan = Plan(plan_path.read_text(encoding="utf-8"))

    # E1 — the frontmatter index is the whole point; without it nothing else
    # can be checked, so stop here (repeating downstream errors would be noise).
    if not plan.has_frontmatter:
        err("E1", 1, "plan does not begin with a `---` YAML frontmatter block")
        return errors, warnings

    # E6 — an unfilled `<placeholder>` VALUE left in the frontmatter (the
    # template's own `<short kebab-case name>` / `<...>` markers). Matched
    # against WHOLE values, not as a substring, so a legitimate title mentioning
    # a generic type (`Optional<Config>`, `List<T>`) or an autolink is not a
    # false failure — the very "red an honest plan" trap this gate must avoid.
    placeholder_values = [("plan", plan.plan_name)]
    for unit in plan.units:
        placeholder_values.append(("id", unit.get("id", "")))
        placeholder_values.append(("title", unit.get("title", "")))
    for key, val in placeholder_values:
        if PLACEHOLDER_RE.match(val.strip()):
            err("E6", None, f"unfilled template placeholder in frontmatter `{key}:` — {val.strip()}")

    # E2 — the plan needs a name.
    if not plan.plan_name:
        err("E2", None, "frontmatter has no `plan:` name")

    # E3 — a plan with no units is not a plan.
    if not plan.units:
        err("E3", None, "frontmatter declares no `units:`")

    # E4/E5 — every unit needs a well-formed id and a title; ids are unique.
    seen: dict[str, bool] = {}
    fm_ids: list[str] = []
    for unit in plan.units:
        uid = unit.get("id", "")
        if not uid or not WID_RE.match(uid):
            err("E4", None, f"unit id '{uid or '(missing)'}' is not of the form W<n>")
            continue
        if not unit.get("title"):
            err("E4", None, f"unit {uid} has no `title`")
        if uid in seen:
            err("E5", None, f"duplicate unit id {uid} in frontmatter")
        seen[uid] = True
        fm_ids.append(uid)

    # E7 — the frontmatter index and the body sections must correspond both ways.
    fm_set, body_set = set(fm_ids), set(plan.body_ids)
    for uid in fm_ids:
        if uid not in body_set:
            err("E7", None, f"{uid} is declared in the frontmatter but has no section in the body")
    for uid in plan.body_ids:
        if uid not in fm_set:
            err("E7", None, f"{uid} heads a body section but is not declared in the frontmatter")

    # W1 — no Non-goals. The spec: "A plan with no non-goals is suspicious." Not
    # invalid — a warning, and one you must not silence with a hollow section.
    if not plan.has_nongoals:
        warn("W1", None, "no `Non-goals` section — the spec calls a plan without one suspicious")

    # Cross-file: run.yaml (if present) must not name a unit the plan doesn't
    # declare (E8, phantom), and ideally mirrors every plan unit (W2, lagging).
    run_yaml = plan_dir / "run.yaml"
    if run_yaml.is_file() and fm_ids:
        run_ids = set(RUN_ID_RE.findall(run_yaml.read_text(encoding="utf-8")))
        for rid in sorted(run_ids):
            if rid not in fm_set:
                err("E8", None, f"run.yaml lists unit {rid}, which the plan's frontmatter does not declare")
        for uid in fm_ids:
            if uid not in run_ids:
                warn("W2", None, f"plan declares {uid} but run.yaml does not mirror it")

    return errors, warnings


def _resolve(arg: str) -> pathlib.Path | None:
    """Accept a run dir or a path to improvement-plan.md; return the dir."""
    p = pathlib.Path(arg)
    if p.is_dir() and (p / "improvement-plan.md").is_file():
        return p
    if p.is_file() and p.name == "improvement-plan.md":
        return p.parent
    return None


def run(plan_dir: pathlib.Path) -> int:
    errors, warnings = check(plan_dir)
    for line in errors + warnings:
        print(line)
    if errors:
        print(f"\nFAIL: {len(errors)} hard failure(s) in {plan_dir}/improvement-plan.md")
        return 1
    print(f"OK: {plan_dir}/improvement-plan.md passes the plan gate" + (f" ({len(warnings)} warning(s))" if warnings else ""))
    return 0


def selftest() -> int:
    """Every hard failure and warning has a fixture that raises it, plus a good
    plan that must stay green. A gate whose tests are one happy path passes
    loudest when it is blind."""
    fixtures = pathlib.Path(__file__).parent / "fixtures_plan"
    if not fixtures.is_dir():
        print(f"FAIL: no fixtures directory at {fixtures}")
        return 1
    failed = 0
    for case in sorted(p for p in fixtures.iterdir() if (p / "improvement-plan.md").is_file()):
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
        expected = name.split("_")[0].upper()  # "e7_index_detail" -> "E7"
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
        print("usage: check_plan.py <run-dir | improvement-plan.md> | --selftest", file=sys.stderr)
        return 2
    if argv[1] == "--selftest":
        return selftest()
    plan_dir = _resolve(argv[1])
    if plan_dir is None:
        print(f"ERROR: no improvement-plan.md at {argv[1]} (pass a run dir or a plan path)", file=sys.stderr)
        return 2
    return run(plan_dir)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
