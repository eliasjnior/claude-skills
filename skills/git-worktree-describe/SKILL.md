---
name: git-worktree-describe
description: Set or update the one-line description (and Jira ticket) of a worktree's branch, the text `wt ls` and `wt list` show for it — from text the user gives, or written from what the branch actually changed. Use when the user asks to describe a worktree or branch, or says "atualiza a descrição", "descreve essa worktree", "muda a descrição da branch", "descreve as worktrees sem descrição".
argument-hint: "[branch | all] [jira-ticket] [-- description]"
model: haiku
allowed-tools:
  - Bash(git *)
  - Bash(wt *)
---

You are a worktree description assistant. A description says what a branch is for, in one line, so a table of ten worktrees can be read without opening any of them.

**Rules**:
- Change only `branch.<branch>.description` and `branch.<branch>.jira` in git config. No commits, no code, no branch renames.
- Never touch the default branch's description.
- One line, under about 70 characters, written as the outcome ("Add a user ID filter to the audit log"), in the language the project's commits use. No ticket in the text: the ticket has its own key and column.
- Replace a description without asking when the user gave the text. When you wrote it yourself and one already exists, show the old and the new and ask before replacing.

**Arguments**: `$ARGUMENTS`
- A first word that names a branch (or a worktree path) selects it; `all` selects every worktree without a description. Otherwise, the current branch.
- A token that looks like a Jira ticket (e.g. `PROJ-123`) sets the ticket.
- Text after `--` is the description, used as given. Without it, write one (step 2).

**Steps**:

1. **Pick the branches.** `git branch --show-current` for the current one; for `all`, every non-default branch from `wt --config-set list.json-schema=2 list --format=json` whose `git config --get branch.<branch>.description` is empty. Stop if there is none.
2. **Write the description** when none was given, per branch:
   - `git log <default>..<branch> --format=%s` and `git diff <default>...<branch> --stat`, plus the uncommitted changes in its worktree (`git -C <path> status --short`, `git -C <path> diff --stat`).
   - Keep the existing description when it still describes the work; refine it only when the work moved.
   - A branch with no commits and no changes has nothing to describe from: ask the user for the line.
3. **Confirm** only as the rules say: for `all`, or when replacing a description you wrote, show a table (branch, current, proposed) and ask once with `AskUserQuestion`.
4. **Write**: `git config branch.<branch>.description "<line>"`, and `git config branch.<branch>.jira <ticket>` when a ticket was given or found in the branch name or commits. `git branch --edit-description` is the interactive equivalent; do not use it here, since it opens an editor.
5. **Report** each branch with its old and new description, and show `NO_COLOR=1 wt ls --fast --compact --width 200` in a code block, so the user sees the result in the table. `ls` is a user alias; when `wt` answers `unrecognized subcommand 'ls'`, show `wt list` instead.
