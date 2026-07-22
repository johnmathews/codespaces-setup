#!/usr/bin/env python3
"""Measure the engineering-team skill's description as a trigger classifier.

For each labelled prompt in `eval-set.json`, this asks a fresh `claude -p`
router to choose among the engineering-team description, one foil route
(deep-research), and NONE (handle directly). Each prompt is run `--runs` times
to get a trigger *rate* (trigger decisions are probabilistic); a prompt is
scored correct when the rate lands on the labelled side of `--threshold`.

Only the engineering-team description varies between runs — editing it is what
this test measures. The foil roster (see ROUTER_PROMPT) is frozen harness
context, there so that "should route elsewhere" negatives are well-posed. What
this is NOT is the full in-vivo routing decision against every installed skill —
the skill-creator harness (`run_eval.py`) does that; see README.md for when to
reach for which, and why this test is not in CI.

Stdlib only. Requires the `claude` CLI on PATH and authenticated (it reuses the
session's Claude Code auth, so no separate API key is needed).

Usage:
    python3 run.py                     # defaults reproduce baseline.md
    python3 run.py --json out.json     # also dump the full result JSON
    python3 run.py --model claude-sonnet-5 --runs 3   # cheaper, noisier
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
EVAL_SET = HERE / "eval-set.json"
SKILL_MD = REPO / "configs/claude/skills/engineering-team/SKILL.md"

# The router faces a realistic choice: engineering-team, one foil route
# (deep-research), or NONE. The foil roster is FROZEN harness context drawn from
# the boundaries the engineering-team description itself names ("that is the
# deep-research skill", "reviewing a single diff/PR", "a quick targeted fix").
# It makes "should route elsewhere" negatives well-posed — an isolated
# single-description classifier over-fires on them because no alternative exists.
# Only the engineering-team description varies between runs; editing it is what
# this test measures.
ROUTER_PROMPT = """You are the skill-routing component of an AI coding assistant. When a user sends a message you route it to the single best-fitting specialized skill, or to NONE when you would just handle it directly. Here are the available routes:

ENGINEERING-TEAM — use when the message matches this skill's description:
<description>
{description}
</description>

DEEP-RESEARCH — a standalone research question with no specific codebase in play (e.g. "what is the state of the art in X").

NONE (handle it directly, no skill) — anything else, and in particular: reviewing a single diff or pull request, or a quick targeted fix to one known spot.

Decide the single best route. You may reason briefly first, but your reply MUST END with a final line in exactly this form, and nothing after it:
ROUTE: ENGINEERING-TEAM
(or `ROUTE: DEEP-RESEARCH`, or `ROUTE: NONE`)

User message: {query}
"""

_TOKENS = {"ENGINEERING-TEAM": True, "DEEP-RESEARCH": False, "NONE": False}


def _verdict(text: str) -> bool:
    """Map a router reply to fire (True) / no-fire (False).

    The router may reason first, so the decision is the LAST `ROUTE: <token>`
    line — not the first token mentioned. (Models sometimes blurt a token, then
    self-correct: "ENGINEERING-TEAM\\nNONE\\nWait, this is a quick fix..." — the
    final ROUTE line is the concluded answer.) Raises if no ROUTE line resolves,
    so a malformed reply is a logged lost vote, not a silently miscounted one.
    """
    verdict: bool | None = None
    for raw in text.splitlines():
        head = raw.strip().lstrip("*#->` ").upper()
        if not head.startswith("ROUTE:"):
            continue
        token = head[len("ROUTE:"):].strip().strip("`*").split()[0] if head[len("ROUTE:"):].strip() else ""
        if token in _TOKENS:
            verdict = _TOKENS[token]  # keep the last one
    if verdict is None:
        raise RuntimeError(f"unparseable verdict: {text[:160]!r}")
    return verdict


def parse_description(skill_md: Path) -> str:
    """Extract the (possibly folded) `description:` scalar from the frontmatter.

    Mirrors the folded/literal-block handling in skill-creator's parse_skill_md
    so the text tested here is byte-for-byte what the skill ships.
    """
    lines = skill_md.read_text().split("\n")
    if lines[0].strip() != "---":
        raise ValueError(f"{skill_md} has no frontmatter")
    try:
        end = next(i for i, ln in enumerate(lines[1:], 1) if ln.strip() == "---")
    except StopIteration:
        raise ValueError(f"{skill_md} frontmatter is not closed") from None
    fm = lines[1:end]
    for i, line in enumerate(fm):
        if line.startswith("description:"):
            val = line[len("description:"):].strip()
            if val in (">", "|", ">-", "|-"):
                # Collect the indented continuation. A blank line inside a block
                # scalar is a paragraph break (YAML folds it to a newline), NOT a
                # terminator — treating it as one would silently drop everything
                # after the first paragraph if the description is ever split for
                # readability. The block ends only at a non-indented, non-blank
                # line (the next frontmatter key; the closing `---` is already
                # excluded from `fm`).
                paras: list[list[str]] = [[]]
                for j in range(i + 1, len(fm)):
                    if fm[j].strip() == "":
                        paras.append([])
                    elif fm[j].startswith(("  ", "\t")):
                        paras[-1].append(fm[j].strip())
                    else:
                        break
                return "\n".join(" ".join(p) for p in paras if p)
            return val.strip('"').strip("'")
    raise ValueError(f"{skill_md} frontmatter has no description")


def one_run(description: str, query: str, model: str, timeout: int) -> bool:
    """One router decision. Returns True (would invoke) / False (would not)."""
    prompt = ROUTER_PROMPT.format(description=description, query=query)
    # Drop CLAUDECODE so `claude -p` can nest inside a Claude Code session.
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    proc = subprocess.run(
        ["claude", "-p", "--output-format", "text", "--model", model],
        input=prompt, capture_output=True, text=True, env=env, timeout=timeout,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"claude -p exited {proc.returncode}: {proc.stderr[:300]}")
    text = proc.stdout.strip()
    if not text:
        raise RuntimeError("claude -p returned empty output")
    return _verdict(text)


def run(items: list[dict], description: str, model: str, runs: int,
        threshold: float, workers: int, timeout: int) -> dict:
    tasks = [(it, r) for it in items for r in range(runs)]
    votes: dict[str, list[bool]] = {it["id"]: [] for it in items}
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(one_run, description, it["query"], model, timeout): it["id"]
                for it, _ in tasks}
        for fut in as_completed(futs):
            iid = futs[fut]
            try:
                votes[iid].append(fut.result())
            except Exception as exc:  # noqa: BLE001 — a failed call is a lost vote, not fatal
                print(f"WARN {iid}: {exc}", file=sys.stderr)

    by_id = {it["id"]: it for it in items}
    results = []
    for iid in sorted(votes):
        it, vs = by_id[iid], votes[iid]
        rate = sum(vs) / len(vs) if vs else 0.0
        fires = rate >= threshold
        results.append({
            "id": iid,
            "category": it["category"],
            "should_trigger": it["should_trigger"],
            "trigger_rate": round(rate, 3),
            "fires": sum(vs),
            "runs": len(vs),
            "correct": bool(vs) and fires == it["should_trigger"],
            "query": it["query"],
        })
    return {
        "model": model, "runs_per_prompt": runs, "threshold": threshold,
        "total": len(results),
        "correct": sum(1 for r in results if r["correct"]),
        "results": results,
    }


def selftest() -> int:
    """Headless checks for the deterministic parsers + the eval set.

    The LLM routing can't run in CI, but the two pure functions that turn a
    reply / a SKILL.md into a scored result CAN — and they are exactly where a
    silent bug produces a confident wrong number (a first-token parser once
    scored a self-correcting reply's false start; a naive continuation loop once
    truncated a folded description at its first blank line). This guards both.
    """
    failures: list[str] = []

    def check(cond: bool, msg: str) -> None:
        if not cond:
            failures.append(msg)

    # _verdict: last ROUTE line wins; reasoning/markdown tolerated; junk raises.
    verdict_cases = [
        ("ROUTE: ENGINEERING-TEAM", True),
        ("reasoning.\nROUTE: NONE", False),
        ("ENGINEERING-TEAM\nNONE\nwait, quick fix.\nROUTE: NONE", False),  # false start
        ("ROUTE: ENGINEERING-TEAM\nactually no.\nROUTE: NONE", False),     # self-correction
        ("`ROUTE: DEEP-RESEARCH`", False),
        ("**ROUTE: NONE**", False),
        ("ROUTE:ENGINEERING-TEAM", True),
    ]
    for text, want in verdict_cases:
        try:
            check(_verdict(text) == want, f"_verdict({text!r}) != {want}")
        except RuntimeError:
            failures.append(f"_verdict({text!r}) raised unexpectedly")
    for junk in ("I think NONE fits.", "ROUTE: MAYBE"):
        try:
            _verdict(junk)
            failures.append(f"_verdict({junk!r}) should have raised")
        except RuntimeError:
            pass

    # parse_description: current file parses; a two-paragraph folded block keeps
    # BOTH paragraphs (the review's silent-truncation bug); block ends at next key.
    check(len(parse_description(SKILL_MD)) > 0, "current SKILL.md description is empty")
    with tempfile.TemporaryDirectory() as d:
        two = Path(d) / "two.md"
        two.write_text("---\nname: x\ndescription: >\n  Para one\n  line two.\n\n"
                       "  Para two survives.\n---\n")
        got = parse_description(two)
        check("Para two survives." in got, f"folded 2nd paragraph dropped: {got!r}")
        check(got == "Para one line two.\nPara two survives.", f"folded join wrong: {got!r}")
        nk = Path(d) / "nk.md"
        nk.write_text("---\ndescription: >\n  Only line.\nother: 1\n---\n")
        check(parse_description(nk) == "Only line.", "block did not stop at next key")

    # eval set: well-formed, balanced-ish, unique ids, required keys.
    items = json.loads(EVAL_SET.read_text())
    ids = [it["id"] for it in items]
    check(len(ids) == len(set(ids)), "duplicate ids in eval-set.json")
    for it in items:
        check(isinstance(it.get("should_trigger"), bool), f"{it.get('id')}: should_trigger not bool")
        check(bool(it.get("query")), f"{it.get('id')}: empty query")
    fire = sum(1 for it in items if it["should_trigger"])
    check(0.3 <= fire / len(items) <= 0.7, f"eval set unbalanced: {fire}/{len(items)} fire")

    if failures:
        print("SELFTEST FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print(f"selftest OK ({len(verdict_cases)} verdict cases, parser + {len(items)}-prompt eval set)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--selftest", action="store_true",
                    help="run headless parser + eval-set checks only (no claude calls); for CI")
    ap.add_argument("--model", default="claude-opus-4-8",
                    help="router model (default: the model that routes in this Claude Code)")
    ap.add_argument("--runs", type=int, default=5, help="runs per prompt")
    ap.add_argument("--threshold", type=float, default=0.5)
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--timeout", type=int, default=120, help="seconds per claude -p call")
    ap.add_argument("--json", type=Path, help="also write the full result JSON here")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    description = parse_description(SKILL_MD)
    items = json.loads(EVAL_SET.read_text())
    out = run(items, description, args.model, args.runs, args.threshold,
              args.workers, args.timeout)

    if args.json:
        args.json.write_text(json.dumps(out, indent=2))

    print(f"model={out['model']}  N={out['runs_per_prompt']}  "
          f"threshold={out['threshold']}")
    print(f"accuracy: {out['correct']}/{out['total']}")
    print()
    for r in out["results"]:
        mark = "ok " if r["correct"] else "XX "
        want = "FIRE" if r["should_trigger"] else "skip"
        print(f"  {mark}{r['id']:<3} want={want}  rate={r['fires']}/{r['runs']}  "
              f"[{r['category']}]  {r['query'][:58]}")
    anchors_ok = all(r["correct"] for r in out["results"]
                     if r["category"].endswith("clear"))
    print()
    print(f"clear anchors all correct: {anchors_ok}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
