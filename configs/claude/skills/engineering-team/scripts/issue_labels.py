#!/usr/bin/env python3
"""Apply and check the engineering-team issue label scheme on a GitHub repo.

The scheme and its canonical label list live in one place,
`references/issues.md` (§3 and the table in §4). This script parses that table
and holds no copy of it, so a change to the list is a change to the doc.

    issue_labels.py list [--json]
        Print the canonical labels.
    issue_labels.py apply [--repo OWNER/NAME] [--dry-run]
        Read `gh label list`, then create each missing scheme label and reset
        any drifted colour or description with `gh label create --force`.
        Never renames a label and never touches one outside the scheme.
    issue_labels.py check --labels "bug,severity: high,..." [--label NAME]... [--body-file F] [--repo R]
        Check a label set, and optionally an issue body, before filing. Use the
        repeatable --label for a name that holds a comma.
    issue_labels.py verify --issue N [--expect "..."] [--expect-label NAME]... [--repo R]
        Read `gh issue view N --json labels,body` and run the same checks on
        what was filed. With --expect, also confirm exactly those labels landed.
    issue_labels.py --selftest
        Parse the real scheme and prove each check can go red. No `gh` needed.

Exit codes: 0 clean, 1 a check failed, 2 a usage, scheme or `gh` error.
Stdlib only, like the skill's other scripts, so it runs wherever the skill is
deployed. `--scheme PATH` reads the table from another file (for tests).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

DEFAULT_SCHEME = Path(__file__).resolve().parent.parent / "references" / "issues.md"
GROUPS = ("type", "severity", "concern")
# GitHub's default triage labels. They are the user's to apply and are never areas.
TRIAGE_DEFAULTS = frozenset({"duplicate", "good first issue", "help wanted", "invalid", "question", "wontfix"})
EVIDENCE_LABELS = ("Verified live:", "Read in repo:", "Inferred:")
MAX_DESCRIPTION = 100  # GitHub's limit on a label description

TABLE_HEADER = re.compile(r"^\|\s*Group\s*\|\s*Name\s*\|\s*Colour\s*\|\s*Description\s*\|\s*$")
LIST_ITEM = re.compile(r"^(?:[-*+]|\d+[.)])\s+(.*)$")


class SchemeError(Exception):
    """The canonical table is missing or malformed."""


class GhError(Exception):
    """A `gh` call failed."""


class UsageError(Exception):
    """The command line asks for something the script cannot do."""


@dataclass(frozen=True)
class Label:
    group: str
    name: str
    color: str
    description: str


# ---- the scheme --------------------------------------------------------------

def parse_scheme(text: str) -> list[Label]:
    """Read the canonical table: the one whose header is Group | Name | Colour | Description."""
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if TABLE_HEADER.match(line.strip())), None)
    if start is None:
        raise SchemeError("no table with the header | Group | Name | Colour | Description |")
    labels: list[Label] = []
    for line in lines[start + 2:]:
        line = line.strip()
        if not line.startswith("|"):
            break
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) != 4:
            raise SchemeError(f"row does not have four cells: {line}")
        group, name, color, description = (c.strip("`").strip() for c in cells)
        if group not in GROUPS:
            raise SchemeError(f"{name}: group {group!r} is not one of {', '.join(GROUPS)}")
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
            raise SchemeError(f"{name}: colour {color!r} is not # and six hex digits")
        if not description or len(description) > MAX_DESCRIPTION:
            raise SchemeError(f"{name}: description must be 1 to {MAX_DESCRIPTION} characters")
        labels.append(Label(group, name, color[1:].lower(), description))
    names = [label.name.lower() for label in labels]
    if len(set(names)) != len(names):
        raise SchemeError("a label name appears twice")
    for group in GROUPS:
        if not any(label.group == group for label in labels):
            raise SchemeError(f"no {group} labels in the table")
    return labels


def load_scheme(path: Path) -> list[Label]:
    try:
        return parse_scheme(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise SchemeError(f"cannot read {path}: {exc}") from exc


# ---- gh ----------------------------------------------------------------------

def gh(args: list[str], repo: str | None) -> str:
    cmd = ["gh", *args, *(["-R", repo] if repo else [])]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError as exc:
        raise GhError("gh is not installed") from exc
    if out.returncode != 0:
        raise GhError(f"`{' '.join(cmd)}` failed: {out.stderr.strip()}")
    return out.stdout


LABEL_LIMIT = 1000


def gh_json(args: list[str], repo: str | None) -> object:
    """A `gh ... --json` call, parsed. Output that is not JSON is a `gh` error, never a check failure."""
    text = gh(args, repo)
    try:
        return json.loads(text)
    except ValueError as exc:
        raise GhError(f"`gh {' '.join(args)}` did not print JSON: {text.strip()[:80]!r}") from exc


def repo_labels(repo: str | None) -> dict[str, dict[str, str]]:
    """The repo's labels, keyed by lower-cased name (GitHub names are case-insensitive)."""
    data = gh_json(["label", "list", "--limit", str(LABEL_LIMIT), "--json", "name,color,description"], repo)
    if not isinstance(data, list) or not all(isinstance(d, dict) and "name" in d for d in data):
        raise GhError("`gh label list` returned an unexpected shape")
    if len(data) >= LABEL_LIMIT:
        # A cut-off list would make a present label look missing, and apply would then
        # create it with the scheme's spelling, renaming the repo's. Refuse instead.
        raise GhError(f"the repo has {LABEL_LIMIT} or more labels, so the list may be cut off")
    return {label["name"].lower(): label for label in data}


def needs_repo(names: list[str], scheme: list[Label]) -> bool:
    """Only an area label needs the repo's label list: scheme and triage labels are known."""
    known = {label.name.lower() for label in scheme} | TRIAGE_DEFAULTS
    return any(n.lower() not in known for n in names)


# ---- checks ------------------------------------------------------------------

def split_labels(raw: str | None, single: list[str] | None = None) -> list[str]:
    """Labels from a comma list plus repeated single flags. A name holding a comma needs the flag."""
    names = [part.strip() for part in (raw or "").split(",") if part.strip()]
    return names + [n.strip() for n in (single or []) if n.strip()]


def check_labels(names: list[str], scheme: list[Label], existing: dict[str, dict[str, str]] | None) -> list[str]:
    """Problems with a label set. `existing` is the repo's labels, needed only for areas."""
    by_name = {label.name.lower(): label for label in scheme}
    errors: list[str] = []
    lowered = [n.lower() for n in names]
    if len(set(lowered)) != len(lowered):
        errors.append("a label is listed twice")
    for group, rule in (("type", "exactly one type label"), ("severity", "exactly one severity label")):
        found = [n for n in names if n.lower() in by_name and by_name[n.lower()].group == group]
        if len(found) != 1:
            errors.append(f"needs {rule}, has {len(found)}: {', '.join(found) or 'none'}")
    for name in names:
        key = name.lower()
        if key in by_name:
            continue
        if key in TRIAGE_DEFAULTS:
            errors.append(f"{name}: a GitHub triage label, which is the user's to apply")
        elif existing is not None and key not in existing:
            errors.append(f"{name}: not a label in this repo. Areas are never invented, so ask the user")
    return errors


def body_sections(body: str) -> dict[str, list[tuple[str, bool]]]:
    """Split a body at its `## ` headings, ignoring any inside a code fence.
    Each line comes with whether it is fence or fenced code."""
    sections: dict[str, list[tuple[str, bool]]] = {}
    current: str | None = None
    in_fence = False
    for line in body.splitlines():
        is_fence = line.strip().startswith("```")
        if not in_fence and not is_fence and line.startswith("## "):
            current = line[3:].strip().lower()
            sections.setdefault(current, [])
            continue
        if current is not None:
            sections[current].append((line, in_fence or is_fence))
        if is_fence:
            in_fence = not in_fence
    return sections


def check_body(body: str, names: list[str]) -> list[str]:
    """Problems with an issue body: evidence must be labelled claims, judgement apart."""
    errors: list[str] = []
    sections = body_sections(body)
    if "evidence" not in sections:
        errors.append("no `## Evidence` section")
    if not ({"judgement", "judgment"} & sections.keys()):
        errors.append("no `## Judgement` section, so judgement is not kept apart from evidence")
    if "evidence" not in sections:
        return errors

    claims: list[str] = []
    for line, fenced in sections["evidence"]:
        if fenced or not line.strip() or line[0].isspace() or line.startswith("#"):
            continue  # code, blank, a continuation of the item above, or a sub-heading
        item = LIST_ITEM.match(line)
        if item is None:
            errors.append(f"evidence holds prose, not a labelled claim: {line.strip()[:60]}")
            continue
        text = item.group(1).replace("**", "").strip()
        claims.append(text)
        if not text.startswith(EVIDENCE_LABELS):
            errors.append(f"evidence claim has no label ({' / '.join(EVIDENCE_LABELS)}): {text[:60]}")
    if not claims:
        errors.append("the Evidence section has no claims")
    if "investigation" in (n.lower() for n in names) and not any(c.startswith("Inferred:") for c in claims):
        errors.append("an investigation issue needs an `Inferred:` claim stating the unverified claim")
    return errors


def report(errors: list[str], ok: str) -> int:
    for error in errors:
        print(f"FAIL {error}")
    if errors:
        return 1
    print(f"OK   {ok}")
    return 0


# ---- commands ----------------------------------------------------------------

def cmd_list(scheme: list[Label], as_json: bool) -> int:
    if as_json:
        print(json.dumps([asdict(label) for label in scheme], indent=2))
    else:
        for label in scheme:
            print(f"{label.group:9} {label.name:20} #{label.color}  {label.description}")
    return 0


def cmd_apply(scheme: list[Label], repo: str | None, dry_run: bool) -> int:
    existing = repo_labels(repo)
    verb = "would " if dry_run else ""
    changes = 0
    for label in scheme:
        current = existing.get(label.name.lower())
        if current is None:
            name, what = label.name, f"create {label.name} (#{label.color}, {label.description})"
        elif current["color"].lower() != label.color or current["description"] != label.description:
            # Keep the repo's spelling of the name, so a case difference is never a rename.
            name = current["name"]
            diffs = []
            if current["color"].lower() != label.color:
                diffs.append(f"colour #{current['color'].lower()} -> #{label.color}")
            if current["description"] != label.description:
                diffs.append(f"description {current['description']!r} -> {label.description!r}")
            what = f"update {name}: {'; '.join(diffs)}"
        else:
            print(f"ok      {label.name}")
            continue
        changes += 1
        print(f"{verb}{what}")
        if not dry_run:
            gh(["label", "create", name, "--color", label.color, "--description", label.description, "--force"], repo)
    print(f"{changes} label(s) {'to change' if dry_run else 'changed'}, {len(scheme) - changes} already current")
    return 0


def cmd_check(scheme: list[Label], repo: str | None, names: list[str], body_file: str | None) -> int:
    if not names:
        raise UsageError("give the labels with --labels or --label")
    errors = check_labels(names, scheme, repo_labels(repo) if needs_repo(names, scheme) else None)
    if body_file is not None:
        errors += check_body(Path(body_file).read_text(encoding="utf-8"), names)
    return report(errors, f"labels{' and body' if body_file else ''} follow the scheme")


def cmd_verify(scheme: list[Label], repo: str | None, issue: str, expect: list[str] | None) -> int:
    data = gh_json(["issue", "view", issue, "--json", "labels,body"], repo)
    if not isinstance(data, dict) or not isinstance(data.get("labels"), list):
        raise GhError(f"`gh issue view {issue}` returned an unexpected shape")
    names = [label["name"] for label in data["labels"]]
    errors = check_labels(names, scheme, repo_labels(repo) if needs_repo(names, scheme) else None)
    errors += check_body(data.get("body") or "", names)
    if expect is not None:
        want = {n.lower(): n for n in expect}
        have = {n.lower() for n in names}
        errors += [f"{want[n]}: expected on #{issue} but did not land" for n in want if n not in have]
        errors += [f"{n}: on #{issue} but not expected" for n in names if n.lower() not in want]
    return report(errors, f"#{issue} carries {', '.join(names)} and its body follows the scheme")


# ---- selftest ----------------------------------------------------------------

def selftest() -> int:
    """Parse the real table, then prove every check reds on a seeded fault."""
    failures: list[str] = []

    def expect(cond: bool, msg: str) -> None:
        if not cond:
            failures.append(msg)

    scheme = load_scheme(DEFAULT_SCHEME)
    counts = {g: sum(1 for label in scheme if label.group == g) for g in GROUPS}
    expect(counts == {"type": 6, "severity": 4, "concern": 3}, f"scheme group counts: {counts}")

    text = DEFAULT_SCHEME.read_text()
    for fault, broken in {
        "bad colour": text.replace("`#d73a4a`", "`#d73a4`"),
        "bad group": text.replace("| type | `bug`", "| kind | `bug`"),
        "duplicate name": text.replace("| type | `enhancement` |", "| type | `bug` |"),
        "no table": text.replace("| Group | Name |", "| Grp | Name |"),
    }.items():
        try:
            parse_scheme(broken)
            failures.append(f"parse_scheme accepted a {fault}")
        except SchemeError:
            pass

    repo = {"home-assistant": {"name": "home-assistant"}}
    expect(not check_labels(["bug", "severity: high", "security", "home-assistant"], scheme, repo), "good set rejected")
    for labels in (["severity: high"], ["bug", "maintenance", "severity: high"], ["bug"],
                   ["bug", "severity: low", "severity: high"], ["bug", "severity: low", "wontfix"],
                   ["bug", "severity: low", "made-up"], ["bug", "bug", "severity: low"]):
        expect(bool(check_labels(labels, scheme, repo)), f"check_labels accepted {labels}")

    body = ("Summary.\n\n## Evidence\n\n- Verified live: `x` printed `y`\n"
            "- Read in repo: `a.py:1`\n\n## Judgement\n\n- Severity: Low\n")
    expect(not check_body(body, ["bug"]), f"good body rejected: {check_body(body, ['bug'])}")
    expect(bool(check_body(body, ["investigation"])), "investigation with no Inferred claim accepted")
    for fault, broken in {
        "unlabelled claim": body.replace("- Read in repo: ", "- "),
        "prose": body.replace("## Evidence\n", "## Evidence\n\nLooks bad.\n"),
        "no judgement": body.replace("## Judgement", "## Notes"),
        "no evidence": body.replace("## Evidence", "## Facts"),
    }.items():
        expect(bool(check_body(broken, ["bug"])), f"check_body accepted {fault}")

    for failure in failures:
        print(f"FAIL {failure}")
    if failures:
        return 1
    print(f"issue_labels selftest OK ({len(scheme)} labels parsed; label, body and table checks seeded red)")
    return 0


# ---- main --------------------------------------------------------------------

def main(argv: list[str]) -> int:
    if argv == ["--selftest"]:
        return selftest()
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--scheme", type=Path, default=DEFAULT_SCHEME, help="file holding the canonical table")
    sub = parser.add_subparsers(dest="command", required=True)
    p_list = sub.add_parser("list", help="print the canonical labels")
    p_list.add_argument("--json", action="store_true")
    p_apply = sub.add_parser("apply", help="create missing scheme labels, reset drifted ones")
    p_apply.add_argument("--repo")
    p_apply.add_argument("--dry-run", action="store_true")
    p_check = sub.add_parser("check", help="check a label set and body before filing")
    p_check.add_argument("--repo")
    p_check.add_argument("--labels", help="comma-separated label names")
    p_check.add_argument("--label", action="append", help="one label name, repeatable (use it for a name with a comma)")
    p_check.add_argument("--body-file")
    p_verify = sub.add_parser("verify", help="check a filed issue")
    p_verify.add_argument("--repo")
    p_verify.add_argument("--issue", required=True)
    p_verify.add_argument("--expect", help="comma-separated labels that must be exactly the issue's")
    p_verify.add_argument("--expect-label", action="append", help="one expected label, repeatable")
    args = parser.parse_args(argv)

    try:
        scheme = load_scheme(args.scheme)
        if args.command == "list":
            return cmd_list(scheme, args.json)
        if args.command == "apply":
            return cmd_apply(scheme, args.repo, args.dry_run)
        if args.command == "check":
            return cmd_check(scheme, args.repo, split_labels(args.labels, args.label), args.body_file)
        expect = None if args.expect is None and not args.expect_label else split_labels(args.expect, args.expect_label)
        return cmd_verify(scheme, args.repo, args.issue, expect)
    except (SchemeError, GhError, UsageError, OSError, UnicodeDecodeError) as exc:
        print(f"issue_labels: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
