#!/usr/bin/env python3
"""Draw a wordmark (a name set in the brand font) as SVG outlines, so it renders without the font.

Outlines matter twice: an <img> of a <text> SVG falls back to whatever font the viewer has, and
the artifact's asset tiles show SVGs only through <img>. Kerning is not applied (no shaping
engine); check the result by eye, and regenerate whenever the font or the ink changes. Write one
file per theme ink: an <img> cannot inherit colour. In pages, inline the outline with
`fill: var(--ink)` instead.

Needs fontTools (and brotli for .woff2), so run it through uv:

  uv run --with fonttools --with brotli python3 wordmark.py \\
      --font fonts/brand-600.woff2 --text "Acme" --tracking -0.02 \\
      --out assets/Wordmark/acme-wordmark-ink.svg:#1d1d1f \\
      --out assets/Wordmark/acme-wordmark-light.svg:#f5f5f3

  uv run --with fonttools python3 wordmark.py --selftest   # builds its own font; no file needed
"""

import argparse
import sys
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

# Bump on every change to this file: ci/lint-skill-versions.sh (codespaces-setup) fails a change
# that doesn't.
SCRIPT_VERSION = 1


def wordmark_svg(font: Path, text: str, fill: str, tracking_em: float = -0.02) -> str:
    tt = TTFont(font)
    glyphs = tt.getGlyphSet()
    cmap = tt.getBestCmap()
    tracking = tracking_em * tt["head"].unitsPerEm
    path_pen = SVGPathPen(glyphs)
    bounds_pen = BoundsPen(glyphs)
    x = 0.0
    for char in text:
        name = cmap[ord(char)]
        # Font units are y-up; SVG is y-down.
        glyphs[name].draw(TransformPen(path_pen, (1, 0, 0, -1, x, 0)))
        glyphs[name].draw(TransformPen(bounds_pen, (1, 0, 0, -1, x, 0)))
        x += tt["hmtx"][name][0] + tracking
    x_min, y_min, x_max, y_max = bounds_pen.bounds
    view = f"{x_min:.0f} {y_min:.0f} {x_max - x_min:.0f} {y_max - y_min:.0f}"
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" role="img" aria-label="{text}">'
        f'<path fill="{fill}" d="{path_pen.getCommands()}"/></svg>\n'
    )


def _selftest() -> int:
    """Draw from a two-glyph font built here, so the test needs no font file."""
    import re
    import tempfile

    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen

    def box(width: int, height: int):
        pen = TTGlyphPen(None)
        if width and height:
            pen.moveTo((0, 0))
            pen.lineTo((0, height))
            pen.lineTo((width, height))
            pen.lineTo((width, 0))
            pen.closePath()
        return pen.glyph()

    builder = FontBuilder(1000, isTTF=True)
    builder.setupGlyphOrder([".notdef", "A", "B"])
    builder.setupCharacterMap({ord("A"): "A", ord("B"): "B"})
    builder.setupGlyf({".notdef": box(0, 0), "A": box(400, 700), "B": box(500, 600)})
    builder.setupHorizontalMetrics({".notdef": (0, 0), "A": (500, 0), "B": (600, 0)})
    builder.setupHorizontalHeader(ascent=800, descent=-200)
    builder.setupNameTable({"familyName": "Selftest", "styleName": "Regular"})
    builder.setupOS2()
    builder.setupPost()
    with tempfile.TemporaryDirectory() as tmp:
        font = Path(tmp) / "selftest.ttf"
        builder.save(str(font))
        svg = wordmark_svg(font, "AB", "#123456", tracking_em=0)
        tracked = wordmark_svg(font, "AB", "#123456", tracking_em=0.1)

    def view_box(text: str) -> list[float]:
        return [float(v) for v in re.search(r'viewBox="([^"]+)"', text).group(1).split()]

    checks = [
        ("the outline is a filled path, with no font needed to show it",
         'fill="#123456"' in svg and ' d="M' in svg and "<text" not in svg),
        ("the name is the accessible label", 'role="img" aria-label="AB"' in svg),
        # A spans 0..400; B starts at A's 500 advance and is 500 wide: 1000 across, 700 high.
        ("the viewBox spans both glyphs, flipped to SVG's y-down", view_box(svg) == [0, -700, 1000, 700]),
        ("tracking widens the advance between glyphs", view_box(tracked)[2] == 1100),
    ]  # fmt: skip
    for name, ok in checks:
        print(f"{'ok  ' if ok else 'FAIL'} {name}")
    return 0 if all(ok for _, ok in checks) else 1


def main() -> None:
    if sys.argv[1:2] == ["--selftest"]:
        sys.exit(_selftest())
    if sys.argv[1:2] == ["--version"]:
        print(f"wordmark.py {SCRIPT_VERSION}")
        return
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--font", type=Path, required=True)
    parser.add_argument("--text", required=True)
    parser.add_argument("--tracking", type=float, default=-0.02, help="em, e.g. -0.02")
    parser.add_argument("--out", action="append", required=True, help="path:fill, repeatable")
    args = parser.parse_args()
    for spec in args.out:
        path, fill = spec.rsplit(":", 1)
        Path(path).write_text(wordmark_svg(args.font, args.text, fill, args.tracking))
        print(path)


if __name__ == "__main__":
    main()
