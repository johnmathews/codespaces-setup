# Tokens: the standard roles and the rules they follow

Every project uses the **same role names** with its own values. That is what lets the gate, the
CSS, the Tailwind mapping and the shadcn-vue adapter be shared across projects unchanged, and
what lets someone moving between projects read any stylesheet. The names are fixed; only values
and accents vary.

## Colour roles (every project defines all of these)

| Role | Use | Contrast duty |
| --- | --- | --- |
| `canvas` | Page background; the ground of every email | — |
| `panel` | Raised surfaces on `canvas`: cards, dialogs, menus | — |
| `tile` | Quiet fills: neutral states, notes, code blocks, hover | — |
| `line` | Dividers only (table rows, rules) | none: never a control border |
| `control-border` | Borders of inputs, outlined buttons, pills | 3:1 on `canvas` and `panel` |
| `ink` | Text and icons; the primary button's fill | 4.5:1 on `canvas`, `panel`, `tile` |
| `on-ink` | Text on an `ink` fill | 4.5:1 on `ink` |
| `ink-secondary` | Supporting text: captions, hints, timestamps | 4.5:1 on `canvas`, `panel`, `tile` |
| `error-ink` | Form errors, always with an icon and words | 4.5:1 on `canvas`, `panel` |
| `focus` | The focus ring: a solid 2px outline at a 2px offset | 3:1 on `canvas`, `panel` |

`check_design_system.py` checks exactly these pairings in every theme. A project's own accent
roles (e.g. Parkahead's `free-surface` / `free-ink`, meaning a free parking bay) go in
`checks.json` `extra_contrast_pairs`, with a usage note that says what the accent means and
where it may never appear.

A project with a stricter rule of its own (say, secondary text at 7:1) keeps it: add the pairs at
the stricter ratio to `extra_contrast_pairs` (`["ink-secondary", "canvas", 7.0]`), and the gate
checks both.

The pairs that most often fail: `ink-secondary` on `tile` (the mockup grey usually lands just
under 4.5:1; move it one step darker and say so), and any faded state. A label faded to 40%
opacity fails, so a "Sending…" button keeps full colour and uses `aria-busy`; only truly disabled
controls fade.

## Removing a role or a component

Removing one is a sweep, not an edit: the name lives in more places than the token. Remove it
from all of these in the same change, then grep the whole repo for the name and for the words that
described it (the feature's own vocabulary, like "Picked row" or "today's band"), and fix every
hit outside point-in-time records (journal, decision log, specs, mockups):

| Place | What goes |
| --- | --- |
| `tokens.json` | the token |
| `checks.json` | its `extra_contrast_pairs`, or the component in `required_components` |
| the app's stylesheet | its `--color-…` mapping and its print value |
| generated tokens | regenerate (`npm run tokens` or the project's equivalent) |
| cards | `components/<Name>/` for a component; every README and preview that names a role |
| `foundations.md`, `README.md`, `voice.md` | the role table, rules and examples that use it |
| the project's docs | brand, architecture and development docs, and its decision log's superseded rows |
| the app | the primitive, its style guide section and its tests |
| the artifact | `null` for the removed paths on the next publish (artifact.md) |

In one project, removing a role, two components and a feature row this way still left about
twenty stale mentions for a later audit to find, because the sweep was done from memory rather
than by grep.

## Projects that already have tokens

Many apps already have semantic variables (`--color-bg`, `--color-surface`, `--text-muted`).
Rename them to the roles; don't alias them permanently, because two names for one colour is the
inconsistency this standard exists to remove.

1. Map each existing variable to a role by what it is **used for**, not what it is called: grep
   its uses. A `--color-border` used on inputs is `control-border`; one used on dividers is
   `line`. If one variable does both jobs, split it. Something with no role (a brand accent) stays
   as a named accent with its usage note.
2. Write the mapping into the brand design or the PR description as a table (old → role).
3. Put the values into `tokens.json` under the role names, check contrast with the gate (old
   values often miss on `tile`), and generate `tokens.css`.
4. Replace every use in one change (`sed` over `src/`, then read the diff). If the app is too big
   for one change, keep the old names temporarily as `--color-bg: var(--canvas);` in a clearly
   marked block, and remove the block before the work is called done.

## The rest of tokens.json

- Themes: `light` first, then `dark` (a token missing a theme inherits the first theme's value,
  so put the primary theme first). Values are `#rrggbb` in this house style (the page accepts more
  formats, but the gate only measures hex).
- Type: one family is enough for most brands; give styles semantic names (`display`, `title-1`
  to `title-3`, `body-large`, `body`, `caption`, `label`, `code`) with `fontSize`, `lineHeight`,
  `fontWeight` and `letterSpacing`. Note the phone rule in `display`'s usage (e.g. "below 640px,
  set at title-1 size").
- Spacing `space-1` … `space-24` on a 4px base; radius `radius-sm`, `radius-md`, `radius-lg`,
  `radius-full`; `shadow` per theme (often `none` in dark).
- Every token has a `usage` note that says where it goes. The page shows them; agents read them.

## Shape rules the artifact page enforces

Every family except `type` is a list, `{"tokens": [{"name", "value", "usage"}]}`; a name-to-value
map (DTCG/W3C style) is valid JSON the page cannot read. Names match
`[A-Za-z0-9][A-Za-z0-9_.-]{0,63}` and are unique across families. Named colours, `var()` and
`color-mix()` drop silently. The gate catches all of these.

## Fonts

Self-hosted files go in `fonts/` and `type.fonts[].file`; a hosted face (Google Fonts) has no file
and is named in `type.families` only. Which to use is the project's call: self-hosting avoids a
third-party request and a CSP entry; Google Fonts is less work. Ask if the project has a privacy or
CSP stance; don't assume one.
