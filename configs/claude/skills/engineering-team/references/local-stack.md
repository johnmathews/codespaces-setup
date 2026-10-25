# Local stack: see it running before CI

> Purpose
>
> The home of the rule that a user-visible change runs locally, in front of the user, before it
> is pushed. It covers when the rule applies, how to bring the stack up, how to keep the login
> and the data across restarts and worktrees, and how to seed demo data. A fast look at the real
> app beats a CI round trip, and the user ranks fast iteration loops very high.

## 1. When it applies

- **Every change the user can see or use:** a screen, a component, copy, a setting, a flow, an
  API response a screen shows. Bring the stack up before Phase 4's `/done`, because `/done`
  pushes, opens the PR and starts CI.
- **During Phase 3 too, when the user is iterating:** keep the stack running between units, so
  each change shows on a reload rather than after a push.
- **Skip it** for a change with nothing to see (a refactor, tests, docs, CI config), for a
  project with no runnable app, or when the user says to go straight to CI. Say which applies in
  one line.

## 2. Bring it up

1. Read how the project runs locally: the README's getting-started section, `docs/development.md`
   or its equivalent, `package.json` scripts, `Makefile`, `docker-compose.yml`. Use the project's
   own commands, never an invented setup.
2. Check the ports first (`lsof -iTCP:<port> -sTCP:LISTEN`). A server already running from
   another checkout serves that checkout's code, not this change: stop it or use another port,
   and say which.
3. Start each long-running process (API, dev server) in the background, from the checkout that
   holds the change (the run's worktree), and wait until each answers a request before handing
   over the link.
4. Give the user the URL, how to sign in (§3), and two or three concrete things to try that
   exercise the change. Then wait for their look before running `/done`, unless they said to go
   ahead.
5. Leave the stack running when the session moves on, and say so; stop it only when the user
   asks or the run closes. Name any process still running in the session verdict
   (`../SKILL.md` §"Closing a run").

## 3. Keep the login and the data

The user's local account, password and data must survive restarts, rebuilds, branch switches and
worktree removal.

- **Never delete or reset the local database** (no `rm -rf` of the data folder, no
  `git clean -x`, no `docker compose down -v`, no fresh migration over it) unless the user asks.
- **Keep the data outside the worktree.** Git-ignored data folders do not exist in a fresh
  worktree, and removing the worktree deletes them. Point the project's data setting (a
  `DATA_DIR`, `DATABASE_URL` or a Compose volume) at the main checkout's data folder, or at a
  stable per-project path such as `~/.local/share/<project>/dev`, and use the same one every
  time.
- **Reuse an existing account** before making a new one. When one has to be made, prefer a
  local-only demo account (§4) over the user's real email, and record how to sign in in a
  git-ignored file the project already uses for local secrets (or `.dev-login` beside the data
  folder). Tell the user where it is. Never commit credentials.

## 4. Seed demo data

An empty app hides most of a change. Wherever the project allows it, the stack comes up with
plausible demo data.

- **Use the project's seed** if it has one (a `seed` script, fixtures, an admin command).
- **Otherwise offer to add one**, as part of the change or as its own small unit: idempotent (a
  second run changes nothing), local-only (refuses to run against production settings), and
  creating one demo account with known credentials plus enough data to show every state the
  screens have (an empty item, a full one, today, a past week). Seed the data only when it is
  missing, so it never overwrites what the user made by hand.
- Data from a fixture the tests already use is better than invented data, because both stay true
  together.
