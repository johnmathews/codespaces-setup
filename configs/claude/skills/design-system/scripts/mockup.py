#!/usr/bin/env python3
"""Start and build a design mockup on a project's design system (references/mockups.md).

A mockup lives in the system it proposes changes to, one folder per question:

    <system-dir>/mockups/<yymmdd>-<slug>/index.html   the page: options built from the tokens
    <system-dir>/mockups/<yymmdd>-<slug>/README.md    the record: question, options, decision
    <system-dir>/mockups/<yymmdd>-<slug>/dist/        built by `build`, git-ignored

`new` copies the skill's templates/mockup.html and mockup-readme.md into a new folder. `build`
writes dist/: index.html (the page as an Artifact fragment, what gets published), tokens.css (the
system's tokens in the Artifact theme contract: light on :root, dark under prefers-color-scheme and
[data-theme="dark"], and any element with data-theme="light" or "dark" switches its subtree, so an
option can show both themes side by side), fonts/ (the system's font files) and preview.html (the
same page in a full document, for a browser and render_mockup.mjs). Any other file beside
index.html (an image, a JSON of sample data) is copied too. Stdlib only; tokens.css comes from
design_preview.py beside this file, so mockups, the gallery and the app share one compiler.

Usage:
    mockup.py new <system-dir> <slug> [--title "Title"] [--date yymmdd]
    mockup.py build <mockup-dir>
    mockup.py --selftest | --version
"""

from __future__ import annotations

import importlib.util
import json
import re
import shutil
import sys
import tempfile
from datetime import date
from pathlib import Path

# Bump on every change to this file: ci/lint-skill-versions.sh (codespaces-setup) fails a change
# that doesn't.
SCRIPT_VERSION = 1

HERE = Path(__file__).resolve().parent
TEMPLATES = HERE.parent / "templates"
SLUG = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
DARK = '[data-theme="dark"]'


def _design_preview():
    sys.dont_write_bytecode = True  # no __pycache__ inside the skill's folder
    spec = importlib.util.spec_from_file_location("design_preview", HERE / "design_preview.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def contract_css(tokens: dict) -> str:
    """The tokens as the Artifact theme contract wants them, scoped so any element can switch."""
    css = _design_preview().tokens_css(tokens, font_base="fonts", dark_selector=DARK)
    dark = re.search(re.escape(DARK) + r" \{\n(.*?)\}", css, re.S)
    if dark is None:  # a single-theme system: nothing to mirror
        return css
    body = dark.group(1) + "  color-scheme: dark;\n"
    css = css.replace(dark.group(0), f"{DARK} {{\n{body}}}")
    light = re.search(r':root, \[data-theme="light"\] \{\n', css)
    if light:
        css = css.replace(light.group(0), light.group(0) + "  color-scheme: light;\n", 1)
    mirror = f'@media (prefers-color-scheme: dark) {{\n:root:not([data-theme="light"]) {{\n{body}}}\n}}\n'
    return css + mirror


def system_of(mockup: Path) -> Path:
    """A mockup's design system: the folder above `mockups/`."""
    if mockup.parent.name != "mockups":
        raise SystemExit(f"error: {mockup} is not inside a mockups/ folder of a design system")
    return mockup.parent.parent


def new(system: Path, slug: str, title: str | None, day: str | None) -> Path:
    if not SLUG.fullmatch(slug):
        raise SystemExit(f"error: slug {slug!r}: lower-case words joined by hyphens")
    if not (system / "project" / "tokens.json").exists():
        raise SystemExit(f"error: no project/tokens.json in {system}")
    day = day or date.today().strftime("%y%m%d")
    folder = system / "mockups" / f"{day}-{slug}"
    if folder.exists():
        raise SystemExit(f"error: {folder} exists; build it, or pick another slug")
    folder.mkdir(parents=True)
    name = json.loads((system / "project" / "tokens.json").read_text()).get("name", "Design system")
    title = title or slug.replace("-", " ").capitalize()
    fill = {"{{TITLE}}": title, "{{DATE}}": f"20{day[:2]}-{day[2:4]}-{day[4:]}", "{{SYSTEM}}": name}
    for src, dst in (("mockup.html", "index.html"), ("mockup-readme.md", "README.md")):
        text = (TEMPLATES / src).read_text()
        for key, value in fill.items():
            text = text.replace(key, value)
        (folder / dst).write_text(text)
    ignore = system / "mockups" / ".gitignore"
    if not ignore.exists():
        ignore.write_text("# Built by mockup.py build: published and rendered, never committed.\n*/dist/\n")
    return folder


def build(mockup: Path) -> Path:
    system = system_of(mockup)
    page = (mockup / "index.html").read_text()
    tokens = json.loads((system / "project" / "tokens.json").read_text())
    dist = mockup / "dist"
    shutil.rmtree(dist, ignore_errors=True)
    (dist / "fonts").mkdir(parents=True)
    for extra in mockup.iterdir():
        if extra.name not in {"index.html", "README.md", "dist"} and extra.is_file():
            shutil.copy2(extra, dist / extra.name)
    (dist / "tokens.css").write_text(f"/* {tokens.get('name', 'Design system')} — generated from tokens.json */\n"
                                    + contract_css(tokens))
    for font in tokens.get("type", {}).get("fonts", []):
        if font.get("file"):
            source = system / "project" / font["file"]
            if not source.exists():
                raise SystemExit(f"error: tokens.json names {font['file']}, which is missing")
            shutil.copy2(source, dist / "fonts" / source.name)
    (dist / "index.html").write_text(page)
    (dist / "preview.html").write_text(
        "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n"
        "<style>:root{color-scheme:light}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>\n"
        f"</head>\n<body>\n{page}\n</body>\n</html>\n"
    )
    return dist


def _selftest() -> int:
    checks: list[tuple[str, bool]] = []
    with tempfile.TemporaryDirectory() as tmp:
        system = Path(tmp) / "design-system"
        (system / "project" / "fonts").mkdir(parents=True)
        (system / "project" / "fonts" / "acme.woff2").write_bytes(b"wOF2")
        tokens = {
            "name": "Acme",
            "color": {"themes": [{"id": "light"}, {"id": "dark"}],
                      "tokens": [{"name": "canvas", "value": {"light": "#ffffff", "dark": "#111111"}, "usage": "."}]},
            "type": {"families": {"sans": "Acme, sans-serif"},
                     "fonts": [{"family": "Acme", "file": "fonts/acme.woff2", "weight": "400"}],
                     "groups": [{"name": "Text", "family": "sans", "styles": [
                         {"name": "body", "fontSize": "18px", "lineHeight": "26px", "fontWeight": 400}]}]},
        }
        (system / "project" / "tokens.json").write_text(json.dumps(tokens))
        folder = new(system, "today-band", "Today's band", "261025")
        checks.append(("new makes a dated folder", folder.name == "261025-today-band"))
        page = (folder / "index.html").read_text()
        checks.append(("new fills the title", "Today's band" in page and "{{TITLE}}" not in page))
        checks.append(("new fills the date", "2026-10-25" in page))
        checks.append(("new writes the record", "{{" not in (folder / "README.md").read_text()))
        checks.append(("new git-ignores dist", "*/dist/" in (system / "mockups" / ".gitignore").read_text()))
        try:
            new(system, "today-band", None, "261025")
            checks.append(("new refuses an existing folder", False))
        except SystemExit:
            checks.append(("new refuses an existing folder", True))
        try:
            new(system, "Bad Slug", None, None)
            checks.append(("new refuses a bad slug", False))
        except SystemExit:
            checks.append(("new refuses a bad slug", True))
        (folder / "sample.json").write_text("{}")
        dist = build(folder)
        css = (dist / "tokens.css").read_text()
        checks.append(("light on bare :root", ':root, [data-theme="light"] {\n  color-scheme: light;' in css))
        checks.append(("dark on any element", '[data-theme="dark"] {\n  --canvas: #111111;' in css))
        checks.append(("dark mirrored for the system setting",
                       '@media (prefers-color-scheme: dark) {\n:root:not([data-theme="light"]) {\n  --canvas: #111111;' in css))
        checks.append(("fonts load from fonts/", 'url("fonts/acme.woff2")' in css and (dist / "fonts" / "acme.woff2").exists()))
        checks.append(("the fragment has no document tags", "<html" not in (dist / "index.html").read_text().lower()))
        checks.append(("the preview is a full document", (dist / "preview.html").read_text().startswith("<!doctype html>")))
        checks.append(("other files are copied", (dist / "sample.json").exists()))
        try:
            build(system)
            checks.append(("build refuses a folder outside mockups/", False))
        except SystemExit:
            checks.append(("build refuses a folder outside mockups/", True))
    for name, ok in checks:
        print(f"{'ok' if ok else 'FAIL'}  {name}")
    return 0 if all(ok for _, ok in checks) else 1


def main(argv: list[str]) -> int:
    if argv[:1] == ["--selftest"]:
        return _selftest()
    if argv[:1] == ["--version"]:
        print(f"{Path(__file__).name} {SCRIPT_VERSION}")
        return 0

    def option(flag: str) -> str | None:
        return argv[argv.index(flag) + 1] if flag in argv else None

    if argv[:1] == ["new"] and len(argv) >= 3:
        print(new(Path(argv[1]), argv[2], option("--title"), option("--date")))
        return 0
    if argv[:1] == ["build"] and len(argv) >= 2:
        print(build(Path(argv[1]).resolve()))
        return 0
    print(__doc__.strip().split("Usage:")[1].rstrip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
