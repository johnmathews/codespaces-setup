#!/usr/bin/env python3
"""Apply and check the engineering-team issue label scheme and issue shape.

The scheme and its canonical label list live in one place,
`references/issues.md` (§3 and the table in §4), as does the body shape (§6)
and the update comment (§7). This script parses that table and holds no copy of
it, so a change to the list is a change to the doc.

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
    issue_labels.py check-body --body-file F [--type T] [--linear]
        Check a body alone, for a tracker the label checks do not fit (Linear).
        `--type investigation` also requires an `Inferred:` claim. `--linear`
        adds the checks for a reader without the repo (§9.4). No `gh`.
    issue_labels.py check-comment --body-file F [--linear]
        Check an update comment: it opens with a `**TL;DR:**` line. No `gh`.
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
from dataclasses import asdict, dataclass, field
from pathlib import Path

DEFAULT_SCHEME = Path(__file__).resolve().parent.parent / "references" / "issues.md"
GROUPS = ("type", "severity", "concern")
# GitHub's default triage labels. They are the user's to apply and are never areas.
TRIAGE_DEFAULTS = frozenset({"duplicate", "good first issue", "help wanted", "invalid", "question", "wontfix"})
EVIDENCE_LABELS = ("Verified live:", "Read in repo:", "Inferred:")
TLDR_HEADINGS = frozenset({"tl;dr", "tldr"})
TLDR_ITEMS = (2, 5)    # issues.md §6.1: 2 to 5 bullets
TLDR_MAX_WORDS = 90    # the hard ceiling; §6.1 asks for about 60
# A TL;DR that defers to the text under it does not stand alone. "below" on its
# own is too broad ("drops below 5%"), so only the deferring phrases count.
POINTS_BELOW = re.compile(
    r"\b(?:see|as)\s+(?:below|the\s+appendix|appendix)\b"
    r"|\b(?:details|more|explained|described|shown)\s+below\b", re.IGNORECASE)
COMMENT_TLDR = re.compile(r"^\*\*TL;DR(?::\*\*|\*\*:)\s*(.*)$")
CHECKBOX = re.compile(r"^\[[ xX]\]\s+")
# A screenshot on its own line, bare or wrapped in a link: ![alt](url) or [![alt](url)](url)
IMAGE_LINE = re.compile(r"^(?:!\[[^\]]*\]\([^)]*\)|\[!\[[^\]]*\]\([^)]*\)\]\([^)]*\))\s*$")
# Internal references a reader without the repo cannot resolve (issues.md §9.4)
INTERNAL_REF = re.compile(r"\b(?:W\d+|F\d+|(?i:ADR|RFC)[- ]?\d+)\b")
GLOSS = re.compile(r"^\s*(?:\(|[—–:]\s|-\s)")  # "W2 (retry...)", "W2 — retry...", "W2: retry..."
INLINE_CODE = re.compile(r"`[^`]*`")
PATH_IN_CODE = re.compile(r"`[^`]*(?:/|\.[A-Za-z]{1,5}(?::\d+)?)[^`]*`")
BARE_PATH = re.compile(r"(?<![\w`])[\w.-]+(?:/[\w.-]+)+\.[A-Za-z]{1,5}(?::\d+)?\b")  # src/export.py:88
MD_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
PO_MIN_WORDS = 4
FOOTER = object()  # marks "past the closing `---`" while splitting a body
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
THEMATIC_BREAK = re.compile(r"^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$")
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


@dataclass
class Outline:
    """A body split at its headings, ignoring any inside a code fence."""
    preamble: list[str]                                  # unfenced, non-blank lines before the first `## `
    order: list[str]                                     # `## ` headings in order, lower-cased
    sections: dict[str, list[tuple[str, bool]]]          # each line, and whether it is fence or fenced code
    headings: list[tuple[int, str]]                      # every unfenced heading: (level, text)
    footer: list[str] = field(default_factory=list)      # lines after a top-level `---`


def fenced_lines(lines: list[str]) -> list[bool]:
    """Whether each line is a code-fence line or inside one (CommonMark: a fence
    of ``` or ~~~, closed by the same character at least as long, with nothing
    after it; a backtick fence's info string holds no backtick)."""
    marks: list[bool] = []
    opener: tuple[str, int] | None = None
    for line in lines:
        m = FENCE.match(line.rstrip("\r"))
        if opener is None:
            if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
                opener = (m.group(1)[0], len(m.group(1)))
                marks.append(True)
            else:
                marks.append(False)
        else:
            marks.append(True)
            if m and m.group(1)[0] == opener[0] and len(m.group(1)) >= opener[1] and not m.group(2).strip():
                opener = None
    return marks


def outline(body: str) -> Outline:
    out = Outline([], [], {}, [])
    current: str | None = None
    lines = body.splitlines()
    for line, fenced in zip(lines, fenced_lines(lines)):
        heading = None if fenced else re.match(r"^ {0,3}(#{1,6})\s+(.*?)(?:\s+#+)?\s*$", line)
        if heading:
            level, text = len(heading.group(1)), heading.group(2).strip()
            out.headings.append((level, text))
            if level == 2:
                current = text.lower()
                out.order.append(current)
                out.sections.setdefault(current, [])
                continue
        if not fenced and current is not None and THEMATIC_BREAK.match(line):
            current = FOOTER  # issues.md §6.5: the footer follows a `---` and belongs to no section
            continue
        if current == FOOTER:
            out.footer.append(line)
        elif current is not None:
            out.sections[current].append((line, fenced))
        elif line.strip():
            out.preamble.append(line.strip())  # anything before the first section, fenced or not
    return out


def list_items(lines: list[tuple[str, bool]]) -> tuple[list[str], list[str]]:
    """The top-level list items of a section, with their continuation lines
    joined on, and every other unfenced line, which is prose.

    A line belongs to the item above it when it is indented, or when it follows
    the item with no blank line between (a hard-wrapped item). An indented line
    with no item above it is prose, so indenting cannot hide text from the checks.
    Fenced code, headings and thematic breaks are neither."""
    items: list[str] = []
    prose: list[str] = []
    in_item = False      # the item above can still take a continuation line
    after_blank = False
    for line, fenced in lines:
        if fenced:
            continue
        if not line.strip():
            after_blank = True
            continue
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())
        if stripped.startswith("#") or THEMATIC_BREAK.match(line):
            in_item, after_blank = False, False
            continue
        item = LIST_ITEM.match(stripped)
        if item and indent <= 3 and not (in_item and indent >= 2):
            items.append(item.group(1).strip())
            in_item = True
        elif in_item and (indent >= 2 or not after_blank):
            items[-1] += " " + stripped
        else:
            prose.append(stripped)
            in_item = False
        after_blank = False
    return items, prose


def check_claims(lines: list[tuple[str, bool]], where: str) -> tuple[list[str], list[str]]:
    """Every list item must start with an evidence label. Returns (errors, claims).

    A screenshot line is allowed, and so is anything inside <details>, which is
    where long output is folded."""
    errors: list[str] = []
    claims: list[str] = []
    kept: list[tuple[str, bool]] = []
    depth = 0
    for line, fenced in lines:
        lower = line.strip().lower()
        if not fenced:
            depth += lower.count("<details") - lower.count("</details>")
            depth = max(depth, 0)
            if lower.startswith("<") or IMAGE_LINE.match(line.strip()):
                continue
        kept.append((line, fenced or depth > 0))
    items, prose = list_items(kept)
    for line in prose:
        errors.append(f"{where} holds prose, not a labelled claim: {line[:60]}")
    for raw in items:
        text = CHECKBOX.sub("", raw.replace("**", "").strip())
        if IMAGE_LINE.match(text):
            continue  # a screenshot written as a list item
        claims.append(text)
        if not text.startswith(EVIDENCE_LABELS):
            errors.append(f"{where} claim has no label ({' / '.join(EVIDENCE_LABELS)}): {text[:60]}")
    return errors, claims


def check_tldr(lines: list[tuple[str, bool]]) -> list[str]:
    errors: list[str] = []
    items, prose = list_items(lines)
    if prose:
        errors.append(f"the TL;DR holds prose; write it as 2 to 5 bullets: {prose[0][:60]}")
    low, high = TLDR_ITEMS
    if not low <= len(items) <= high:
        errors.append(f"the TL;DR has {len(items)} item(s); it needs 2 to 5 (what, impact and severity, next step)")
    words = sum(len(text.split()) for text in items + prose)
    if words > TLDR_MAX_WORDS:
        errors.append(f"the TL;DR is {words} words; keep it under {TLDR_MAX_WORDS} and move detail to Evidence")
    for text in items + prose:
        if POINTS_BELOW.search(text):
            errors.append(f"the TL;DR points below instead of standing alone: {text[:60]}")
    return errors


def check_appendix(o: Outline) -> list[str]:
    errors: list[str] = []
    named = [(level, text) for level, text in o.headings if "appendix" in text.lower()]
    for level, text in named:
        if level != 2 or text.lower() != "appendix":
            errors.append(f"an appendix heading must be exactly `## Appendix`, not `{'#' * level} {text}`")
    count = sum(1 for level, text in named if level == 2 and text.lower() == "appendix")
    if count > 1:
        errors.append(f"the body has {count} appendix headings; use one `## Appendix` with A.1, A.2 subsections")
    if "appendix" in o.order and o.order[-1] != "appendix":
        after = o.order[o.order.index("appendix") + 1]
        errors.append(f"`## Appendix` must be the last section, but `## {after}` comes after it")
    return errors


def ref_key(ref: str) -> str:
    return re.sub(r"[- ]", "", ref.upper())


def unglossed_refs(texts: list[str]) -> list[str]:
    """Internal references whose first use carries no meaning (issues.md §9.4).
    Inline code is ignored, since a command or path is not a reference."""
    errors: list[str] = []
    seen: set[str] = set()
    for text in texts:
        plain = MD_LINK.sub(r"\1", INLINE_CODE.sub(" ", text))
        for m in INTERNAL_REF.finditer(plain):
            key = ref_key(m.group(0))
            if key in seen:
                continue
            seen.add(key)
            if not GLOSS.match(plain[m.end():]):
                errors.append(f"{m.group(0)} has no meaning at its first use; write `{m.group(0)} (<what it is>)`")
    return errors


def check_plan(lines: list[tuple[str, bool]]) -> list[str]:
    """A tracking issue's plan (issues.md §10.2): one checklist item per unit,
    each ID followed by its meaning in plain words."""
    errors: list[str] = []
    items, prose = list_items(lines)
    for line in prose:
        errors.append(f"the Plan holds prose, not a checklist item: {line[:60]}")
    if not items:
        errors.append("the Plan has no items")
    for raw in items:
        if not CHECKBOX.match(raw):
            errors.append(f"a Plan item must be a checklist item (`- [ ]` or `- [x]`): {raw[:60]}")
            continue
        text = MD_LINK.sub(r"\1", INLINE_CODE.sub(" ", CHECKBOX.sub("", raw).replace("~~", "").strip()))
        ref = INTERNAL_REF.match(text)
        rest = text[ref.end():] if ref else text
        glossed = not ref or (GLOSS.match(rest) and re.search(r"\w", GLOSS.sub("", rest, count=1)))
        if not text or not glossed:
            errors.append(f"a Plan item needs its meaning in plain words, such as `W3 (cache totals)`: {raw[:60]}")
    return errors


def check_po(o: Outline) -> list[str]:
    """Checks for a reader without the repo, such as a product owner on Linear
    (issues.md §9.4)."""
    errors: list[str] = []
    tldr = next((h for h in o.order if h in TLDR_HEADINGS), None)
    if tldr is not None:
        for line, fenced in o.sections[tldr]:
            if fenced:
                continue
            ref = INTERNAL_REF.search(INLINE_CODE.sub(" ", line))
            if ref:
                errors.append(f"the TL;DR names an internal reference ({ref.group(0)}); say it in product words")
            if PATH_IN_CODE.search(line) or BARE_PATH.search(INLINE_CODE.sub(" ", line)):
                errors.append(f"the TL;DR names a file path; say it in product words: {line.strip()[:60]}")
    texts = [line for h in o.order if h != "appendix" for line, fenced in o.sections[h] if not fenced]
    errors += unglossed_refs(texts)
    if "evidence" in o.sections:
        _, claims = check_claims(o.sections["evidence"], "evidence")
        for claim in claims:
            body = claim.split(":", 1)[1] if ":" in claim else claim
            words = re.findall(r"[A-Za-z][\w'-]*", INLINE_CODE.sub(" ", body))
            if len(words) < PO_MIN_WORDS:
                errors.append(f"an Evidence claim needs its meaning in plain words, not only code: {claim[:60]}")
    return errors


def check_body(body: str, names: list[str], linear: bool = False) -> list[str]:
    """Problems with an issue body (issues.md §6): a TL;DR first, evidence as
    labelled claims (or a plan, for a tracking issue, §10), and any appendix
    marked as one and placed last. `linear` adds the §9.4 checks."""
    errors: list[str] = []
    o = outline(body)
    if o.preamble:
        errors.append(f"the body must open with `## TL;DR`, but text comes before it: {o.preamble[0][:60]}")
    tldr = next((h for h in o.order if h in TLDR_HEADINGS), None)
    if tldr is None:
        errors.append("no `## TL;DR` section; the body opens with one (what, impact and severity, next step)")
    else:
        if o.order[0] != tldr:
            errors.append(f"`## TL;DR` must be the first section, but `## {o.order[0]}` comes first")
        errors += check_tldr(o.sections[tldr])
    errors += check_appendix(o)
    if linear:
        errors += check_po(o)

    tracking = "plan" in o.sections
    if tracking:
        errors += check_plan(o.sections["plan"])
        items, _ = list_items(o.sections[tldr]) if tldr else ([], [])
        if not any(i.replace("**", "").lower().startswith("status:") for i in items):
            errors.append("a tracking issue's TL;DR needs a `Status:` item (how far along, and whether on track)")
    if "evidence" not in o.sections:
        if not tracking:
            errors.append("no `## Evidence` section")
        return errors
    claim_errors, claims = check_claims(o.sections["evidence"], "evidence")
    errors += claim_errors
    if not claims:
        errors.append("the Evidence section has no claims")
    if "investigation" in (n.lower() for n in names) and not any(c.startswith("Inferred:") for c in claims):
        errors.append("an investigation issue needs an `Inferred:` claim stating the unverified claim")
    return errors


def check_comment(text: str, linear: bool = False) -> list[str]:
    """Problems with an update comment (issues.md §7): it opens with a
    `**TL;DR:** <what changed>` line, and any list item is a labelled claim."""
    lines = text.strip().splitlines()
    if not lines:
        return ["the comment is empty"]
    first = COMMENT_TLDR.match(lines[0].strip())
    if first is None:
        return [f"the comment must open with `**TL;DR:** <what changed>`, not: {lines[0].strip()[:60]}"]
    if len(first.group(1).split()) < 3:
        return ["the comment's TL;DR line is empty; say what changed and what it means now"]
    rest = list(zip(lines[1:], fenced_lines(lines[1:])))
    errors, _ = check_claims(rest, "comment")
    errors = [e for e in errors if "holds prose" not in e]  # a comment may explain in prose
    if linear:
        errors += unglossed_refs([lines[0]] + [line for line, fenced in rest if not fenced])
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


def cmd_check_body(body_file: str, kind: str | None, linear: bool) -> int:
    errors = check_body(Path(body_file).read_text(encoding="utf-8"), [kind] if kind else [], linear)
    return report(errors, "body follows the shape")


def cmd_check_comment(body_file: str, linear: bool) -> int:
    return report(check_comment(Path(body_file).read_text(encoding="utf-8"), linear), "comment opens with a TL;DR")


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

    body = ("## TL;DR\n\n- The backup skips /etc.\n- Severity: low, because x.\n- Next: y.\n\n"
            "## Evidence\n\n- Verified live: `x` printed `y`\n- [ ] Read in repo: `a.py:1`\n\n"
            "![shot](https://example.com/a.png)\n\n## Appendix\n\n### A.1 Output\n\n- z\n")
    expect(not check_body(body, ["bug"]), f"good body rejected: {check_body(body, ['bug'])}")
    expect(bool(check_body(body, ["investigation"])), "investigation with no Inferred claim accepted")
    for fault, broken in {
        "unlabelled claim": body.replace("- Verified live: ", "- "),
        "prose": body.replace("## Evidence\n", "## Evidence\n\nLooks bad.\n"),
        "no evidence": body.replace("## Evidence", "## Facts"),
        "no tldr": body.replace("## TL;DR", "## Summary"),
        "text before the tldr": "Summary.\n\n" + body,
        "one-item tldr": body.replace("- Severity: low, because x.\n- Next: y.\n", ""),
        "long tldr": body.replace("- Next: y.", "- Next: " + "y " * 100),
        "tldr points below": body.replace("- Next: y.", "- Next: see below."),
        "appendix not last": body + "\n## Notes\n\n- n\n",
        "appendix misnamed": body.replace("## Appendix", "## Appendix: logs"),
        "appendix sub-heading": body.replace("## Evidence\n", "## Evidence\n\n### Appendix\n"),
    }.items():
        expect(bool(check_body(broken, ["bug"])), f"check_body accepted {fault}")
    expect(not POINTS_BELOW.search("disk use drops below 5%"), "a plain 'below' counted as pointing below")

    tracking = ("## TL;DR\n\n- Ship X.\n- Status: 1 of 2 done.\n- Next: y.\n\n"
                "## Plan\n\n- [x] W1 (add the index)\n- [ ] W2 (page the list)\n")
    expect(not check_body(tracking, ["enhancement"], linear=True), f"good tracking body rejected: {check_body(tracking, ['enhancement'], True)}")
    for fault, broken in {
        "no status": tracking.replace("- Status: 1 of 2 done.\n", ""),
        "bare plan id": tracking.replace("- [ ] W2 (page the list)", "- [ ] W2"),
        "plan item not a checklist": tracking.replace("- [ ] W2", "- W2"),
    }.items():
        expect(bool(check_body(broken, ["enhancement"])), f"check_body accepted a tracking issue with {fault}")
    expect(bool(check_body(tracking.replace("- Next: y.", "- Next: W2 (page)."), [], linear=True)), "--linear accepted an ID in the TL;DR")
    expect(bool(unglossed_refs(["W2 is done"])), "an unexplained W2 passed")
    expect(not unglossed_refs(["W2 (retry) is done", "then W2 again", "`W3` in code"]), "a glossed or coded ref failed")

    comment = "**TL;DR:** Cause found: the check runs first.\n\n- Verified live: `x` printed `y`\n"
    expect(not check_comment(comment), f"good comment rejected: {check_comment(comment)}")
    for fault, broken in {
        "no tldr": comment.replace("**TL;DR:** ", ""),
        "empty tldr": "**TL;DR:**\n\n- Verified live: x\n",
        "unlabelled claim": comment.replace("- Verified live: ", "- "),
    }.items():
        expect(bool(check_comment(broken)), f"check_comment accepted {fault}")

    for failure in failures:
        print(f"FAIL {failure}")
    if failures:
        return 1
    print(f"issue_labels selftest OK ({len(scheme)} labels parsed; label, body, comment and table checks seeded red)")
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
    p_body = sub.add_parser("check-body", help="check a body alone, for a tracker other than GitHub")
    p_body.add_argument("--body-file", required=True)
    p_body.add_argument("--type", help="the issue's type; `investigation` also needs an Inferred claim")
    p_body.add_argument("--linear", action="store_true", help="also check it reads without the repo (issues.md §9.4)")
    p_comment = sub.add_parser("check-comment", help="check an update comment")
    p_comment.add_argument("--body-file", required=True)
    p_comment.add_argument("--linear", action="store_true", help="also check internal references carry their meaning")
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
        if args.command == "check-body":
            return cmd_check_body(args.body_file, args.type, args.linear)
        if args.command == "check-comment":
            return cmd_check_comment(args.body_file, args.linear)
        if args.command == "check":
            return cmd_check(scheme, args.repo, split_labels(args.labels, args.label), args.body_file)
        expect = None if args.expect is None and not args.expect_label else split_labels(args.expect, args.expect_label)
        return cmd_verify(scheme, args.repo, args.issue, expect)
    except (SchemeError, GhError, UsageError, OSError, UnicodeDecodeError) as exc:
        print(f"issue_labels: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
