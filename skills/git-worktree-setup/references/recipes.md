# Worktree recipes

Building blocks for `scripts/worktree-setup.sh`. Pick per concern, adapt the commands to the
project, and verify each one by hand first.

## The script

It runs inside a new worktree, right after `git worktree add`, and again whenever someone wants to
bring the worktree back up to date, so every step is safe to repeat. Keep what the project uses and
delete the rest.

```bash
#!/usr/bin/env bash
# Makes this worktree ready to work in. Run it after `git worktree add`; safe to run again.
set -euo pipefail
cd "$(dirname "$0")/.."

primary="$(git worktree list --porcelain | sed -n '1s/^worktree //p')"
branch="$(git branch --show-current)"
branch="${branch:-$(basename "$PWD")}"
repo="$(basename "$primary")"

# A stable port per name, so two worktrees never collide
hash_port() { printf '%s' "$1" | cksum | awk '{ print 10000 + $1 % 50000 }'; }

# A valid database name per branch. The hash keeps `a/b` and `a-b` apart
sanitize_db() {
  local name suffix
  name="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_')"
  suffix="$(printf '%s' "$1" | cksum | cut -d' ' -f1)"
  printf '%s_%s' "${name:0:40}" "$suffix"
}

# The gitignored files listed in .worktreeinclude, copied from the primary worktree.
# Existing files stay, so a second run keeps local edits
if [ "$PWD" != "$(cd "$primary" && pwd)" ] && [ -f .worktreeinclude ]; then
  git -C "$primary" ls-files -z --others --ignored --exclude-from="$PWD/.worktreeinclude" \
    | { git -C "$primary" check-ignore -z --stdin || true; } \
    | while IFS= read -r -d '' file; do
        [ -e "$file" ] && continue
        mkdir -p "$(dirname "$file")"
        cp -c "$primary/$file" "$file" 2>/dev/null \
          || cp --reflink=auto "$primary/$file" "$file" 2>/dev/null \
          || cp "$primary/$file" "$file"
      done
fi

# Dependencies, and the git hooks the install writes, so the push gate exists here too
pnpm install --frozen-lockfile
```

The two `cp` variants are reflinks on macOS and Linux: no extra disk until a file is modified.

## Files a new worktree needs

`.worktreeinclude` is an allowlist: a file is copied only when it is gitignored **and** matched
there. Claude Code reads the same file for the worktrees it creates.

```text
# .worktreeinclude — gitignored files every new worktree needs
.env
.env.local
apps/*/.env
```

Copy before the install when the install or the first command needs the files. Keep values that
differ per worktree out of the copied files; see **Ports** and **Database**.

## Dependencies, per stack

| Stack | Step | Notes |
|---|---|---|
| pnpm | `pnpm install --frozen-lockfile` | The global store makes it fast; do not copy `node_modules/` |
| npm / yarn | `node_modules/` in `.worktreeinclude`, then `npm ci` / `yarn install --frozen-lockfile` after the copy | The copy turns a cold install into a verification |
| bun | `bun install --frozen-lockfile` | |
| uv | `uv sync` | Never copy `.venv/`: it holds absolute paths |
| poetry | `poetry install` | Same, with `virtualenvs.in-project` |
| Ruby | `bundle install` | |
| Rust | `target/` in `.worktreeinclude` | The first build reuses compiled dependencies |
| Go | nothing | The module cache is global |

Build caches (`.turbo/`, `.next/cache/`) go in `.worktreeinclude`; they only save time.

## Ports

One deterministic port per repository and branch, stable across machines. Prefixing the repository
keeps two repositories with a branch of the same name apart. Write them to a file of their own,
gitignored and loaded after `.env`, so the copied `.env` stays identical to the primary one and no
loader has to pick between two values of the same key.

```bash
# This worktree's own ports, so two dev servers never collide
cat > .env.worktree <<EOF
API_PORT=$(hash_port "$repo-api-$branch")
WEB_PORT=$(hash_port "$repo-web-$branch")
EOF
```

Check how the app loads env files. If it cannot load a second file, propose that change to the user
rather than appending to a copied `.env`.

Do not start the server from the script: it is one server per worktree nobody asked for, and it
would outlive the worktree.

## Database

Only when the project already runs a local database. Two options, lightest first.

**A database per worktree on the shared local server.** Adapt the create and migrate commands. A
stopped server is a warning, not a failed worktree: start it and run the script again.

```bash
# This worktree's own database. Created only when missing, so a second run keeps its data
db="$(sanitize_db "$branch")"
echo "DATABASE_URL=postgres://postgres:postgres@localhost:5432/$db" >> .env.worktree

if pg_isready -q -h localhost; then
  psql -h localhost -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1 \
    || createdb -h localhost -U postgres "$db"
  pnpm db:migrate
else
  echo "Postgres is not running: start it and run this script again" >&2
fi
```

The `>>` needs the `cat >` from **Ports** before it, so the file is rewritten on every run. Without
ports, use `>` here.

Dropping it destroys data, so it is never in the script. It is a command for the user, after
removing the worktree:

```bash
dropdb -h localhost -U postgres --if-exists <database>
```

**A container per worktree**, when worktrees need different server versions or extensions: a step
that runs `docker run -d --rm --name "db-$db" -p "$(hash_port "db-$branch"):5432" …` unless
`docker ps -q -f name="^db-$db$"` already finds it, and `docker stop "db-$db"` as a command for the
user after removing the worktree. `--rm` makes the stop also the cleanup.

## Docker Compose

The Compose project name defaults to the directory name, which already differs per worktree, so
containers and volumes do not collide. Host ports do: replace fixed host ports with variables
(`"${DB_PORT:-5432}:5432"`) and write those variables to the env file Compose reads, hashed as
above. That edit is to a tracked file, so it is a proposal for the user, not part of the setup.

## Environment managers

`.envrc` and `mise.toml` are tracked, so every worktree has them, and each new worktree needs one
`direnv allow` or `mise trust`. Do not automate that: the trust prompt is the point.

## Git hooks

Every worktree shares `.git/config`, so `core.hooksPath` is the same everywhere. husky v9 points it
at `.husky/_`, which is gitignored and written by the `prepare` script during install, so a
worktree without the install has no working hooks and a push skips the gate. The dependency step
covers it; verify `.husky/_` exists in the throwaway worktree.
