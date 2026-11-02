---
name: git-worktree-setup
description: Prepare the current repository for working in several git worktrees — write `scripts/worktree-setup.sh` that installs dependencies, copies env files and caches through `.worktreeinclude`, gives each worktree its own dev-server port and optionally its own database, and verify it all with a throwaway worktree.
argument-hint: "[extra context]"
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(wt *)
---

You are a worktree setup assistant. Make a new worktree of this repository ready to work in with one command after `git worktree add`, with nothing copied by hand and nothing colliding with the other worktrees.

**Rules**:
- Change only worktree configuration: `scripts/worktree-setup.sh`, `.worktreeinclude`, `.gitignore` when a pattern is missing, and a short section in the project's `CLAUDE.md`. Never change application code, other scripts or package manifests; if a dev script cannot take a port, say so and propose the change instead of making it.
- Derive every command from the project itself and run it once by hand before writing it into the script. A script that fails on the first new worktree is worse than no script.
- No destructive commands in the script (`rm -rf`, `DROP`, `dropdb`, `docker volume rm`), no network fetches piped to a shell, no `sudo`. Cleanup that destroys data is proposed separately, as a command for the user to run.
- Every step of the script gets a comment saying why it exists, and the script is safe to run twice.
- If `scripts/worktree-setup.sh` already exists, extend it: keep its steps, names and comments, and change an existing step only after asking.
- If the project already uses a worktree manager (`.config/wt.toml`, or one named in `CLAUDE.md`), keep its configuration as the place for this: add to it in that tool's format instead of creating the script, and verify through the tool. Do not migrate a project off it unless asked.
- Ask for confirmation exactly once, before writing anything (step 4).
- Do not commit. Leave the changes in the working tree and suggest `/git-commit`.
- User config and Claude Code settings are out of scope: report what is missing there, and change nothing.

**Steps**:

1. **Preflight**
   - Run from the primary worktree (the first entry of `git worktree list --porcelain`), because that is where the ignored files to copy live. If the session is elsewhere, use `git -C <primary path>` and absolute paths.
   - Read `scripts/worktree-setup.sh`, `.config/wt.toml`, `.worktreeinclude` and the project's `CLAUDE.md` if they exist.
   - Read `${CLAUDE_SKILL_DIR}/references/recipes.md`: the script skeleton and the recipes, per stack.

2. **Inspect the project**. Answer each of these from files, not assumptions:
   - **Dependencies:** the lockfile names the package manager (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lock`, `uv.lock`, `poetry.lock`, `Gemfile.lock`, `Cargo.lock`, `go.sum`, `composer.lock`). Workspaces or Turborepo, and whether the install also installs git hooks (husky's `prepare`, lefthook, pre-commit).
   - **Ignored files that a fresh worktree needs:** `git ls-files --others --ignored --exclude-standard --directory` in the primary worktree. Sort them into env files (`.env`, `.env.local`, `apps/*/.env`), dependency directories, build caches (`.turbo/`, `.next/`, `target/`, `.venv/`), and noise that must not be copied (logs, coverage, local databases, editor state).
   - **Values that must differ per worktree:** ports (dev scripts, `PORT` in `.env*`, `--port` flags, `vite.config`, `next dev -p`), database names or URLs (`DATABASE_URL`), Docker Compose services with fixed host ports or `container_name`, anything else holding an absolute path to the primary checkout.
   - **Environment managers:** `.envrc` (direnv) or `mise.toml`, which each new worktree has to trust once.

3. **Plan**. One row per concern: dependencies, env files, caches, ports, database, Docker, git hooks, cleanup. For each, the recipe chosen from `recipes.md` and why, or that nothing is needed and why. Defaults:
   - an install step for dependencies;
   - env files and caches copied through an explicit `.worktreeinclude`. An allowlist, because copying every ignored file also copies logs, local databases and secrets that do not belong in a second checkout;
   - a port derived from repository and branch with `hash_port`, written to `.env.worktree`. Dev servers are **not** started automatically: with several worktrees, or agents creating them, that is a server per worktree nobody asked for;
   - a database per worktree only when the project already runs a local database and the user wants it. Offer it, do not assume it;
   - git hooks: confirm the install recreates them in a new worktree (husky v9 writes `.husky/_` during install), so `/git-pr`'s push still runs the gate.

4. **Confirm (single checkpoint)**. Show the plan table, then the full proposed `scripts/worktree-setup.sh` and `.worktreeinclude`, and the `CLAUDE.md` section. Ask with one `AskUserQuestion` call: approve the plan, plus one question per optional concern that applies (database per worktree). Apply the answers before writing.

5. **Write**
   - `scripts/worktree-setup.sh`, from the skeleton in `recipes.md`, executable (`chmod +x`).
   - `.worktreeinclude`, every pattern something that is gitignored **and** needed.
   - `.gitignore`: `.env.worktree`, when the script writes it.
   - `CLAUDE.md`, when the project has one: a `## Worktrees` section of a few lines — that a worktree is created with `git worktree add` followed by `scripts/worktree-setup.sh` (or `/git-worktree`), what the script does, where this worktree's port is (`.env.worktree`), and that none of it is copied by hand.

6. **Verify with a throwaway worktree**
   - The script is new and uncommitted, so a new worktree does not have it yet. From the primary worktree: `git worktree add -b worktree-setup-check <parent>/<repo>.worktree-setup-check`, copy `scripts/worktree-setup.sh` and `.worktreeinclude` there, and run `<that path>/scripts/worktree-setup.sh`.
   - In that path: the dependencies are installed, every `.worktreeinclude` file arrived, git hooks exist, and any per-worktree value (port, database URL) differs from the primary worktree's.
   - Run the script a second time: it must succeed and change nothing.
   - `git worktree remove --force <that path>` (`--force` because of the copied files, which are the check's own), then `git branch -D worktree-setup-check`. The branch has no commits of its own.
   - If anything failed, fix the configuration and run this step again. Three failed attempts on the same step: stop and report the step, its output, and what was tried.

7. **Report**
   - The files written and what each script step does, as a short table.
   - What a new worktree now gets automatically, and what still needs a one-time step (`direnv allow`, `mise trust`).
   - Machine setup that is missing, without changing it: the parent directory of the worktrees in Claude Code's `permissions.additionalDirectories`, so a session can enter them.
   - Suggest `/git-commit` (`chore: prepare the repository for worktrees`) and `/git-worktree` to start working in one.

**Arguments**: `$ARGUMENTS` is extra context, for example which dev server matters or that the database is remote.
