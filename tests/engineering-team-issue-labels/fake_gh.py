#!/usr/bin/env python3
"""A fake `gh` for the issue_labels.py tests.

It keeps a repo's labels and issues in the JSON file named by FAKE_GH_STATE and
appends every call, as a JSON array of its arguments, to FAKE_GH_LOG. It speaks
only the four calls issue_labels.py makes:

    gh label list --limit N --json name,color,description [-R repo]
    gh label create NAME --color C --description D --force [-R repo]
    gh issue view N --json labels,body [-R repo]

A state with "fail": true makes every call exit 1, the way a real `gh` does
when it is not logged in.
"""

import json
import os
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    state_path = Path(os.environ["FAKE_GH_STATE"])
    with open(os.environ["FAKE_GH_LOG"], "a") as log:
        log.write(json.dumps(argv) + "\n")
    state = json.loads(state_path.read_text())
    if state.get("fail"):
        print("gh: To get started with GitHub CLI, please run:  gh auth login", file=sys.stderr)
        return 1

    args = list(argv)
    if "-R" in args:
        i = args.index("-R")
        del args[i : i + 2]

    if args[:2] == ["label", "list"]:
        print(json.dumps(state.get("labels", [])))
        return 0

    if args[:2] == ["label", "create"]:
        name = args[2]
        color = args[args.index("--color") + 1]
        description = args[args.index("--description") + 1]
        labels = state.setdefault("labels", [])
        existing = [label for label in labels if label["name"].lower() == name.lower()]
        if existing and "--force" not in args:
            print(f"label with name \"{name}\" already exists; use `--force` to update", file=sys.stderr)
            return 1
        if existing:
            existing[0].update(color=color, description=description)
        else:
            labels.append({"name": name, "color": color, "description": description})
        state_path.write_text(json.dumps(state))
        return 0

    if args[:2] == ["issue", "view"]:
        issue = state.get("issues", {}).get(args[2])
        if issue is None:
            print(f"GraphQL: Could not resolve to an issue with the number of {args[2]}.", file=sys.stderr)
            return 1
        print(json.dumps({"labels": [{"name": n} for n in issue["labels"]], "body": issue["body"]}))
        return 0

    print(f"fake gh: unsupported call {argv}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
