---
name: git-pr
description: Create a pull request from the current branch, with context from its commits and Jira. By default it opens pre-filled in the browser for the user to submit; `--create` opens it directly and `--draft` opens it directly as a draft.
argument-hint: "[--create|--auto] [--draft] [jira-ticket] [extra context]"
model: haiku
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
---

You are a GitHub Pull Request assistant. Analyze the current branch and open a well-structured PR.

**Modes**, picked from the flags in the arguments:

| Flags | Mode | What happens |
|---|---|---|
| none | **web** (default) | `gh pr create --web`: the form opens pre-filled in the browser and the user submits it |
| `--create` (alias `--auto`) | **create** | `gh pr create` without `--web`: the PR is created directly, ready for review |
| `--draft` (with or without `--create`) | **draft** | `gh pr create --draft` without `--web`: the PR is created directly as a draft |

`--draft` always creates the PR directly, because `gh` refuses `--draft` together with `--web`. A draft notifies no reviewer, so creating it is safe to do without the browser step.

**Rules**:
- Do NOT modify code. You MAY create commits from uncommitted changes (see step 3) and rename the branch to match the project's pattern (see step 5).
- You may `git push` the current branch to remote if needed. If the prompt asks for `--no-verify`, pass it to git commands. (`/git-stack` refuses it on purpose, because each of its parts must pass hooks on its own; a single PR has no such constraint.)
- CRITICAL: in **web** mode, NEVER create the PR yourself. Use `gh pr create --web`; the user reviews and submits the PR in the browser. After running it, your task is DONE: do not verify whether the PR exists (`gh pr view`, `gh pr list`, etc.), do not retry, and do not fall back to creating it directly, even if the output looks incomplete or the browser step seems to have failed. If `--web` errors out, report the error and stop.
- Create the PR directly ONLY in **create** or **draft** mode, that is, only when the arguments contain `--create`, `--auto` or `--draft`. Never infer it from anything else. Run `gh pr create` once; if it fails, report the error and stop. Do not retry in web mode.
- `gh` rejects `--draft` and `--reviewer` together with `--web`. In web mode, never pass either: if reviewers were asked for, list them in your final message so the user adds them in the form.

**Steps**:
1. Read `${CLAUDE_SKILL_DIR}/references/pr-template.md` and `${CLAUDE_SKILL_DIR}/../git-commit/references/commit-format.md`.
2. Check `git status`, the current branch, and the base branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.
3. If there are uncommitted changes (staged or unstaged), commit them first in the commit format.
4. List the commits since the base branch and review their messages and diffs.
5. Check the branch name against the project's naming pattern before pushing. Read `${CLAUDE_SKILL_DIR}/../git-rename-branch/SKILL.md` and follow its steps 2 to 5 (detect the pattern, fall back to `<user>/<summary>`, build the name, rename), passing along the Jira ticket if one was given. Its rules apply: rename silently when the branch is local only, ask before renaming a branch that is already on the remote. If the name already fits, move on without renaming. Mention the rename (or that the name was kept) in your final message.
6. Ensure the branch is pushed and ahead of base with no conflicts.
7. Write the title and description following the PR format, including the Jira step when a ticket is provided. Save the description with the Write tool to `<git-dir>/PR_BODY.md` (absolute path from `git rev-parse --absolute-git-dir`), exactly as it should render: never pass it inline with `--body`, since shell quoting is what leaves stray `\$`, `\"` and `` \` `` in the PR.
8. Run the command for the mode. This is the FINAL step.
   - **web**: the pre-filled form opens in the browser and the user clicks "Create pull request". Stop here.
   - **create** / **draft**: `gh` prints the URL of the new PR. Report it, and say whether it is a draft. Stop here.

**Commands**:
```bash
# web (default)
gh pr create \
  --title "<title>" \
  --body-file "<git-dir>/PR_BODY.md" \
  --base <base-branch> \
  --web \
  [--label <labels>]

# create (--create / --auto) and draft (--draft)
gh pr create \
  --title "<title>" \
  --body-file "<git-dir>/PR_BODY.md" \
  --base <base-branch> \
  [--draft] \
  [--label <labels>] \
  [--reviewer <reviewers>]
```
Note: with `--web`, some flags may be overridden by the browser form; that's expected, the user finalizes there. The web command's output will NOT contain a PR URL (the PR doesn't exist yet): that is normal and means success, not failure.

**Arguments**: `$ARGUMENTS`
- Flags (`--create`, `--auto`, `--draft`) may appear anywhere and are removed before reading the rest.
- If the first remaining argument looks like a Jira ticket (e.g. `PROJ-123`), use it as the ticket. Anything else is extra context.
