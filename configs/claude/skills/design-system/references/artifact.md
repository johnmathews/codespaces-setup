# The claude.ai Design System artifact, with its source in the repo

The artifact is the published, browsable design system that later agents read ("read its README
first"). The repository holds its source, so changes go through git and the gate. The artifact
type's own instructions arrive in the create result and in `artifact-type/reference/format.md`,
`craft.md` and `cover.md` (read them on the system's URL); this file is the condensed practice.

## Create once, keep the source in the repo

1. Find the type with `Artifact quickstart` (intent `other`) or `list scope:types`, then create
   the system: `publish` with `type_url`, `title` (the brand's name), no files. Never pass
   `type_url` again; that makes a second system. Record the URL in `brand/design-system/SYSTEM.md`.
2. Read `format.md`, `craft.md`, `cover.md` and `demo.json` from the new system before writing.
3. Write every file under `brand/design-system/project/<its path>` in the repo: the same paths the
   artifact serves. One `publish` with `root: brand/design-system` sends them.

## What goes in it

| Path | Notes |
| --- | --- |
| `project/README.md` | The brand book's front page, written as usage rules that name tokens. No title. |
| `project/foundations.md`, `voice.md` | Further sections (any `*.md` outside `components/`). |
| `project/tokens.json` | See tokens.md. |
| `project/components/<Name>/README.md` | First sentence is the summary; then use, states, what the consumer provides. |
| `project/components/<Name>/preview.html` | Line 1 `<!-- @dsCard group="…" height=N -->`, then a complete small HTML document using only `var(--token)` and the style classes. |
| `project/components/Cover/preview.html` | The cover. **No README beside it**, or it becomes an ordinary component. Follow cover.md. |
| `project/components/bundle.js` | Even with no scripted components, ship one line (`window.<Namespace> = {}`). Without a bundle the page shows previews as static images that don't grow to fit. |
| `project/assets/<Group>/…` | SVGs are **uploads**, not files: upload first, then record `{name, blob, size, type}` in the index. A group's README.md and licences are files. |
| `project/fonts/…` | Font binaries only; licences go elsewhere (e.g. `project/licenses/`). |
| `project/design-system.json` | The index (shape in the type's SKILL.md, with `createdOnFiles`). Written **last**, and only re-sent when its own keys change. |

## Publishing

- Upload SVGs: `publish` with `url`, `asset: true`, `file_paths: [...]`; record each returned id
  and byte size in the index.
- Then one `publish`: `url`, `root: <abs>/brand/design-system`, `file_path: <abs>/…/design-system.json`,
  `files: {"project/x": "project/x", …}` for every other text and font file (not the uploaded SVGs).
- Later changes: publish only the changed files the same way; leave the index out unless an asset
  record or the title changed.

## Verify before calling it done

1. Run the gate (`check_design_system.py brand/design-system --complete`).
2. Open the artifact in the browser. Check the cover and every component card in each theme (the
   Components section has a theme menu). Cards are lazy: scroll slowly; a blank card usually just
   hasn't loaded.
3. Check phone width with `render_previews.mjs` (the browser extension can't resize the page below
   desktop). Only the cover may overflow, by design.
4. Watch for: cards clipped at their `height` (raise it), Dutch or German strings wrapping badly,
   a wordmark vanishing on dark (ship one SVG per theme ink; inline the outline with
   `fill: var(--ink)` in previews), and green or any meaningful colour used as decoration on the
   cover.

## Things that bit last time

- A preview's marker comment before `<!doctype>` puts the page in quirks mode when rendered
  elsewhere; the scripts strip it, and so should anything else that reuses previews.
- An email preview can't use `var()` or `<style>`: hard-code the light values, inline styles,
  tables, no images, and a real-length link with `word-break:break-all`.
- Preview copy is real copy from the product's locale files, including every language it ships.
- Edits made on the artifact page never reach the repo by themselves: read the changed files back
  before editing locally.
