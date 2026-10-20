---
name: git-worktree
description: Work in a separate git worktree managed by worktrunk (`wt`) — create one for a task and move this session into it, run several tasks in parallel worktrees, list them, leave one, or clean up the ones whose PR was merged. Use when the user asks to work in a worktree, in parallel, or on a separate branch without touching the current checkout, or says "abre uma worktree", "numa worktree", "em outra worktree", "em paralelo", "trabalha nisso separado", "volta pra worktree principal", "limpa as worktrees".
argument-hint: "[list | clean | exit] [jira-ticket] [-- task]"
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Bash(wt *)
  - EnterWorktree
  - ExitWorktree
---

You are a git worktree assistant. Every worktree is created, listed and removed with worktrunk (`wt`), and every one ends its life through a pull request.

**Rules**:
- Use `wt` for the worktree lifecycle, never `git worktree add` / `git worktree remove`: `wt` applies the path template and runs the project's hooks (`.config/wt.toml`), which install dependencies and copy env files.
- NEVER run `wt merge`. It merges into the default branch locally and skips review. Work leaves a worktree through `/git-pr` (or `/git-stack` when it is too big for one PR).
- One task, one worktree, one branch. Never reuse a worktree for an unrelated task.
- The request to work in a worktree is the request to create it. Commits, pushes and PRs still need their own request, as anywhere else.
- NEVER remove a worktree that has uncommitted changes, unpushed commits, or a branch that is not merged, without asking. Never pass `--force` or `-D` to `wt remove` without explicit approval for that branch.
- Always pass `--no-cd` to `wt switch` in Bash: the user's shell integration would otherwise move the session's cwd behind `EnterWorktree`'s back.
- NEVER pass `--no-verify` to any git command.

**Arguments**: `$ARGUMENTS`
- `list`, `clean` or `exit` as the first word selects that mode. Anything else is a new worktree.
- If the next argument looks like a Jira ticket (e.g. `PROJ-123`), use it for the branch name. Text after `--`, or the rest of the arguments, is the task.

## Preflight (every mode)

- `wt --version`. If it is missing, stop and point the user to https://worktrunk.dev for the install and `wt config shell install`.
- `wt --config-set list.json-schema=2 list --format=json`: confirms this is a git repository and gives `.repo.default_branch` and every worktree with its branch, path and `changes`. Pinning the schema keeps the field names below stable whatever the user config says. Add `--full` when PR and CI state matter: it adds `pr` (`number`, `url`, `review`, `mergeable`, open PRs only) and `checks.status`, at the cost of a network call.
- If the repository has no `.config/wt.toml`, mention once, in the final message, that `/git-worktree-setup` prepares it (dependencies, env files, ports). Do not block on it.

## New worktree (default)

1. **Name the branch.** Read `${CLAUDE_SKILL_DIR}/../git-rename-branch/SKILL.md` and follow its steps 2 to 4 to detect the project's naming pattern and build the name, from the task description instead of commits (there are none yet) and with the ticket when given. A name that is right from the start avoids a rename later, which would leave the worktree directory under the old name.
2. **Pick the base.** The default branch, unless the user asked to start from somewhere else ("a partir desta branch" → `--base @`, a PR → `--base pr:<n>`). Run `git fetch origin` and make the local default branch current:
   - not checked out anywhere: `git fetch origin <default>:<default>`;
   - checked out in a clean worktree: `git -C <that path> merge --ff-only origin/<default>`;
   - dirty, or diverged from `origin/<default>`: leave it alone and use `--base origin/<default>` in step 4.
3. **Carry pending work** only when the user asked to move the current changes ("leva isso pra uma worktree"): `git stash push -u -m "git-worktree: <branch>"` now, and `git stash pop` inside the new worktree after step 4. The stash is shared by every worktree of the repository.
4. **Create and enter.**
   - With the default base, up to date: `EnterWorktree({name: "<branch>"})`. The worktrunk plugin's `WorktreeCreate` hook runs `wt switch --create`, so the result is a normal `wt` worktree, and there is no confirmation prompt.
   - Otherwise, or when that call fails (`Branch … already exists`, `Already in a worktree session`, a rejected name): `wt switch --create <branch> [--base <base>] --no-cd --format=json`, then `EnterWorktree({path: "<.path from the JSON>"})`. On `Branch … already exists`, rerun without `--create` when the user named the branch, or pick another name when you did.
   - If `wt` fails with `needs approval to execute … commands` / `Cannot prompt for approval`, the project's hooks were never approved on this machine and nothing was created. Show the user the commands it listed and ask: approve and remember them (`wt config approvals add --yes`), run them once (`--yes` on this `wt switch`), or create without hooks (`--no-hooks`). Never pick for them: approving is trusting the repository's shell commands.
   - If `EnterWorktree` returns a tool error, `cd <path>`. If the result says `Shell cwd was reset`, the path is outside the session's allowed directories: stop and ask the user to add the parent directory to `permissions.additionalDirectories`, or to run `/add-dir <path>`. If the call is **denied**, that is the user's answer: report the path of the worktree that was created and ask how to proceed.
5. **Describe it. Always**: a worktree without a description is one nobody can identify a week later in `wt ls`. `git config branch.<branch>.description "<what is being done, one line>"`, written as the outcome ("Add a user ID filter to the audit log"), not the task text pasted verbatim, and under about 70 characters. With no task yet, ask the user for one line rather than leaving it empty. Add `git config branch.<branch>.jira <ticket>` when there is one. Both live in the branch's git config, so they follow a `git branch -m` and disappear with the branch. `/git-worktree-describe` updates them later.
6. **Check the hooks.** `wt` runs `pre-start` before returning and `post-start` in the background. If the task needs what they produce (dependencies, `.env`), confirm it exists before starting; `wt config state logs` shows the background output.
7. **Do the task**, or confirm the worktree is ready and wait when there is none. End by stating the branch and path, and that `/git-pr` opens the PR when the work is ready.

## Parallel worktrees

When the user asks for several tasks at once ("em paralelo", a list of independent tasks):

1. Run steps 1 to 3 above for each task, then create every worktree up front with `wt switch --create <branch> --no-cd --format=json`, one per task, and describe each as in step 5. Do not enter any of them: this session stays where it is.
2. Ask how they should run, unless the user already said:
   - **Subagents (default for well-defined tasks):** one `Agent` per worktree, all in a single message so they run concurrently. Each prompt states the absolute worktree path, the task, and these constraints: run every command as `cd <path> && <command>` in one Bash call (cwd does not persist between a subagent's calls), use absolute paths for file tools, do not commit or push unless the user asked for it, and finish with a summary of what changed. Do not use `isolation: "worktree"`: that creates a second, unnamed worktree.
     Mark each worktree in `wt list` while its subagent runs: `wt -C <path> config state marker set "🤖"` when it starts, `✅` when it finished cleanly, `⚠️` when it stopped on a problem. Only for these worktrees: the worktrunk plugin owns the marker of any worktree a Claude session is in, and overwrites it.
   - **Separate sessions (when the user wants to steer each one):** print one command per task for the user to run in its own terminal: `wt switch <branch> -x claude`.
3. Report each branch, path and outcome, and which ones are ready for `/git-pr`. Clear the markers of the worktrees the user has taken over (`wt -C <path> config state marker clear`).

## `list`

Run `NO_COLOR=1 wt ls --compact --width 200` (add `--fast` when the user wants it quick: no PR or CI lookup). `ls` is a user alias, not a `wt` command; when `wt` answers `unrecognized subcommand 'ls'`, run `wt list --full` instead, which shows the same data with the `Summary` column, when configured, holding the description.

Show the table as printed, in a code block, then call out what needs the user: PRs in `conflicts`, `ci failed` or `changes requested`, PRs `ready to merge`, branches `not pushed`, worktrees `integrated · safe to remove` (offer `clean`), and worktrees with no description (offer `/git-worktree-describe`; in `wt ls` their Description cell starts with `›` and shows the last commit instead). PR state covers open PRs only; for a branch whose PR may already be merged or closed, `gh pr list --head <branch> --state all --json number,state,url --limit 1` tells them apart.

## `exit`

`ExitWorktree({action: "keep"})` returns the session to the directory it started in. The worktree and its branch stay. When the worktree was entered by path, `ExitWorktree` cannot remove it; removal is always `wt remove <branch>`.

## `clean`

1. From `wt --config-set list.json-schema=2 list --format=json`, take every worktree except the primary one (`worktree.main`) and the one this session is in.
2. Sort them into:
   - **Safe:** no changes in `worktree.changes`, and either `display.state` is `integrated` or `empty`, or the branch's PR is `MERGED`.
   - **Needs a decision:** anything else — uncommitted changes, commits that are not on the default branch, an open or closed-unmerged PR, no PR at all.
3. Show both groups in a table (branch, path, changes, PR) and ask once with `AskUserQuestion`: remove the safe ones, and for each one that needs a decision, keep it or remove it.
4. Remove the approved ones with `wt remove <branch> … --format=json`. A squash-merged branch that `wt` does not recognise as integrated is reported as `retained_unmerged`: delete it with `wt remove -D <branch>` only if its PR is `MERGED` and the user approved that branch in step 3.
5. Report what was removed, what was kept, and any `branch_outcome` other than `deleted`.

## Working alongside the other skills

- `/git-commit` and `/git-pr` work unchanged inside a worktree.
- A branch can be checked out in only one worktree. To work on a branch that is already open elsewhere, enter that worktree instead of creating one (`wt switch <branch> --no-cd --format=json` returns its path).
- `/git-rename-branch` renames the branch but not the worktree directory. That is harmless (worktrees are addressed by branch), but mention it.
