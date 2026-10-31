#!/usr/bin/env python3
"""Which model did each agent in this session run on, for how long, at what size?

`references/team-structure.md` §"Choosing a model" names four dispatches that
run on the mid tier and puts a floor under every dispatch: never below the mid
tier. A rule about which model ran is a runtime claim, so its check has to be a
runtime observation. This script reads that observation from the transcripts:
every assistant entry records the model that produced it and the API usage of
its request, and every entry carries a timestamp.

Where it reads (the layout Claude Code writes):

- `<config>/projects/<slug>/<session-id>.jsonl`: the lead's own entries;
- `<config>/projects/<slug>/<session-id>/subagents/agent-<id>.jsonl`: one file per
  subagent, with `agent-<id>.meta.json` beside it holding the agent type, the
  description and the `model` the dispatch asked for (absent means inherit).

What each line reports:

- **time**: first to last timestamp in the transcript. For the lead that is the
  session's elapsed time, idle waits for the user included. The subagent total
  adds the agents' times, so it exceeds the elapsed time when they run in parallel.
- **tokens**: the sum, over API calls, of input + cache reads + cache writes +
  output. Cache reads are most of it and cost far less than fresh input, so
  this is volume processed, not a bill. One call can be written as several
  entries that repeat its usage, so each message ID counts once.

What it flags:

- **below floor**: an agent that ran on the smallest tier (a `haiku` model). The
  skill's floor forbids it, so the report ends with a FAIL line and exits 1.
  When the floor held, the report says nothing about it.
- **pinned by its type**: an agent that asked for nothing but ran on a different
  family from the lead's. Its agent type's own definition set the model, which
  beats inheritance. Pass `model` explicitly when the tier matters.
- **not as asked**: an agent that asked for one family and ran on another.

Usage:
    model_usage.py                      # this session (CLAUDE_CODE_SESSION_ID)
    model_usage.py --transcript PATH    # a given session transcript
    model_usage.py --all                # one line per agent, not grouped
    model_usage.py --selftest

Exit 0 with a report, 1 when an agent ran below the floor, 2 when no transcript
is found.
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import re
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

FLOOR_RE = re.compile(r"haiku", re.IGNORECASE)
FAMILY_RE = re.compile(r"claude-([a-z]+)", re.IGNORECASE)


@dataclass
class Usage:
    """What one transcript shows: models, tokens and elapsed seconds."""

    models: collections.Counter[str] = field(default_factory=collections.Counter)
    tokens_in: int = 0
    tokens_out: int = 0
    seconds: float = 0.0

    def add(self, other: Usage) -> None:
        self.models.update(other.models)
        self.tokens_in += other.tokens_in
        self.tokens_out += other.tokens_out
        self.seconds += other.seconds

    @property
    def ran(self) -> str:
        return ", ".join(m for m, _ in self.models.most_common()) or "no reply"


@dataclass
class Agent:
    name: str
    agent_type: str
    requested: str  # a tier name such as "sonnet", or "inherit"
    usage: Usage


def family(model: str) -> str:
    m = FAMILY_RE.search(model)
    return m.group(1).lower() if m else model.lower()


def _when(stamp: object) -> datetime | None:
    if not isinstance(stamp, str):
        return None
    try:
        return datetime.fromisoformat(stamp)
    except ValueError:
        return None


def read_usage(path: Path, skip_sidechain: bool) -> Usage:
    usage = Usage()
    calls: dict[str, tuple[str, dict]] = {}  # message id -> (model, usage); the last copy wins
    first = last = None
    with path.open(encoding="utf-8", errors="replace") as fh:
        for n, line in enumerate(fh):
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(entry, dict) or (skip_sidechain and entry.get("isSidechain")):
                continue
            when = _when(entry.get("timestamp"))
            if when:
                first = first or when
                last = when
            if entry.get("type") != "assistant":
                continue
            message = entry.get("message") or {}
            model = str(message.get("model") or "")
            if not model or model.startswith("<"):  # "<synthetic>" entries carry no real call
                continue
            calls[str(message.get("id") or f"line-{n}")] = (model, message.get("usage") or {})
    for model, u in calls.values():
        usage.models[model] += 1
        usage.tokens_in += sum(int(u.get(k) or 0) for k in
                               ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
        usage.tokens_out += int(u.get("output_tokens") or 0)
    if first and last:
        usage.seconds = max(0.0, (last - first).total_seconds())
    return usage


def read_agents(session_dir: Path) -> list[Agent]:
    agents = []
    for transcript in sorted((session_dir / "subagents").glob("agent-*.jsonl")):
        meta_path = transcript.with_suffix(".meta.json")
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            meta = {}
        agents.append(Agent(
            name=str(meta.get("description") or transcript.stem),
            agent_type=str(meta.get("agentType") or "unknown"),
            requested=str(meta.get("model") or "inherit"),
            usage=read_usage(transcript, skip_sidechain=False),
        ))
    return agents


def flags(agent: Agent, lead_family: str) -> list[str]:
    out = []
    if any(FLOOR_RE.search(m) for m in agent.usage.models):
        out.append("BELOW FLOOR")
    families = {family(m) for m in agent.usage.models}
    if agent.requested == "inherit":
        if lead_family and families and families != {lead_family}:
            out.append("pinned by its type")
    elif families and families != {agent.requested.lower()}:
        out.append(f"not as asked ({agent.requested})")
    return out


def fmt_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.0f}k" if n >= 10_000 else f"{n / 1_000:.1f}k"
    return str(n)


def fmt_time(seconds: float) -> str:
    s = round(seconds)
    if s < 60:
        return f"{s}s"
    if s < 3600:
        return f"{s // 60}m {s % 60:02d}s"
    return f"{s // 3600}h {s % 3600 // 60:02d}m"


def cost(u: Usage) -> str:
    return f"{fmt_time(u.seconds)}, {fmt_tokens(u.tokens_in + u.tokens_out)} tokens"


def short(models: str) -> str:
    """claude-sonnet-5-5 -> sonnet-5-5; the family is what the eye looks for."""
    return re.sub(r"\bclaude-", "", models)


def table(headers: list[str], rows: list[list[str]], right: set[int]) -> list[str]:
    """Plain-text columns, two spaces apart; numbers right-aligned so they line up."""
    widths = [max(len(r[i]) for r in [headers, *rows]) for i in range(len(headers))]

    def line(cells: list[str]) -> str:
        return "  ".join(c.rjust(w) if i in right else c.ljust(w)
                         for i, (c, w) in enumerate(zip(cells, widths))).rstrip()

    return [line(headers), line(["-" * w for w in widths]), *(line(r) for r in rows)]


def report(lead: Usage, agents: list[Agent], per_agent: bool) -> tuple[str, int]:
    lead_family = family(lead.models.most_common(1)[0][0]) if lead.models else ""
    second = "Type" if per_agent else "Count"
    rows = [["lead", "-" if per_agent else "1", "-", short(lead.ran),
             fmt_time(lead.seconds), fmt_tokens(lead.tokens_in + lead.tokens_out), ""]]
    below = 0
    if per_agent:
        for a in agents:
            f = flags(a, lead_family)
            below += "BELOW FLOOR" in f
            name = a.name if len(a.name) <= 32 else a.name[:31] + "…"
            rows.append([name, a.agent_type, a.requested, short(a.usage.ran), fmt_time(a.usage.seconds),
                         fmt_tokens(a.usage.tokens_in + a.usage.tokens_out), "; ".join(f)])
    else:
        groups: dict[tuple[str, str, str], list[Agent]] = collections.defaultdict(list)
        for a in agents:
            groups[(a.agent_type, a.requested, a.usage.ran)].append(a)
        for (atype, req, ran), members in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            f = flags(members[0], lead_family)
            if "BELOW FLOOR" in f:
                below += len(members)
            group = Usage()
            for a in members:
                group.add(a.usage)
            rows.append([atype, str(len(members)), req, short(ran), fmt_time(group.seconds),
                         fmt_tokens(group.tokens_in + group.tokens_out), "; ".join(f)])
    if agents:
        total = Usage()
        for a in agents:
            total.add(a.usage)
        rows.append(["all subagents", "-" if per_agent else str(len(agents)), "", "",
                     fmt_time(total.seconds), fmt_tokens(total.tokens_in + total.tokens_out), ""])
    lines = table(["Agent", second, "Asked", "Ran", "Time", "Tokens", "Note"], rows,
                  right={4, 5} if per_agent else {1, 4, 5})
    if not agents:
        lines.append("No subagents.")
    if below:
        lines.append(f"FAIL: {below} agent(s) ran below the floor (team-structure.md, \"Choosing a model\")")
    return "\n".join(lines), 1 if below else 0


def find_transcript(session_id: str, config_dir: Path) -> Path | None:
    matches = sorted((config_dir / "projects").glob(f"*/{session_id}.jsonl"))
    return matches[0] if matches else None


def run(transcript: Path, per_agent: bool) -> int:
    lead = read_usage(transcript, skip_sidechain=True)
    text, code = report(lead, read_agents(transcript.with_suffix("")), per_agent)
    print(text)
    return code


def selftest() -> int:
    failed = 0

    def expect(cond: bool, msg: str) -> None:
        nonlocal failed
        print(("ok   " if cond else "FAIL ") + msg)
        failed += not cond

    def asst(model: str, at: str = "2026-10-31T12:00:00Z", out: int = 10, inp: int = 100,
             mid: str | None = None, side: bool = False) -> str:
        message: dict = {"model": model, "usage": {"input_tokens": inp, "cache_read_input_tokens": 0,
                                                   "cache_creation_input_tokens": 0, "output_tokens": out}}
        if mid:
            message["id"] = mid
        return json.dumps({"type": "assistant", "isSidechain": side, "timestamp": at, "message": message})

    def cells(text: str, first: str) -> list[str]:
        """The cells of the row whose first cell is `first`."""
        for row in text.splitlines():
            parts = re.split(r"\s{2,}", row.strip())
            if parts[0] == first:
                return parts
        return []

    def user(at: str) -> str:
        return json.dumps({"type": "user", "timestamp": at, "message": {"content": "hi"}})

    expect(fmt_tokens(950) == "950" and fmt_tokens(1_500) == "1.5k" and fmt_tokens(45_413) == "45k"
           and fmt_tokens(12_300_000) == "12.3M", "token counts format as 950, 1.5k, 45k, 12.3M")
    expect(fmt_time(2.9) == "3s" and fmt_time(185) == "3m 05s" and fmt_time(7_260) == "2h 01m",
           "durations format as 3s, 3m 05s, 2h 01m")

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        main = root / "s1.jsonl"
        main.write_text("\n".join([
            user("2026-10-31T12:00:00Z"),
            asst("claude-opus-5-5", at="2026-10-31T12:00:05Z", mid="m1"),
            asst("claude-opus-5-5", at="2026-10-31T12:00:06Z", mid="m1"),  # same call, second block
            asst("claude-sonnet-5-5", at="2026-10-31T13:00:00Z", side=True),  # sidechain: not the lead
            asst("<synthetic>", at="2026-10-31T12:01:00Z"),
            "not json",
            user("2026-10-31T12:02:00Z"),
        ]), encoding="utf-8")
        sub = root / "s1" / "subagents"
        sub.mkdir(parents=True)

        def agent(aid: str, meta: dict, *models: str) -> None:
            (sub / f"agent-{aid}.jsonl").write_text("\n".join(
                asst(m, at=f"2026-10-31T12:00:{i * 30:02d}Z") for i, m in enumerate(models)), encoding="utf-8")
            (sub / f"agent-{aid}.meta.json").write_text(json.dumps(meta), encoding="utf-8")

        lead = read_usage(main, skip_sidechain=True)
        expect(dict(lead.models) == {"claude-opus-5-5": 1}, f"lead skips sidechain and synthetic: {dict(lead.models)}")
        expect(lead.tokens_in == 100 and lead.tokens_out == 10, "a call split over two entries counts once")
        expect(lead.seconds == 120, f"lead time is first to last timestamp, sidechain excluded: {lead.seconds}")

        text, code = report(lead, read_agents(root / "s1"), per_agent=False)
        expect(code == 0 and text.splitlines()[-1] == "No subagents.", "no subagents: exit 0, said once")
        expect(cells(text, "lead") == ["lead", "1", "-", "opus-5-5", "2m 00s", "110"],
               f"lead row shows model, time and tokens: {cells(text, 'lead')}")

        agent("a1", {"agentType": "general-purpose", "description": "survey", "model": "sonnet"},
              "claude-sonnet-5-5", "claude-sonnet-5-5")
        agent("a2", {"agentType": "general-purpose", "description": "plan"}, "claude-opus-5-5")
        text, code = report(lead, read_agents(root / "s1"), per_agent=False)
        expect(code == 0 and "<-" not in text, "sonnet as asked plus inherited opus: nothing flagged, exit 0")
        expect("floor" not in text.lower(), "a held floor is not mentioned")
        lines = text.splitlines()
        expect(lines[0].split() == ["Agent", "Count", "Asked", "Ran", "Time", "Tokens", "Note"],
               f"header row: {lines[0]}")
        tok = lines[0].index("Tokens") + len("Tokens")
        expect(all(len(row) >= tok and row[tok - 1] != " " for row in lines[2:]),
               "every token count ends under the end of its header")
        rows = [re.split(r"\s{2,}", row.strip()) for row in lines[2:]]
        expect(["general-purpose", "1", "sonnet", "sonnet-5-5", "30s", "220"] in rows
               and ["general-purpose", "1", "inherit", "opus-5-5", "0s", "110"] in rows,
               "each group row shows its count, summed time and tokens")
        expect(cells(text, "all subagents") == ["all subagents", "2", "30s", "330"],
               f"the total row sums every agent: {cells(text, 'all subagents')}")

        agent("a3", {"agentType": "some-reviewer", "description": "review"}, "claude-sonnet-5-5")
        text, _ = report(lead, read_agents(root / "s1"), per_agent=True)
        expect("pinned by its type" in text, "inherit that ran on another family is flagged as pinned")
        expect(cells(text, "review") == ["review", "some-reviewer", "inherit", "sonnet-5-5", "0s", "110",
                                         "pinned by its type"],
               f"a per-agent row shows its type, time, tokens and note: {cells(text, 'review')}")

        agent("a4", {"agentType": "general-purpose", "description": "check", "model": "sonnet"}, "claude-opus-5-5")
        text, _ = report(lead, read_agents(root / "s1"), per_agent=True)
        expect("not as asked (sonnet)" in text, "asked sonnet, ran opus: flagged")

        agent("a5", {"agentType": "guide", "description": "docs lookup"}, "claude-haiku-5-5")
        text, code = report(lead, read_agents(root / "s1"), per_agent=False)
        expect(code == 1 and "BELOW FLOOR" in text and text.splitlines()[-1].startswith("FAIL: 1 agent"),
               "a haiku agent fails the floor: FAIL is the last line, exit 1")

        (sub / "agent-a6.jsonl").write_text(asst("claude-sonnet-5-5"), encoding="utf-8")  # no meta file
        a6 = [a for a in read_agents(root / "s1") if a.name == "agent-a6"]
        expect(len(a6) == 1 and a6[0].requested == "inherit", "a missing meta file reads as inherit, named by file")

        (root / "projects" / "slug").mkdir(parents=True)
        (root / "projects" / "slug" / "abc.jsonl").write_text(asst("claude-opus-5-5"), encoding="utf-8")
        expect(find_transcript("abc", root) is not None and find_transcript("nope", root) is None,
               "session lookup by ID under <config>/projects/<slug>/")

    print()
    if failed:
        print(f"FAIL: {failed} selftest case(s) did not behave as specified")
        return 1
    print("OK: every selftest case behaves as specified")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Report which model each agent in a session ran on, with time and tokens.")
    ap.add_argument("--transcript", type=Path, help="a session transcript (.jsonl)")
    ap.add_argument("--all", action="store_true", help="one line per agent instead of grouped")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args(argv[1:])
    if args.selftest:
        return selftest()
    transcript = args.transcript
    if transcript is None:
        session = os.environ.get("CLAUDE_CODE_SESSION_ID", "").strip()
        config = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")
        transcript = find_transcript(session, config) if session else None
    if transcript is None or not transcript.is_file():
        print("no transcript found (set CLAUDE_CODE_SESSION_ID, or pass --transcript)")
        return 2
    return run(transcript, args.all)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
