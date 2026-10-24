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
"""

import argparse
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont


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


def main() -> None:
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
