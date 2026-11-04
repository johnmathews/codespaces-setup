# Sitrep: a "Shipped" section, and a per-project shipping path

The sitrep had no place that said whether a change was pushed, merged and live
in each environment. Nothing in the skills recorded how a project ships either:
`/merge-push` decided its path from one rule (a remote means a PR), so a project
that merges into `main` locally and pushes it was not supported.

- **New reference, `references/shipping.md`.** It defines a `## Shipping`
  section that each project keeps in its `CLAUDE.md`. `Lands by:` is
  `pull request`, `direct push` or `local only`. Each environment gives what
  puts a change there and a read-only `Check:` command that shows what is live.
- **Missing section:** it is worked out from the remote, the branch protection
  rules and the history of `main`, then shown to the user and saved only once
  they confirm it. Until then a repo with a remote lands by pull request. A
  wrong guess there costs one PR. The other wrong guess puts unreviewed commits
  on `main`.
- **Only `/merge-push` and `/done` write the section**, on the work branch, so it
  lands with the change. The sitrep only reads, because a sitrep changes no work
  and the main checkout is not written.
- **The sitrep gained "Shipped"**, just before "Doing now": the path, then one
  ✅ ⬜ ❌ bullet per step and per environment. The marks follow the DoD's rules.
  An environment is ticked only by its `Check:` command, never by a merge,
  because "deployed" is a claim about runtime.
- **`/merge-push` gained Step 2C, the direct path.** It rebases the branch onto
  `origin/main` and pushes `HEAD:main` from the worktree. This lands the same
  commits as a local merge and push without writing the shared main checkout,
  and a `main` that moved meanwhile makes the push fail, so it can't clobber
  anything. It then watches CI on `main` and fast-forwards the local `main`
  only where that is safe.
- **`/done` Phase 8** now branches on `Lands by:`. A PR project gets 8a as
  before. Any other project gets a commit on the branch, and `/merge-push` lands
  it. `/done` still never pushes to `main`.
- **`done_when:`** says how far along the environments "done" goes when a
  project deploys ("merged; live on staging"). With nothing said, done means
  merged.

This repo now has its own `## Shipping` section: it lands by pull request, and
its environments are `~/.claude` on the main machine and the Codespaces.

The drift scan guards the new default (`lands-by-default`), and
`rule-ownership.md` gained a `shipping.md` home.
