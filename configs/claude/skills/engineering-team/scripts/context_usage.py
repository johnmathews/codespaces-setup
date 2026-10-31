#!/usr/bin/env python3
"""How big is this session's context? One input to the sitrep's Session line.

`references/status-updates.md` §4 decides whether to continue in this session or
hand over to a new one, and that decision is mostly qualitative: does the work
ahead need what this session already holds? Size is a secondary input. The
session cannot see its own size, and auto-compaction is too late a signal, so
this script reads the session's transcript and reports it.

How it measures: Claude Code writes each session's transcript to
`<config>/projects/<slug>/<session-id>.jsonl`, and each assistant entry carries
the API `usage` of the request that produced it. The context sent with that
request is `input_tokens + cache_read_input_tokens + cache_creation_input_tokens`.
The newest main-chain entry (subagent entries are marked `isSidechain` and
skipped) is the current size. A `compact_boundary` system entry marks each
compaction.

It reports tokens, not a percentage: the window size and the compaction
threshold are not in the transcript, and a percentage of a guessed window is a
number with nothing behind it.

Usage:
    context_usage.py                      # this session (CLAUDE_CODE_SESSION_ID)
    context_usage.py --transcript PATH    # a given transcript
    context_usage.py --selftest

Exit 0 with a report; exit 2 when no transcript or no usage entry is found.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path



@dataclass
class Usage:
    tokens: int
    model: str
    compactions: int


def read_usage(path: Path) -> Usage | None:
    """Context size of the newest main-chain request, and the compaction count."""
    tokens, model, compactions = None, "", 0
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(entry, dict):
                continue
            if entry.get("type") == "system" and entry.get("subtype") == "compact_boundary":
                compactions += 1
                continue
            if entry.get("type") != "assistant" or entry.get("isSidechain"):
                continue
            message = entry.get("message")
            usage = message.get("usage") if isinstance(message, dict) else None
            if not isinstance(usage, dict):
                continue
            size = sum(int(usage.get(k) or 0) for k in
                       ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
            if size:
                tokens, model = size, str(message.get("model") or "")
    return None if tokens is None else Usage(tokens, model, compactions)


def find_transcript(session_id: str, config_dir: Path) -> Path | None:
    matches = sorted((config_dir / "projects").glob(f"*/{session_id}.jsonl"))
    return matches[0] if matches else None


def report(u: Usage) -> str:
    times = "time" if u.compactions == 1 else "times"
    return f"context: {u.tokens // 1000}k tokens\nsummarised: {u.compactions} {times}"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--transcript", type=Path)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()

    path = args.transcript
    if path is None:
        session = os.environ.get("CLAUDE_CODE_SESSION_ID", "").strip()
        config = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")
        path = find_transcript(session, config) if session else None
    if path is None or not path.is_file():
        print("context: unknown (no transcript found)")
        return 2
    u = read_usage(path)
    if u is None:
        print(f"context: unknown (no usage entries in {path})")
        return 2
    print(report(u))
    return 0


def selftest() -> int:
    fails: list[str] = []

    def expect(cond: bool, msg: str) -> None:
        if not cond:
            fails.append(msg)

    def asst(inp: int, read: int, create: int, model: str = "m", side: bool = False) -> dict:
        return {"type": "assistant", "isSidechain": side,
                "message": {"model": model, "usage": {
                    "input_tokens": inp, "cache_read_input_tokens": read,
                    "cache_creation_input_tokens": create, "output_tokens": 9}}}

    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)

        def write(name: str, entries: list) -> Path:
            p = t / name
            p.write_text("\n".join(json.dumps(e) for e in entries) + "\nnot json\n")
            return p

        # The newest main-chain entry wins; a later subagent entry is ignored.
        p = write("a.jsonl", [asst(1, 10_000, 0), {"type": "user"},
                              asst(2, 90_000, 1_000), asst(5, 150_000, 0, side=True)])
        u = read_usage(p)
        expect(u is not None and u.tokens == 91_002, f"sidechain/newest: got {u}")
        expect(u is not None and u.compactions == 0, "no compaction expected")

        # Compactions are counted.
        p = write("b.jsonl", [asst(0, 150_000, 0),
                              {"type": "system", "subtype": "compact_boundary"},
                              asst(0, 20_000, 0)])
        u = read_usage(p)
        expect(u is not None and u.compactions == 1 and u.tokens == 20_000, f"compaction: {u}")

        # No usage at all -> None.
        expect(read_usage(write("c.jsonl", [{"type": "user"}])) is None, "empty should be None")


        # Session lookup by ID under <config>/projects/<slug>/.
        (t / "projects" / "slug").mkdir(parents=True)
        target = t / "projects" / "slug" / "abc.jsonl"
        target.write_text(json.dumps(asst(0, 1, 0)) + "\n")
        expect(find_transcript("abc", t) == target, "find by session id")
        expect(find_transcript("nope", t) is None, "missing session")

        expect(report(Usage(166_400, "m", 1)) == "context: 166k tokens\nsummarised: 1 time",
               "report format")

    if fails:
        for f in fails:
            print(f"FAIL {f}")
        return 1
    print("context_usage selftest OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
