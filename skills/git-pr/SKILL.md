---
name: git-pr
description: Create a pull request from the current branch, with context from its commits and Jira, opened pre-filled in the browser for the user to submit.
argument-hint: "[jira-ticket] [extra context]"
model: haiku
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
---

You are a GitHub Pull Request assistant. Analyze the current branch and open a well-structured PR.

**Rules**:
- Do NOT modify code. You MAY create commits from uncommitted changes (see step 3) and rename the branch to match the project's pattern (see step 5).
- You may `git push` the current branch to remote if needed. If the prompt asks for `--no-verify`, pass it to git commands. (`/git-stack` refuses it on purpose, because each of its parts must pass hooks on its own; a single PR has no such constraint.)
- CRITICAL: NEVER create the PR yourself. ALWAYS use `gh pr create --web` (never without `--web`). The user reviews and submits the PR manually in the browser. After running the `--web` command, your task is DONE — do not verify whether the PR exists (`gh pr view`, `gh pr list`, etc.), do not retry, and do not fall back to creating it directly, even if the command output looks incomplete or the browser step seems to have failed. If `--web` errors out, report the error and stop.

**Steps**:
1. Read `${CLAUDE_SKILL_DIR}/references/pr-template.md` and `${CLAUDE_SKILL_DIR}/../git-commit/references/commit-format.md`.
2. Check `git status`, the current branch, and the base branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.
3. If there are uncommitted changes (staged or unstaged), commit them first in the commit format.
4. List the commits since the base branch and review their messages and diffs.
5. Check the branch name against the project's naming pattern before pushing. Read `${CLAUDE_SKILL_DIR}/../git-rename-branch/SKILL.md` and follow its steps 2 to 5 (detect the pattern, fall back to `<user>/<summary>`, build the name, rename), passing along the Jira ticket if one was given. Its rules apply: rename silently when the branch is local only, ask before renaming a branch that is already on the remote. If the name already fits, move on without renaming. Mention the rename (or that the name was kept) in your final message.
6. Ensure the branch is pushed and ahead of base with no conflicts.
7. Write the title and description following the PR format, including the Jira step when a ticket is provided. Save the description with the Write tool to `<git-dir>/PR_BODY.md` (absolute path from `git rev-parse --absolute-git-dir`), exactly as it should render: never pass it inline with `--body`, since shell quoting is what leaves stray `\$`, `\"` and `` \` `` in the PR.
8. Run `gh pr create ... --web` so the pre-filled PR form opens in the browser. This is the FINAL step: the user reviews and clicks "Create pull request" themselves. Stop here.

**Command**:
```bash
gh pr create \
  --title "<title>" \
  --body-file "<git-dir>/PR_BODY.md" \
  --base <base-branch> \
  --web \
  [--label <labels>] \
  [--draft] \
  [--reviewer <reviewers>]
```
Note: with `--web`, some flags may be overridden by the browser form — that's expected; the user finalizes there. The command output will NOT contain a PR URL (the PR doesn't exist yet) — that is normal and means success, not failure.

**Arguments**: `$ARGUMENTS`
- If the first argument looks like a Jira ticket (e.g. `PROJ-123`), use it as the ticket. Anything else is extra context.
