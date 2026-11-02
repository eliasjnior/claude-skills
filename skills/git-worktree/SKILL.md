---
name: git-worktree
description: Work in a separate git worktree — create one for a task and move this session into it, run several tasks in parallel worktrees, list them, leave one, or clean up the ones whose PR was merged. Use when the user asks to work in a worktree, in parallel, or on a separate branch without touching the current checkout, or says "abre uma worktree", "numa worktree", "em outra worktree", "em paralelo", "trabalha nisso separado", "volta pra worktree principal", "limpa as worktrees".
argument-hint: "[list | clean | exit] [jira-ticket] [-- task]"
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Bash(wt *)
  - Bash(*/scripts/worktree-setup.sh)
  - EnterWorktree
  - ExitWorktree
---

You are a git worktree assistant. Every worktree is created, listed and removed with `git worktree`, and every one ends its life through a pull request.

**Rules**:
- The tool is `git worktree`, unless the project uses a manager (see **Project with a worktree manager**).
- Work leaves a worktree through `/git-pr` (or `/git-stack` when it is too big for one PR), never through a local merge into the default branch.
- One task, one worktree, one branch. Never reuse a worktree for an unrelated task.
- The request to work in a worktree is the request to create it. Commits, pushes and PRs still need their own request, as anywhere else.
- NEVER remove a worktree that has uncommitted changes, unpushed commits, or a branch that is not merged, without asking. Never pass `--force` to `git worktree remove` or use `git branch -D` without explicit approval for that branch.
- NEVER pass `--no-verify` to any git command.

**Arguments**: `$ARGUMENTS`
- `list`, `clean` or `exit` as the first word selects that mode. Anything else is a new worktree.
- If the next argument looks like a Jira ticket (e.g. `PROJ-123`), use it for the branch name. Text after `--`, or the rest of the arguments, is the task.

## Preflight (every mode)

- `git worktree list --porcelain`: confirms this is a git repository and gives every worktree with its path and branch. The first entry is the primary worktree.
- The default branch: `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` prefix, or `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` when that fails.
- If the repository has no `scripts/worktree-setup.sh` and no worktree manager, mention once, in the final message, that `/git-worktree-setup` prepares it (dependencies, env files, ports). Do not block on it.

## Project with a worktree manager

A project can already use a tool on top of git worktrees: `.config/wt.toml` means worktrunk (`wt`), and the project's `CLAUDE.md` may name another. Its hooks only run through it, so when the tool is installed, use its commands for creating and removing, and skip step 6 of **New worktree**. The steps around them stay the same.

For worktrunk: `wt switch --create <branch> [--base <base>] --no-cd --format=json` creates (`.path` in the JSON), `wt remove <branch>` removes. If it fails with `needs approval to execute … commands`, nothing was created: show the user the commands and ask whether to approve them (`wt config approvals add --yes`), run them once (`--yes`), or create without hooks (`--no-hooks`).

When the tool is not installed, use `git worktree` and tell the user that the project's hooks did not run.

## New worktree (default)

1. **Name the branch.** Read `${CLAUDE_SKILL_DIR}/../git-rename-branch/SKILL.md` and follow its steps 2 to 4 to detect the project's naming pattern and build the name, from the task description instead of commits (there are none yet) and with the ticket when given. A name that is right from the start avoids a rename later, which would leave the worktree directory under the old name.
2. **Pick the base.** The default branch, unless the user asked to start from somewhere else ("a partir desta branch" → `HEAD`; a PR → `git fetch origin <its headRefName>`, then `origin/<its headRefName>`). Run `git fetch origin` and make the local default branch current:
   - not checked out anywhere: `git fetch origin <default>:<default>`;
   - checked out in a clean worktree: `git -C <that path> merge --ff-only origin/<default>`;
   - dirty, or diverged from `origin/<default>`: leave it alone and use `origin/<default>` as the base in step 4.
3. **Carry pending work** only when the user asked to move the current changes ("leva isso pra uma worktree"): `git stash push -u -m "git-worktree: <branch>"` now, and `git stash pop` inside the new worktree after step 4. The stash is shared by every worktree of the repository.
4. **Create.** The path is `<parent of the primary worktree>/<repo>.<branch with each / replaced by ->`, unless the project's `CLAUDE.md` sets another location.
   - `git worktree add -b <branch> <path> <base>`.
   - On `a branch named … already exists`: `git worktree add <path> <branch>` when the user named the branch, or pick another name when you did.
   - On `… is already used by worktree at <other path>`: enter that worktree instead of creating one.
5. **Enter.** `EnterWorktree({path: "<path>"})`.
   - If `EnterWorktree` returns a tool error, `cd <path>`. If the result says `Shell cwd was reset`, the path is outside the session's allowed directories: stop and ask the user to add the parent directory to `permissions.additionalDirectories`, or to run `/add-dir <path>`. If the call is **denied**, that is the user's answer: report the path of the worktree that was created and ask how to proceed.
6. **Prepare it.** If `<path>/scripts/worktree-setup.sh` exists, read it and run it: it is what installs dependencies and copies env files. If it does more than prepare the worktree (a `curl | sh`, `sudo`, anything outside the repository), show the user and ask first. Without the script, a fresh worktree has no dependencies and no gitignored files: if the task needs them, say so and run the install the lockfile calls for.
7. **Describe it. Always**: a worktree without a description is one nobody can identify a week later. `git config branch.<branch>.description "<what is being done, one line>"`, written as the outcome ("Add a user ID filter to the audit log"), not the task text pasted verbatim, and under about 70 characters. With no task yet, ask the user for one line rather than leaving it empty. Add `git config branch.<branch>.jira <ticket>` when there is one. Both live in the branch's git config, so they follow a `git branch -m` and disappear with the branch. `/git-worktree-describe` updates them later.
8. **Do the task**, or confirm the worktree is ready and wait when there is none. End by stating the branch and path, and that `/git-pr` opens the PR when the work is ready.

## Parallel worktrees

When the user asks for several tasks at once ("em paralelo", a list of independent tasks):

1. Run steps 1 to 4 above for each task, creating every worktree up front, then steps 6 and 7 for each one. Do not enter any of them: this session stays where it is.
2. Ask how they should run, unless the user already said:
   - **Subagents (default for well-defined tasks):** one `Agent` per worktree, all in a single message so they run concurrently. Each prompt states the absolute worktree path, the task, and these constraints: run every command as `cd <path> && <command>` in one Bash call (cwd does not persist between a subagent's calls), use absolute paths for file tools, do not commit or push unless the user asked for it, and finish with a summary of what changed. Do not use `isolation: "worktree"`: that creates a second, unnamed worktree.
   - **Separate sessions (when the user wants to steer each one):** print one command per task for the user to run in its own terminal: `cd <path> && claude`.
3. Report each branch, path and outcome, and which ones are ready for `/git-pr`.

## `list`

Build one table from these, with a row per worktree (branch, description, changes, ahead/behind the default branch, PR, path):

- `git worktree list --porcelain` for the paths and branches;
- `git config --get branch.<branch>.description` and `branch.<branch>.jira`;
- `git -C <path> status --short` for the changes, and `git rev-list --left-right --count <default>...<branch>` for behind and ahead;
- `gh pr list --state all --limit 100 --json headRefName,number,state,url,reviewDecision,mergeable,statusCheckRollup` for the PRs. Skip it when the user wants it quick.

Then call out what needs the user: PRs in conflict, with failed checks or changes requested, PRs ready to merge, branches not pushed, worktrees whose PR was merged (offer `clean`), and worktrees with no description (offer `/git-worktree-describe`).

## `exit`

`ExitWorktree({action: "keep"})` returns the session to the directory it started in. The worktree and its branch stay. When the worktree was entered by path, `ExitWorktree` cannot remove it; removal is the `clean` mode's job.

## `clean`

1. From `git worktree list --porcelain`, take every worktree except the primary one and the one this session is in. `git fetch --prune origin` first, and look up each branch with `gh pr list --head <branch> --state all --json number,state,url,headRefOid --limit 1`.
2. Sort them into:
   - **Safe:** `git -C <path> status --short` is empty, and either the branch is contained in the default branch (`git merge-base --is-ancestor <branch> origin/<default>`), or its PR is `MERGED` and `headRefOid` equals the branch's tip. A squash merge is only recognised by the PR, and a different tip means commits made after the merge.
   - **Needs a decision:** anything else — uncommitted changes, commits that are not on the default branch, an open or closed-unmerged PR, no PR at all.
3. Show both groups in a table (branch, path, changes, PR) and ask once with `AskUserQuestion`: remove the safe ones, and for each one that needs a decision, keep it or remove it.
4. Remove the approved ones with `git worktree remove <path>`, then `git branch -d <branch>`. A squash-merged branch is refused by `-d`: delete it with `git branch -D <branch>` only if its PR is `MERGED` and the user approved that branch in step 3. `git worktree remove` refuses a worktree with changes; use `--force` only when the user approved removing that one with its changes in step 3.
5. Run `git worktree prune`, then report what was removed, what was kept, and any branch that could not be deleted.

## Working alongside the other skills

- `/git-commit` and `/git-pr` work unchanged inside a worktree.
- A branch can be checked out in only one worktree. To work on a branch that is already open elsewhere, enter that worktree instead of creating one (`git worktree list` has its path).
- `/git-rename-branch` renames the branch but not the worktree directory. That is harmless, since `git worktree list` shows which branch each directory holds, but mention it.
