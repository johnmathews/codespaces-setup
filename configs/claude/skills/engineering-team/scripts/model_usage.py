#!/usr/bin/env python3
"""Which model did each agent in this session actually run on?

`references/team-structure.md` §"Choosing a model" names four dispatches that
run on the mid tier and puts a floor under every dispatch: never below the mid
tier. A rule about which model ran is a runtime claim, so its check has to be a
runtime observation. This script reads that observation from the transcripts:
every assistant entry records the model that produced it.

Where it reads (the layout Claude Code writes):

- `<config>/projects/<slug>/<session-id>.jsonl`: the lead's own entries;
- `<config>/projects/<slug>/<session-id>/subagents/agent-<id>.jsonl`: one file per
  subagent, with `agent-<id>.meta.json` beside it holding the agent type, the
  description and the `model` the dispatch asked for (absent means inherit).

What it flags:

- **below floor**: an agent that ran on the smallest tier (a `haiku` model). The
  skill's floor forbids it, so this exits 1.
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
from pathlib import Path

FLOOR_RE = re.compile(r"haiku", re.IGNORECASE)
FAMILY_RE = re.compile(r"claude-([a-z]+)", re.IGNORECASE)


@dataclass
class Agent:
    name: str
    agent_type: str
    requested: str  # a tier name such as "sonnet", or "inherit"
    models: collections.Counter[str] = field(default_factory=collections.Counter)
    output_tokens: int = 0

    @property
    def ran(self) -> str:
        return ", ".join(m for m, _ in self.models.most_common()) or "no reply"


def family(model: str) -> str:
    m = FAMILY_RE.search(model)
    return m.group(1).lower() if m else model.lower()


def read_models(path: Path, skip_sidechain: bool) -> tuple[collections.Counter[str], int]:
    models: collections.Counter[str] = collections.Counter()
    out = 0
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"assistant"' not in line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("type") != "assistant" or (skip_sidechain and entry.get("isSidechain")):
                continue
            message = entry.get("message") or {}
            model = str(message.get("model") or "")
            if not model or model.startswith("<"):  # "<synthetic>" entries carry no real call
                continue
            models[model] += 1
            out += int((message.get("usage") or {}).get("output_tokens") or 0)
    return models, out


def read_agents(session_dir: Path) -> list[Agent]:
    agents = []
    for transcript in sorted((session_dir / "subagents").glob("agent-*.jsonl")):
        meta_path = transcript.with_suffix(".meta.json")
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            meta = {}
        models, out = read_models(transcript, skip_sidechain=False)
        agents.append(Agent(
            name=str(meta.get("description") or transcript.stem),
            agent_type=str(meta.get("agentType") or "unknown"),
            requested=str(meta.get("model") or "inherit"),
            models=models,
            output_tokens=out,
        ))
    return agents


def flags(agent: Agent, lead_family: str) -> list[str]:
    out = []
    if any(FLOOR_RE.search(m) for m in agent.models):
        out.append("BELOW FLOOR")
    families = {family(m) for m in agent.models}
    if agent.requested == "inherit":
        if lead_family and families and families != {lead_family}:
            out.append("pinned by its type")
    elif families and families != {agent.requested.lower()}:
        out.append(f"not as asked ({agent.requested})")
    return out


def report(lead: collections.Counter[str], agents: list[Agent], per_agent: bool) -> tuple[str, int]:
    lead_family = family(lead.most_common(1)[0][0]) if lead else ""
    lines = [f"Lead session: {', '.join(m for m, _ in lead.most_common()) or 'no reply found'}"]
    if not agents:
        lines.append("Subagents: none")
        return "\n".join(lines), 0
    below = 0
    lines.append(f"Subagents: {len(agents)}")
    if per_agent:
        for a in agents:
            f = flags(a, lead_family)
            below += "BELOW FLOOR" in f
            lines.append(f"- {a.name} [{a.agent_type}, asked {a.requested}] ran {a.ran}"
                         + (f"  <- {'; '.join(f)}" if f else ""))
    else:
        groups: dict[tuple[str, str, str], list[Agent]] = collections.defaultdict(list)
        for a in agents:
            groups[(a.agent_type, a.requested, a.ran)].append(a)
        for (atype, req, ran), members in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            f = flags(members[0], lead_family)
            if "BELOW FLOOR" in f:
                below += len(members)
            lines.append(f"- {len(members)} x {atype}, asked {req}, ran {ran}"
                         + (f"  <- {'; '.join(f)}" if f else ""))
    totals: collections.Counter[str] = collections.Counter()
    for a in agents:
        totals.update({family(m): 1 for m in a.models})
    lines.append("By family: " + ", ".join(f"{fam} {n}" for fam, n in totals.most_common()))
    if below:
        lines.append(f"FAIL: {below} agent(s) ran below the floor (team-structure.md, \"Choosing a model\")")
    else:
        lines.append("Floor: held. No agent ran below the mid tier.")
    return "\n".join(lines), 1 if below else 0


def find_transcript(session_id: str, config_dir: Path) -> Path | None:
    matches = sorted((config_dir / "projects").glob(f"*/{session_id}.jsonl"))
    return matches[0] if matches else None


def run(transcript: Path, per_agent: bool) -> int:
    lead, _ = read_models(transcript, skip_sidechain=True)
    text, code = report(lead, read_agents(transcript.with_suffix("")), per_agent)
    print(text)
    return code


def selftest() -> int:
    failed = 0

    def expect(cond: bool, msg: str) -> None:
        nonlocal failed
        print(("ok   " if cond else "FAIL ") + msg)
        failed += not cond

    def asst(model: str, out: int = 10, side: bool = False) -> str:
        return json.dumps({"type": "assistant", "isSidechain": side,
                           "message": {"model": model, "usage": {"output_tokens": out}}})

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        main = root / "s1.jsonl"
        main.write_text("\n".join([
            json.dumps({"type": "user", "message": {"content": "hi"}}),
            asst("claude-opus-5-5"),
            asst("claude-sonnet-5-5", side=True),  # a sidechain entry is not the lead
            asst("<synthetic>"),
            "not json",
        ]), encoding="utf-8")
        sub = root / "s1" / "subagents"
        sub.mkdir(parents=True)

        def agent(aid: str, meta: dict, *models: str) -> None:
            (sub / f"agent-{aid}.jsonl").write_text("\n".join(asst(m) for m in models), encoding="utf-8")
            (sub / f"agent-{aid}.meta.json").write_text(json.dumps(meta), encoding="utf-8")

        lead, _ = read_models(main, skip_sidechain=True)
        expect(dict(lead) == {"claude-opus-5-5": 1}, f"lead models skip sidechain and synthetic: {dict(lead)}")

        text, code = report(lead, read_agents(root / "s1"), per_agent=False)
        expect(code == 0 and "Subagents: none" in text, "no subagents: exit 0")

        agent("a1", {"agentType": "general-purpose", "description": "survey", "model": "sonnet"},
              "claude-sonnet-5-5", "claude-sonnet-5-5")
        agent("a2", {"agentType": "general-purpose", "description": "plan"}, "claude-opus-5-5")
        agents = read_agents(root / "s1")
        text, code = report(lead, agents, per_agent=False)
        expect(code == 0 and "Floor: held" in text, "sonnet as asked plus inherited opus: floor held, exit 0")
        expect("<-" not in text, "nothing flagged when every agent ran as asked")

        agent("a3", {"agentType": "some-reviewer", "description": "review"}, "claude-sonnet-5-5")
        text, _ = report(lead, read_agents(root / "s1"), per_agent=True)
        expect("pinned by its type" in text, "inherit that ran on another family is flagged as pinned")

        agent("a4", {"agentType": "general-purpose", "description": "check", "model": "sonnet"}, "claude-opus-5-5")
        text, _ = report(lead, read_agents(root / "s1"), per_agent=True)
        expect("not as asked (sonnet)" in text, "asked sonnet, ran opus: flagged")

        agent("a5", {"agentType": "guide", "description": "docs lookup"}, "claude-haiku-5-5")
        text, code = report(lead, read_agents(root / "s1"), per_agent=False)
        expect(code == 1 and "BELOW FLOOR" in text and "FAIL: 1 agent" in text, "a haiku agent fails the floor: exit 1")

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
    ap = argparse.ArgumentParser(description="Report which model each agent in a session ran on.")
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
