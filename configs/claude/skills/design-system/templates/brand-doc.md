# Brand and design system

<!-- Copy to docs/brand.md and fill in. Keep it short: it says where things live and how to
change them; the brand book itself lives in the design system. -->

> Purpose
>
> This document says where <Project>'s brand lives, how its design system is kept, and how to
> change it. Read it before designing any page or email.

## 1. The direction

<Two or three sentences: the direction's name, the feeling, the references and what was taken
from each.> The reasons, goals and anti-goals are in the [brand design](<path to the spec>).

## 2. The design system

The design system is a claude.ai artifact: <artifact URL>. It holds the brand book, the tokens in
<n> themes, <n> components with live previews and guidelines, and the assets. Agents designing for
<Project> read its README first.

Its source lives in this repository, at the same paths the artifact uses:

| Path | Contents |
| --- | --- |
| `brand/design-system/SYSTEM.md` | The artifact's URL |
| `brand/design-system/checks.json` | The gate's settings: required components, extra contrast pairs, banned words |
| `brand/design-system/project/design-system.json` | The index: title, asset records (upload ids) |
| `brand/design-system/project/tokens.json` | Every colour, type style, space, radius and shadow |
| `brand/design-system/project/*.md` | The brand book |
| `brand/design-system/project/components/<Name>/` | Each component's `README.md` and `preview.html` |
| `brand/design-system/project/assets/`, `fonts/` | Uploaded SVGs and self-hosted fonts |

`scripts/check_design_system.py` is the gate; CI runs it with `--complete`. `make design-preview`
(or `python3 scripts/design_preview.py brand/design-system`) builds an offline gallery into the
git-ignored `brand/design-system/preview/`.

## 3. Changing it

1. Edit the files under `brand/design-system/project/`.
2. Run the gate and the tests.
3. Publish only the changed files to the artifact with `root: brand/design-system`; send
   `design-system.json` only when its own keys change, and last.
4. Upload a new or changed SVG as an asset first, and record its id, size and type in the index.
5. Regenerate the app's `tokens.css` whenever `tokens.json` changes.

Edits made on the artifact page itself are not in the repository: read the changed files back
before editing here.

## 4. Mockups

A visual change starts as a mockup and waits for a pick before any code. Each question gets a
folder in `brand/design-system/mockups/<yymmdd>-<slug>/`: `index.html` (the options, built from
the tokens, both themes side by side) and `README.md` (the question, the options, the decision and
the link to the private artifact it was published as). The design-system skill's
`references/mockups.md` has the loop and its commands. `dist/` folders are builds and are not
committed.
