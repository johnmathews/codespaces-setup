# Mockups: show it before you build it

A visual change is decided on a picture, not in code. Code written before the person has seen the
options gets rewritten when they see the result, and a mockup is cheaper than that rewrite. This
is the loop, the same in every project with a `brand/design-system/`.

## When

Mock up first whenever the person will see something new: a colour, a size, spacing, type, a
mark or icon, a component or screen that doesn't exist yet, or a layout change. That holds even
when the request names the value ("make it blue"): the picture is how they check that blue is what
they meant, beside the alternatives.

Go straight to code only when one of these is true:

- the change restores what the system already says (a bug: the code drifted from its card);
- the person has already seen and picked this exact look, in a mockup or a screenshot;
- the change is invisible (refactor, data, tests) or copy-only and the voice rules decide it.

## The loop

1. **Brief.** One sentence: what is being decided, and what stays as it is. Read the system's
   README, `foundations.md` and the affected cards first, so the options start from what exists.
2. **Start the mockup** in the system it changes:
   `python3 <skill>/scripts/mockup.py new <system-dir> <slug> --title "<the question as a name>"`.
   It makes `<system-dir>/mockups/<yymmdd>-<slug>/` with `index.html` (the page) and `README.md`
   (the record). `<skill>` is this skill's folder.
3. **Build the options** in `index.html`, following the comment at its top:
   - two to four options, lettered, one marked recommended, each a real alternative on the
     question and nothing else (the rest of the screen stays as it is);
   - every proposed value as a `--candidate-*` property, everything else from the system's
     tokens and type classes, never a raw value standing in for an existing token;
   - the change shown where it lands, on the real screen or component at real size with the
     product's real copy and plausible data, in both themes (the page's light and dark panes);
     a close-up or swatch row only beside that, never instead of it. Start from the affected
     cards' `preview.html`: copy their markup and their whole style block (its phone-width
     rules included) into the stage, so the mockup draws what the product draws, then change
     only the candidate values;
   - a measure for every new colour pairing (`data-fg`, `data-bg`, `data-min`), so contrast is
     on the page, misses included.
4. **Build and look.** `python3 <skill>/scripts/mockup.py build <mockup-dir>`, then
   `node <skill>/scripts/render_mockup.mjs <mockup-dir>/dist <out-dir> --playwright <project>/node_modules/playwright/index.mjs`.
   Read all four PNGs and the problem lines yourself. Fix overflow, errors and anything that
   doesn't look like the product before anyone else sees it.
5. **Show.** Publish `dist/` as a private Artifact: `file_path` its `index.html`, `root` the
   `dist` folder, `files` `tokens.css` and each `fonts/…` file (plus any other file there), and
   an `icon` and a one-sentence `description` on the first publish. Write the link into the
   README's **Link** line at once: it is how any later session updates the same page. Send the
   person the link and the phone-light PNG, then ask with the options as choices (the
   recommended one first). Their comments on the page come back to you.
6. **Iterate on the same link.** Change `index.html`, build, render, look, and publish again:
   the same `file_path` in the same session, otherwise the README's link as `url` (read it with
   the Artifact tool first). Add a line under Rounds in the README. Keep options they ruled out off the
   page unless they ask to compare again.
7. **Record, then build.** When they pick, fill the README (Status `decided`, the option, their
   words, the date, the link) and add the decision to the project's decisions log. Only now write
   the code and the system changes (tokens, cards), then screenshot the real app at the same
   widths and check it against the chosen option before calling it done.

Commit the mockup folder (`index.html`, `README.md`, any data or images) with the code it led
to; `dist/` and the renders are never committed (`mockups/.gitignore`). A mockup that was dropped
keeps its folder with Status `dropped`: the options someone rejected are a record too.

## Asking

Ask once per round, with the choices drawn from the page: "Which today band? A (neutral grey,
recommended), B (pale blue), C (keep yellow)". Say what each costs in a word where it matters
("1.8:1 on the page"). Don't ask questions the picture answers, and don't ask before the picture
exists.

## Common mistakes

| Mistake | Instead |
| --- | --- |
| Editing tokens or components, then showing a screenshot | The mockup first; code after the pick |
| One option ("here's the blue") | Two to four, so the person picks rather than approves |
| Swatches only | The change in its real place, at real size, in both themes |
| Raw hex for everything | Tokens for what exists, `--candidate-*` for what's proposed |
| A new mockup link each round | One Artifact per question, republished |
| Contrast "looks fine" | A measure on the page for every new pairing |
| Rendering and not looking | Read every PNG before the link goes out |
