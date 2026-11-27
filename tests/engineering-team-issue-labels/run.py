#!/usr/bin/env python3
"""End-to-end tests for the engineering-team skill's scripts/issue_labels.py.

Each test runs the real script against a fake `gh` (fake_gh.py, put first on
PATH) whose repo state lives in a temporary JSON file, then asserts on the exit
code, the output, the calls made and the state left behind. No network, no
GitHub login, stdlib only, so it runs in CI.

    python3 tests/engineering-team-issue-labels/run.py
"""

import json
import os
import subprocess
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SCRIPT = REPO / "configs/claude/skills/engineering-team/scripts/issue_labels.py"
SCHEME = REPO / "configs/claude/skills/engineering-team/references/issues.md"

SCHEME_NAMES = {
    "bug", "enhancement", "maintenance", "investigation", "documentation", "dependencies",
    "severity: critical", "severity: high", "severity: medium", "severity: low",
    "security", "reliability", "performance",
}

GOOD_BODY = """## TL;DR

- The nightly backup skips /etc when the pool is degraded.
- Impact: a restore loses /etc. Severity: high, because the loss is silent.
- Next: back up /etc before the pool check.

## Evidence

- Verified live: `zpool status` printed `DEGRADED`
- Read in repo: `backup.sh:42` returns early on a degraded pool

## Appendix

### A.1 Full zpool status

<details><summary>zpool status</summary>

```text
pool: tank
```

</details>

---

Not fixed now: out of scope in the plan. · Found by: engineering-team run manual-x, 2026-11-27
"""

GOOD_COMMENT = """**TL;DR:** Cause found: the pool check runs before the /etc copy.

- Verified live: `backup.sh --dry-run` printed `skip /etc (pool DEGRADED)`
"""


class Repo:
    """A temporary repo state plus a PATH that resolves `gh` to the fake."""

    def __init__(self, tmp: Path, labels: list[dict[str, str]] | None = None,
                 issues: dict[str, dict[str, object]] | None = None, fail: bool = False,
                 garbage: bool = False) -> None:
        self.state = tmp / "state.json"
        self.log = tmp / "calls.log"
        self.log.write_text("")
        self.state.write_text(json.dumps({"labels": labels or [], "issues": issues or {}, "fail": fail, "garbage": garbage}))
        bindir = tmp / "bin"
        bindir.mkdir()
        gh = bindir / "gh"
        gh.write_text(f'#!/bin/sh\nexec "{sys.executable}" "{HERE / "fake_gh.py"}" "$@"\n')
        gh.chmod(0o755)
        self.env = {**os.environ, "PATH": f"{bindir}{os.pathsep}{os.environ['PATH']}",
                    "FAKE_GH_STATE": str(self.state), "FAKE_GH_LOG": str(self.log)}

    def run(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=self.env,
                              capture_output=True, text=True)

    def labels(self) -> dict[str, dict[str, str]]:
        return {label["name"]: label for label in json.loads(self.state.read_text())["labels"]}

    def writes(self) -> list[list[str]]:
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        return [c for c in calls if c[:2] == ["label", "create"]]


def canonical() -> list[dict[str, str]]:
    """The scheme as the script itself reports it, so the tests hold no copy."""
    out = subprocess.run([sys.executable, str(SCRIPT), "list", "--json"], capture_output=True, text=True)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout)


def expect(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


# ---- apply -----------------------------------------------------------------

def test_list_matches_scheme(tmp: Path) -> None:
    labels = canonical()
    expect({label["name"] for label in labels} == SCHEME_NAMES, f"scheme names differ: {labels}")
    expect(all(len(label["color"]) == 6 for label in labels), "a colour is not six hex digits")


def test_dry_run_writes_nothing(tmp: Path) -> None:
    repo = Repo(tmp)
    out = repo.run("apply", "--dry-run")
    expect(out.returncode == 0, f"exit {out.returncode}: {out.stderr}")
    expect(repo.writes() == [], f"dry run wrote: {repo.writes()}")
    expect(repo.labels() == {}, "dry run changed the repo")
    expect(out.stdout.count("would create") == 13, f"expected 13 planned creates:\n{out.stdout}")


def test_apply_creates_missing(tmp: Path) -> None:
    repo = Repo(tmp)
    out = repo.run("apply")
    expect(out.returncode == 0, f"exit {out.returncode}: {out.stderr}")
    expect(set(repo.labels()) == SCHEME_NAMES, f"labels after apply: {set(repo.labels())}")
    expect(all("--force" in call for call in repo.writes()), "a create ran without --force")
    for label in canonical():
        got = repo.labels()[label["name"]]
        expect(got["color"] == label["color"] and got["description"] == label["description"],
               f"{label['name']} landed as {got}")


def test_second_apply_is_idempotent(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical())
    out = repo.run("apply")
    expect(out.returncode == 0, f"exit {out.returncode}: {out.stderr}")
    expect(repo.writes() == [], f"apply on a current repo wrote: {repo.writes()}")


def test_apply_resets_drift_and_never_renames(tmp: Path) -> None:
    labels = canonical()
    for label in labels:
        if label["name"] == "security":
            label.update(color="8B0000", description="Security hardening or a security gap")
        if label["name"] == "bug":
            label.update(name="Bug", color="ffffff")
    repo = Repo(tmp, labels=labels)
    out = repo.run("apply")
    expect(out.returncode == 0, f"exit {out.returncode}: {out.stderr}")
    expect(len(repo.writes()) == 2, f"expected 2 updates, got {repo.writes()}")
    expect("Bug" in repo.labels() and "bug" not in repo.labels(), "apply renamed Bug to bug")
    # GitHub matches label names case-insensitively, so the end state alone cannot
    # show a rename. The contract is that the script passes the repo's spelling.
    expect(any(call[2] == "Bug" for call in repo.writes()), f"update did not use the repo's spelling: {repo.writes()}")
    expect(repo.labels()["Bug"]["color"] == "d73a4a", "Bug kept its drifted colour")
    expect(repo.labels()["security"]["color"] == "5319e7", "security kept its drifted colour")


def test_apply_leaves_other_labels_alone(tmp: Path) -> None:
    others = [{"name": "home-assistant", "color": "41BDF5", "description": "HA"},
              {"name": "wontfix", "color": "ffffff", "description": "no"}]
    repo = Repo(tmp, labels=canonical() + others)
    out = repo.run("apply")
    expect(out.returncode == 0, f"exit {out.returncode}: {out.stderr}")
    expect(repo.writes() == [], f"apply touched a non-scheme label: {repo.writes()}")


def test_apply_passes_repo(tmp: Path) -> None:
    repo = Repo(tmp)
    out = repo.run("apply", "--repo", "someone/thing")
    expect(out.returncode == 0, f"exit {out.returncode}: {out.stderr}")
    calls = [json.loads(line) for line in repo.log.read_text().splitlines()]
    expect(all(c[-2:] == ["-R", "someone/thing"] for c in calls), f"a call lacked -R: {calls}")


def test_gh_failure_exits_2(tmp: Path) -> None:
    repo = Repo(tmp, fail=True)
    out = repo.run("apply")
    expect(out.returncode == 2, f"expected exit 2, got {out.returncode}")
    expect("gh auth login" in out.stderr, f"gh's error was not passed on: {out.stderr}")


def test_broken_scheme_exits_2(tmp: Path) -> None:
    broken = tmp / "issues.md"
    broken.write_text(SCHEME.read_text().replace("`#d73a4a`", "`#d73a4`"))
    repo = Repo(tmp)
    out = repo.run("--scheme", str(broken), "apply", "--dry-run")
    expect(out.returncode == 2, f"expected exit 2 on a bad colour, got {out.returncode}")
    expect("bug" in out.stderr, f"error does not name the label: {out.stderr}")


def test_non_json_from_gh_exits_2(tmp: Path) -> None:
    repo = Repo(tmp, garbage=True)
    out = repo.run("apply", "--dry-run")
    expect(out.returncode == 2, f"expected exit 2 on non-JSON gh output, got {out.returncode}: {out.stderr}")
    expect("Traceback" not in out.stderr, f"a traceback leaked: {out.stderr}")


def test_truncated_label_list_exits_2(tmp: Path) -> None:
    many = [{"name": f"area-{i}", "color": "ffffff", "description": "x"} for i in range(1000)]
    repo = Repo(tmp, labels=many)
    out = repo.run("apply", "--dry-run")
    expect(out.returncode == 2, f"a 1000-label list was trusted as complete: {out.returncode}")


# ---- check -----------------------------------------------------------------

HOME = [{"name": "home-assistant", "color": "41BDF5", "description": "HA"},
        {"name": "wontfix", "color": "ffffff", "description": "no"}]


def run_with_file(repo: Repo, text: str, *args: str) -> subprocess.CompletedProcess[str]:
    path = repo.state.parent / "text.md"
    path.write_text(text)
    return repo.run(*args, "--body-file", str(path))


def check(repo: Repo, labels: str, body: str | None = None) -> subprocess.CompletedProcess[str]:
    args = ["check", "--labels", labels]
    if body is not None:
        path = repo.state.parent / "body.md"
        path.write_text(body)
        args += ["--body-file", str(path)]
    return repo.run(*args)


def test_check_accepts_a_good_set(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical() + HOME)
    out = check(repo, "bug,severity: high,security,home-assistant", GOOD_BODY)
    expect(out.returncode == 0, f"good set rejected: {out.stdout}{out.stderr}")


def test_check_label_set_violations(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical() + HOME)
    cases = {
        "severity: high": "type",                         # no type
        "bug,maintenance,severity: high": "type",         # two types
        "bug": "severity",                                # no severity
        "bug,severity: high,severity: low": "severity",   # two severities
        "bug,severity: high,wontfix": "wontfix",          # triage default
        "bug,severity: high,made-up-area": "made-up-area",  # invented area
        "Bug,BUG,severity: high": "twice",               # same label, two spellings
    }
    for labels, word in cases.items():
        out = check(repo, labels)
        expect(out.returncode == 1, f"{labels!r}: expected exit 1, got {out.returncode}")
        expect(word in out.stdout, f"{labels!r}: output does not name {word!r}: {out.stdout}")


def test_check_is_case_insensitive(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical() + HOME)
    out = check(repo, "Bug,Severity: High,Home-Assistant")
    expect(out.returncode == 0, f"case variants rejected: {out.stdout}{out.stderr}")


def test_check_label_flag_keeps_commas(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical() + [{"name": "api, v2", "color": "ffffff", "description": "x"}])
    out = repo.run("check", "--label", "bug", "--label", "severity: low", "--label", "api, v2")
    expect(out.returncode == 0, f"a label with a comma was split: {out.stdout}{out.stderr}")


def test_check_triage_label_needs_no_gh(tmp: Path) -> None:
    repo = Repo(tmp, fail=True)
    out = check(repo, "bug,severity: low,wontfix")
    expect(out.returncode == 1, f"expected a check failure without calling gh, got {out.returncode}")


def test_check_missing_body_file_exits_2(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical())
    out = repo.run("check", "--labels", "bug,severity: low", "--body-file", str(tmp / "nope.md"))
    expect(out.returncode == 2, f"expected exit 2 for a missing body file, got {out.returncode}")


def test_body_fences_and_formatting(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical())
    fenced = GOOD_BODY.replace(
        "- Read in repo: `backup.sh:42` returns early on a degraded pool",
        "- Verified live: the log printed\n\n```\n## not a heading\n```\n\n"
        "- **Read in repo:** `backup.sh:42` returns early\n\n### Detail\n\n- Inferred: x. Settled by: y")
    out = check(repo, "investigation,severity: high", fenced)
    expect(out.returncode == 0, f"fence, bold label or sub-heading broke the body check: {out.stdout}")
    fake_tldr = "```\n## TL;DR\n```\n\n" + GOOD_BODY.split("\n\n", 1)[1]
    out = check(repo, "bug,severity: high", fake_tldr)
    expect(out.returncode == 1, f"a fenced `## TL;DR` counted as the section: {out.stdout}")


def test_body_accepts_checklist_image_diagram_and_no_appendix(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical())
    body = GOOD_BODY.replace(
        "- Read in repo: `backup.sh:42` returns early on a degraded pool",
        "- [ ] Read in repo: `backup.sh:42` returns early\n- [x] Read in repo: `cron:3` runs it nightly\n\n"
        "![The restore dialog lists no /etc](https://example.com/a.png)\n\n"
        "```mermaid\nflowchart LR\n  A --> B\n```")
    out = check(repo, "bug,severity: low", body)
    expect(out.returncode == 0, f"checklist, image or mermaid broke the body check: {out.stdout}")
    out = check(repo, "bug,severity: high", GOOD_BODY.split("## Appendix")[0])
    expect(out.returncode == 0, f"a body with no appendix failed: {out.stdout}")
    footer = "\n---\n\n" + GOOD_BODY.split("---\n", 1)[1]
    out = check(repo, "bug,severity: high", GOOD_BODY.split("## Appendix")[0] + footer)
    expect(out.returncode == 0, f"a body with a footer and no appendix failed: {out.stdout}")
    out = check(repo, "bug,severity: high", GOOD_BODY + "\n## Related\n\n- #12\n")
    expect(out.returncode == 1, f"a section after the footer escaped the appendix-last check: {out.stdout}")


def test_markdown_edge_cases(tmp: Path) -> None:
    """Real bodies use more of markdown than the template: each of these broke
    an earlier parser (found in review, 2026-11-27)."""
    repo = Repo(tmp, labels=canonical())
    claim = "- Read in repo: `backup.sh:42` returns early on a degraded pool"
    accepted = {
        "tilde fence": GOOD_BODY.replace(claim, claim + "\n\n~~~\nraw output\n## Appendix\n~~~"),
        "raw output in details": GOOD_BODY.replace(
            claim, claim + "\n\n<details><summary>log</summary>\n\nraw output line\n\n</details>"),
        "hard-wrapped item": GOOD_BODY.replace(claim, "- Read in repo: `backup.sh:42` returns early\non a degraded pool"),
        "image as a list item": GOOD_BODY.replace(claim, claim + "\n- ![The dialog](https://example.com/a.png)"),
        "linked image": GOOD_BODY.replace(claim, claim + "\n\n[![The dialog](https://e.com/a.png)](https://e.com/a.png)"),
        "four-backtick fence holding three": GOOD_BODY.replace(claim, claim + "\n\n````\n```\n## Appendix\n````"),
        "nested item in the tldr": GOOD_BODY.replace("- Next: back up /etc", "  - with a nested note\n- Next: back up /etc"),
        "crlf line endings": GOOD_BODY.replace("\n", "\r\n"),
    }
    for name, body in accepted.items():
        out = check(repo, "bug,severity: high", body)
        expect(out.returncode == 0, f"{name}: a valid body failed: {out.stdout}")
    rejected = {
        "indented prose hides in the tldr": (GOOD_BODY.replace("## TL;DR\n", "## TL;DR\n\n    hidden prose\n"), "prose"),
        "an indented continuation counts toward the words": (GOOD_BODY.replace(
            "\n## Evidence", "\n    " + "word " * 80 + "\n\n## Evidence"), "words"),
        "a thematic break pads the tldr": (GOOD_BODY.replace(
            "- Impact: a restore loses /etc. Severity: high, because the loss is silent.\n"
            "- Next: back up /etc before the pool check.\n", "* * *\n"), "2 to 5"),
        "inline triple backticks are not a fence": (GOOD_BODY.replace(
            claim, claim + "\n\n```x``` y") + "\n## Notes\n\n- n\n", "last"),
    }
    for name, (body, reason) in rejected.items():
        out = check(repo, "bug,severity: high", body)
        expect(out.returncode == 1 and reason in out.stdout, f"{name}: expected a {reason!r} failure: {out.stdout}")
    out = run_with_file(repo, GOOD_COMMENT + "\n~~~\n- not a claim\n~~~\n", "check-comment")
    expect(out.returncode == 0, f"a tilde fence in a comment was read as a claim: {out.stdout}")


TRACKING_BODY = """## TL;DR

- Invoice pages take 8 s to load; the goal is under 1 s.
- Status: 2 of 4 steps done, on track.
- Next: cache customer totals.

## Plan

- [x] W1 (add an index for invoice lookups)
- [x] W2 (stop loading every line item up front)
- [ ] W3 (cache customer totals)
- [ ] W4 — page the invoice list

---

Found by: engineering-team run manual-x, 2026-11-27
"""

LINEAR_BODY = """## TL;DR

- Exports silently drop rows when a file is over 10 MB.
- Impact: finance reports undercount revenue. Severity: high, because the loss is silent.
- Next: stream the export instead of buffering it.

## Evidence

- Verified live: a 12 MB export kept 9,000 of 10,000 rows (`export --size 12M`)
- Read in repo: the exporter stops at a fixed buffer size, W2 (retry failed exports) did not touch it (`export.py:88`)
- Read in repo: ADR-7 (exports run on the job queue) puts the buffer limit there, and W2 is unrelated

## Appendix

### A.1 Raw output

W9 shows up here unexplained, which is fine in the appendix.
"""


def test_tracking_issue(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical())
    out = check(repo, "enhancement,severity: medium", TRACKING_BODY)
    expect(out.returncode == 0, f"a good tracking issue failed: {out.stdout}")
    cases = {
        "no status line": (TRACKING_BODY.replace("- Status: 2 of 4 steps done, on track.\n", "- On track.\n"), "Status:"),
        "plan item not a checklist": (TRACKING_BODY.replace("- [ ] W3 (cache", "- W3 (cache"), "checklist"),
        "plan id with no meaning": (TRACKING_BODY.replace("- [ ] W3 (cache customer totals)", "- [ ] W3"), "meaning"),
        "plan holds prose": (TRACKING_BODY.replace("## Plan\n", "## Plan\n\nFour steps.\n"), "prose"),
    }
    for name, (body, reason) in cases.items():
        out = check(repo, "enhancement,severity: medium", body)
        expect(out.returncode == 1 and reason in out.stdout, f"{name}: expected a {reason!r} failure: {out.stdout}")
    no_plan = TRACKING_BODY.replace("## Plan", "## Steps")
    out = check(repo, "enhancement,severity: medium", no_plan)
    expect(out.returncode == 1 and "no `## Evidence`" in out.stdout, f"a body with neither Plan nor Evidence passed: {out.stdout}")


def test_linear_reader_without_the_repo(tmp: Path) -> None:
    repo = Repo(tmp, fail=True)
    out = run_with_file(repo, LINEAR_BODY, "check-body", "--linear")
    expect(out.returncode == 0, f"a PO-readable body failed --linear: {out.stdout}{out.stderr}")
    out = run_with_file(repo, TRACKING_BODY, "check-body", "--linear")
    expect(out.returncode == 0, f"a tracking issue failed --linear: {out.stdout}")
    out = run_with_file(repo, GOOD_BODY, "check-body")
    expect(out.returncode == 0, f"--linear rules leaked into a plain check-body: {out.stdout}")
    cases = {
        "id in the tldr": (LINEAR_BODY.replace("- Next: stream", "- Next: finish W3 (streaming) and stream"), "TL;DR"),
        "path in the tldr": (LINEAR_BODY.replace("- Next: stream the export", "- Next: fix `src/export.py`"), "path"),
        "unexplained unit": (LINEAR_BODY.replace("W2 (retry failed exports) did not touch it", "W2 did not touch it"), "meaning"),
        "unexplained adr": (LINEAR_BODY.replace("ADR-7 (exports run on the job queue)", "ADR-7"), "meaning"),
        "claim that is only code": (LINEAR_BODY.replace(
            "- Verified live: a 12 MB export kept 9,000 of 10,000 rows (`export --size 12M`)",
            "- Verified live: `export --size 12M` printed `9000`"), "plain words"),
    }
    for name, (body, reason) in cases.items():
        out = run_with_file(repo, body, "check-body", "--linear")
        expect(out.returncode == 1 and reason in out.stdout, f"{name}: expected a {reason!r} failure: {out.stdout}")
    more = {
        "lower-case adr": (LINEAR_BODY.replace("ADR-7 (exports run on the job queue)", "adr-7"), "meaning"),
        "bare path in the tldr": (LINEAR_BODY.replace("- Next: stream the export", "- Next: fix src/export.py"), "path"),
    }
    for name, (body, reason) in more.items():
        out = run_with_file(repo, body, "check-body", "--linear")
        expect(out.returncode == 1 and reason in out.stdout, f"{name}: expected a {reason!r} failure: {out.stdout}")
    out = run_with_file(repo, TRACKING_BODY.replace("- [ ] W3 (cache customer totals)", "- [ ] [W3](https://x/3) cache"), "check-body")
    expect(out.returncode == 1 and "meaning" in out.stdout, f"a link-wrapped plan ID with no meaning passed: {out.stdout}")
    struck = TRACKING_BODY.replace("- [ ] W3 (cache customer totals)", "- [ ] ~~W3 (cache customer totals)~~ dropped: no time")
    out = run_with_file(repo, struck, "check-body", "--linear")
    expect(out.returncode == 0, f"a struck, explained plan item failed: {out.stdout}")
    good = "**TL;DR:** W2 (retry failed exports) is done; 2 of 4 steps finished.\n"
    out = run_with_file(repo, good, "check-comment", "--linear")
    expect(out.returncode == 0, f"a glossed comment failed --linear: {out.stdout}")
    out = run_with_file(repo, "**TL;DR:** W2 is done; 2 of 4 steps finished.\n", "check-comment", "--linear")
    expect(out.returncode == 1 and "meaning" in out.stdout, f"an unexplained unit in a comment passed --linear: {out.stdout}")


TLDR = GOOD_BODY.split("## Evidence")[0]
REST = "## Evidence" + GOOD_BODY.split("## Evidence")[1]


def test_check_body_violations(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical())
    cases = {
        "unlabelled claim": (GOOD_BODY.replace("- Read in repo: `backup.sh:42`", "- `backup.sh:42`"), "has no label"),
        "no evidence heading": (GOOD_BODY.replace("## Evidence", "## Facts"), "no `## Evidence`"),
        "prose in evidence": (GOOD_BODY.replace("## Evidence\n", "## Evidence\n\nIt seems broken.\n"), "holds prose"),
        "empty evidence": (TLDR + "## Evidence\n\n## Appendix\n\n- x\n", "has no claims"),
        "no tldr": (REST, "## TL;DR"),
        "text before the tldr": ("The backup is broken.\n\n" + GOOD_BODY, "before"),
        "evidence before the tldr": (REST.split("## Appendix")[0] + TLDR, "first section"),
        "one-item tldr": (GOOD_BODY.replace("- Impact: a restore loses /etc. Severity: high, because the loss is silent.\n"
                                            "- Next: back up /etc before the pool check.\n", ""), "2 to 5"),
        "six-item tldr": (GOOD_BODY.replace("- Next:", "- a\n- b\n- c\n- Next:"), "2 to 5"),
        "long tldr": (GOOD_BODY.replace("- Next: back up /etc", "- Next: " + "word " * 80 + "back up /etc"), "words"),
        "tldr points below": (GOOD_BODY.replace("- Next: back up /etc before the pool check.", "- Next: see below."), "below"),
        "prose tldr": (GOOD_BODY.replace("- The nightly backup", "The nightly backup"), "prose"),
        "empty tldr": ("## TL;DR\n\n" + REST, "2 to 5"),
        "appendix not last": (GOOD_BODY + "\n## Related\n\n- #12\n", "last"),
        "appendix heading misspelled": (GOOD_BODY.replace("## Appendix", "## Appendix: logs"), "exactly"),
        "appendix under evidence": (GOOD_BODY.replace("## Appendix", "### Appendix\n\n## Notes"), "exactly"),
        "two appendices": (GOOD_BODY.replace("## Appendix", "## Appendix\n\n- x\n\n## Appendix"), "one `## Appendix`"),
    }
    for name, (body, reason) in cases.items():
        out = check(repo, "bug,severity: high", body)
        expect(out.returncode == 1, f"{name}: expected exit 1, got {out.returncode}: {out.stdout}")
        expect(reason in out.stdout, f"{name}: failed, but not for {reason!r}: {out.stdout}")


def test_check_body_command_skips_labels(tmp: Path) -> None:
    repo = Repo(tmp, fail=True)  # any gh call fails, so a pass proves none was made
    out = run_with_file(repo, GOOD_BODY, "check-body")
    expect(out.returncode == 0, f"a good body failed check-body: {out.stdout}{out.stderr}")
    out = run_with_file(repo, REST, "check-body")
    expect(out.returncode == 1, f"check-body accepted a body with no TL;DR: {out.stdout}")
    out = run_with_file(repo, GOOD_BODY, "check-body", "--type", "investigation")
    expect(out.returncode == 1, f"check-body accepted an investigation with no Inferred claim: {out.stdout}")
    out = repo.run("check-body", "--body-file", str(tmp / "nope.md"))
    expect(out.returncode == 2, f"expected exit 2 for a missing body file, got {out.returncode}")


def test_check_comment(tmp: Path) -> None:
    repo = Repo(tmp, fail=True)
    out = run_with_file(repo, GOOD_COMMENT, "check-comment")
    expect(out.returncode == 0, f"a good comment failed: {out.stdout}{out.stderr}")
    out = run_with_file(repo, "\n\n" + GOOD_COMMENT.replace("**TL;DR:**", "**TL;DR**:"), "check-comment")
    expect(out.returncode == 0, f"`**TL;DR**:` after blank lines failed: {out.stdout}")
    cases = {
        "no tldr line": GOOD_COMMENT.replace("**TL;DR:** ", ""),
        "tldr not first": "Update.\n\n" + GOOD_COMMENT,
        "empty tldr": "**TL;DR:**\n\n- Verified live: x",
        "tldr heading instead of line": GOOD_COMMENT.replace("**TL;DR:** ", "## TL;DR\n\n"),
        "unlabelled claim": GOOD_COMMENT.replace("- Verified live: ", "- "),
    }
    for name, comment in cases.items():
        out = run_with_file(repo, comment, "check-comment")
        expect(out.returncode == 1, f"{name}: expected exit 1, got {out.returncode}: {out.stdout}")
        reason = "has no label" if name == "unlabelled claim" else "TL;DR"
        expect(reason in out.stdout, f"{name}: failed, but not for {reason!r}: {out.stdout}")


def test_investigation_needs_an_inferred_claim(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical())
    out = check(repo, "investigation,severity: critical", GOOD_BODY)
    expect(out.returncode == 1, f"investigation with no Inferred claim passed: {out.stdout}")
    body = GOOD_BODY.replace("## Appendix", "- Inferred: the restore drops /etc. Settled by: a test restore\n\n## Appendix")
    out = check(repo, "investigation,severity: critical", body)
    expect(out.returncode == 0, f"investigation with an Inferred claim failed: {out.stdout}")


def test_check_scheme_only_set_needs_no_gh(tmp: Path) -> None:
    repo = Repo(tmp, fail=True)
    out = check(repo, "bug,severity: low")
    expect(out.returncode == 0, f"a scheme-only set called gh: {out.stdout}{out.stderr}")


# ---- verify ----------------------------------------------------------------

def test_verify_passes_when_labels_landed(tmp: Path) -> None:
    issues = {"7": {"labels": ["bug", "severity: high", "security"], "body": GOOD_BODY}}
    repo = Repo(tmp, labels=canonical(), issues=issues)
    out = repo.run("verify", "--issue", "7", "--expect", "bug,severity: high,security")
    expect(out.returncode == 0, f"verify failed: {out.stdout}{out.stderr}")


def test_verify_reds_on_a_missing_label(tmp: Path) -> None:
    issues = {"7": {"labels": ["bug", "severity: high"], "body": GOOD_BODY}}
    repo = Repo(tmp, labels=canonical(), issues=issues)
    out = repo.run("verify", "--issue", "7", "--expect", "bug,severity: high,security")
    expect(out.returncode == 1, f"expected exit 1, got {out.returncode}")
    expect("security" in out.stdout, f"output does not name the missing label: {out.stdout}")


def test_verify_reds_on_an_extra_label(tmp: Path) -> None:
    issues = {"7": {"labels": ["bug", "severity: high", "security"], "body": GOOD_BODY}}
    repo = Repo(tmp, labels=canonical(), issues=issues)
    out = repo.run("verify", "--issue", "7", "--expect", "bug,severity: high")
    expect(out.returncode == 1 and "not expected" in out.stdout, f"an unexpected label passed: {out.stdout}")


def test_verify_reds_on_scheme_violation(tmp: Path) -> None:
    issues = {"9": {"labels": ["bug"], "body": GOOD_BODY}}
    repo = Repo(tmp, labels=canonical(), issues=issues)
    out = repo.run("verify", "--issue", "9")
    expect(out.returncode == 1, f"an issue with no severity verified: {out.stdout}")


def test_verify_unknown_issue_exits_2(tmp: Path) -> None:
    repo = Repo(tmp, labels=canonical())
    out = repo.run("verify", "--issue", "404")
    expect(out.returncode == 2, f"expected exit 2, got {out.returncode}")


TESTS: list[Callable[[Path], None]] = [
    obj for name, obj in sorted(globals().items()) if name.startswith("test_") and callable(obj)
]


def main() -> int:
    failed = 0
    for test in TESTS:
        with tempfile.TemporaryDirectory() as tmp:
            try:
                test(Path(tmp))
                print(f"ok   {test.__name__}")
            except Exception as exc:  # noqa: BLE001 - report every failure, keep going
                failed += 1
                print(f"FAIL {test.__name__}: {exc}")
    print(f"\n{len(TESTS) - failed} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
