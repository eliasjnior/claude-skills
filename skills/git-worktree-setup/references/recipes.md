# Worktree recipes

Building blocks for `.config/wt.toml`. Pick per concern, adapt the commands to the project, and
verify each one by hand first. The full reference is the worktrunk documentation
(https://worktrunk.dev/hook/, https://worktrunk.dev/step/), also bundled with the worktrunk plugin.

## Which hook

| Hook | Runs | Use for |
|---|---|---|
| `pre-start` | once, on creation, blocking | what the first command in the worktree needs: dependencies, env files |
| `post-start` | once, on creation, in the background | slow or optional work: cache copies, builds, dev servers |
| `pre-remove` | before removal, inside the worktree | stopping what the worktree started |
| `post-remove` | after removal, from the primary worktree | external cleanup |

A table runs its commands concurrently. A list of tables (`[[pre-start]]`) is a pipeline: each
step waits for the previous one.

```toml
# Concurrent
[pre-start]
install = "pnpm install --frozen-lockfile"
env = "wt step copy-ignored"
```

```toml
# Sequential: copy first, so the install reuses what was copied
[[pre-start]]
copy = "wt step copy-ignored"

[[pre-start]]
install = "npm ci"
```

Templates: `{{ branch }}`, `{{ repo }}`, `{{ worktree_path }}`, `{{ primary_worktree_path }}`,
`{{ default_branch }}`, `{{ vars.<key> }}`. Filters: `sanitize`, `sanitize_db`, `hash_port`. Values
are shell-escaped automatically, so do not quote them.

## Files a new worktree needs

`wt step copy-ignored` copies gitignored files from the primary worktree, with reflinks (no extra
disk until modified). Always pair it with `.worktreeinclude`, an allowlist: a file is copied only
when it is gitignored **and** matched there.

```text
# .worktreeinclude — gitignored files every new worktree needs
.env
.env.local
apps/*/.env
```

Run it in `pre-start` when the install or the first command needs the files, in `post-start`
otherwise. Env files holding per-worktree values (a port, a database URL) are copied and then
rewritten in a later pipeline step; see **Ports** and **Database**.

## Dependencies, per stack

| Stack | Hook | Notes |
|---|---|---|
| pnpm | `pre-start`: `pnpm install --frozen-lockfile` | The global store makes it fast; do not copy `node_modules/` |
| npm / yarn | `[[pre-start]]` copy `node_modules/` (in `.worktreeinclude`), then `npm ci` / `yarn install --frozen-lockfile` | The copy turns a cold install into a verification |
| bun | `pre-start`: `bun install --frozen-lockfile` | |
| uv | `pre-start`: `uv sync` | Never copy `.venv/`: it holds absolute paths |
| poetry | `pre-start`: `poetry install` | Same, with `virtualenvs.in-project` |
| Ruby | `pre-start`: `bundle install` | |
| Rust | `post-start`: copy `target/` | The first build reuses compiled dependencies |
| Go | nothing | The module cache is global |

Build caches (`.turbo/`, `.next/cache/`) go in `.worktreeinclude` and copy in `post-start`; they
only save time.

## Ports

One deterministic port per repository and branch, stable across machines. Prefixing the repository
keeps two repositories with a branch of the same name apart.

```toml
[list]
# URL column in `wt list`, dimmed when nothing is listening
url = "http://localhost:{{ (repo ~ '-' ~ branch) | hash_port }}"

[aliases]
# `wt dev` starts this worktree's dev server on its own port
dev = "pnpm dev --port {{ (repo ~ '-' ~ branch) | hash_port }}"
```

When the app reads the port from an env file instead of a flag, write it after the copy:

```toml
[[pre-start]]
copy = "wt step copy-ignored"

[[pre-start]]
# This worktree's port, so two dev servers never collide
port = "echo PORT={{ (repo ~ '-' ~ branch) | hash_port }} >> .env.local"
```

If the copied file already sets the key, appending leaves two values and which one wins depends on
the env loader. Check the loader, or write the per-worktree values to a file of their own that the
app also loads.

Several services: hash a different string per service (`(repo ~ '-api-' ~ branch)`,
`(repo ~ '-web-' ~ branch)`).

Starting the server on creation, only when the user asked for it. `wt step tether` kills the whole
process tree when the worktree is removed, so no `pre-remove` is needed:

```toml
[post-start]
server = "wt step tether -- pnpm dev --port {{ (repo ~ '-' ~ branch) | hash_port }}"
```

## Database

Only when the project already runs a local database. Two options, lightest first.

**A database per worktree on the shared local server.** Adapt the create and migrate commands:

```toml
[[pre-start]]
# The database name and URL for this worktree, readable later with `wt config state vars get db_url`
vars = "wt config state vars set db_name={{ branch | sanitize_db }} db_url=postgres://postgres:postgres@localhost:5432/{{ branch | sanitize_db }}"

[[pre-start]]
# Created only when missing, so recreating a worktree for the same branch keeps its data
create = "psql -h localhost -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname = '{{ vars.db_name }}'\" | grep -q 1 || createdb -h localhost -U postgres {{ vars.db_name }}"

[[pre-start]]
url = "echo DATABASE_URL={{ vars.db_url }} >> .env.local"

[[pre-start]]
migrate = "pnpm db:migrate"
```

Dropping it on removal destroys data, so it is written only with explicit approval:

```toml
[pre-remove]
# Approved by the user: removing a worktree drops its database
drop = "dropdb -h localhost -U postgres --if-exists {{ vars.db_name }}"
```

**A container per worktree**, when worktrees need different server versions or extensions: a
`post-start` pipeline that sets `container` and `port` vars (`('db-' ~ branch) | hash_port`), then
`docker run -d --rm --name {{ vars.container }} -p {{ vars.port }}:5432 …`, and a `pre-remove`
`docker stop {{ vars.container }} 2>/dev/null || true`. `--rm` makes the stop also the cleanup.

## Docker Compose

The Compose project name defaults to the directory name, which already differs per worktree, so
containers and volumes do not collide. Host ports do: replace fixed host ports with variables
(`"${DB_PORT:-5432}:5432"`) and write those variables into `.env` in a `pre-start` step, hashed as
above. That edit is to a tracked file, so it is a proposal for the user, not part of the setup.

## Environment managers

`.envrc` and `mise.toml` are tracked, so every worktree has them, and each new worktree needs one
`direnv allow` or `mise trust`. Do not automate that: the trust prompt is the point.

## Git hooks

Every worktree shares `.git/config`, so `core.hooksPath` is the same everywhere. husky v9 points it
at `.husky/_`, which is gitignored and written by the `prepare` script during install, so a
worktree without the install has no working hooks and a push skips the gate. The dependency hook
covers it; verify `.husky/_` exists in the throwaway worktree.
