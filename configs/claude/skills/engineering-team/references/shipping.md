# Shipping: how a change reaches each environment

> Purpose
>
> Every project ships differently. Some land a change through a pull request, some merge into
> `main` locally and push it, and each has its own environments. This file defines the
> `## Shipping` section a project keeps in its `CLAUDE.md`, how to work it out when the section
> is missing, and who reads and writes it. `/merge-push` and `/done` read it to choose how a
> change lands. The sitrep reads it for the shipping steps in its Done, Doing and Need to do sections
> (`status-updates.md` §3).

## 1. The section a project keeps

The project's root `CLAUDE.md` (or `AGENTS.md`, if that is what the project has) holds it:

```markdown
## Shipping

- **Lands by:** pull request
- **Environments:**
  - staging: deploys on every push to `main` (`.github/workflows/deploy.yml`).
    Check: `gh run list --workflow deploy.yml --branch main --limit 1`
  - production: manual, `gh workflow run release.yml` once staging looks right.
    Check: `curl -s https://example.com/version`
```

`Lands by:` takes one of three values:

| Value | What landing means | Steps the sitrep tracks |
| --- | --- | --- |
| `pull request` | push the branch, open a PR, CI passes on it, merge it on the platform | pushed, merged |
| `direct push` | merge the branch into `main`, then push `main` | merged into `main`, pushed |
| `local only` | merge into `main`; there is no remote | merged |

Each environment line gives three things:

- its name
- what puts a change there: every push to `main`, a tag, a manual command
- a `Check:` command that shows what is live there

A project with nothing deployed writes `- **Environments:** none`.

Rules for the `Check:` command:

- **It observes the environment**: a deploy run's result, a version endpoint, an image tag in
  use. "Deployed" is a claim about runtime, so a merge never ticks an environment on its own
  (`general-guidelines.md` rule 2).
- **It only reads.** The sitrep runs it, and a sitrep changes nothing.
- **When there is no way to check from a dev machine**, write `Check: none`. The sitrep then
  shows the environment as not checked.

## 2. When the section is missing

Work it out, show it to the user, and save it only once they confirm it.

1. **No remote** (`git remote` prints nothing): `local only`.
2. **A remote, and `main` requires a pull request:** `pull request`. Read the rules with
   `gh api repos/{owner}/{repo}/rulesets` and
   `gh api repos/{owner}/{repo}/branches/main/protection`. A 404 from either is an answer.
3. **A remote with no such rule:** read the history with
   `git log --first-parent --oneline -20 origin/main`. Subjects ending in `(#123)`, or "Merge pull
   request", mean `pull request`. Plain commits mean `direct push`. Ask when it's mixed or unclear.
4. **Environments:** read `.github/workflows/` (or the project's CI config) for jobs that deploy,
   whether on a push to `main`, on a tag, or by hand, and read the project's deploy docs. List each
   one found with its trigger. The user confirms or corrects the list.

**Until the user confirms, a repo with a remote lands by pull request.** A wrong guess of
`direct push` would put unreviewed commits on `main`. A wrong guess of `pull request` costs one
PR.

**Who saves it:**

- `/merge-push` and `/done` save the confirmed section to `CLAUDE.md` on the work branch, so it
  lands with the change. They already commit to the repo.
- The sitrep only reads. With no section, it shows what it worked out, marked "worked out, not
  confirmed", and leaves `CLAUDE.md` alone.

## 3. How far "done" goes

When the section lists environments, a run's `done_when:` says how far along the path the work
goes: "merged to main; live on staging", or "live in production". It is set at the start and
agreed at the Phase 2 gate, like the rest of `done_when:` (`SKILL.md` §"The run directory").
With nothing said, done means merged.
