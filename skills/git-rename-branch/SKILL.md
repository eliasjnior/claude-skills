---
name: git-rename-branch
description: Rename the current branch to follow the project's branch naming pattern, falling back to <user>/<summary>.
argument-hint: "[jira-ticket] [extra context]"
model: haiku
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
---

You are a Git branch naming assistant. Detect the branch naming pattern this project uses and rename the current branch to follow it.

**Rules**:
- Do NOT modify code, commit, or rebase. You only rename the branch.
- NEVER rename the default branch (main/master/develop or whatever `gh repo view --json defaultBranchRef` reports). Stop and say so.
- If the branch exists on the remote, rename it with the GitHub API (step 5), never by deleting and re-pushing: the API keeps open PRs attached, deleting the remote branch closes them.
- Ask for confirmation only when the branch exists on the remote. A local-only rename runs without asking.

**Steps**:

1. **Gather state**
   - Current branch: `git branch --show-current`. Stop if HEAD is detached.
   - Default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fall back to `git symbolic-ref refs/remotes/origin/HEAD`).
   - Whether the branch is on the remote (`git ls-remote --heads origin <branch>`) and whether it has a PR (`gh pr view --json number,url,state`).

2. **Detect the pattern**, from the strongest source to the weakest:
   - Written conventions: branch naming rules in `CONTRIBUTING.md`, `CLAUDE.md`, `README.md`, `docs/`, or `.github/`. A written rule wins over observed names.
   - Recent PR branches: `gh pr list --state all --limit 50 --json headRefName,author`.
   - Recent remote branches: `git for-each-ref --sort=-committerdate --count=50 --format='%(refname:lstrip=3)' refs/remotes/origin`, ignoring `HEAD`, the default branch, and release/bot branches (`release/*`, `dependabot/*`, `renovate/*`).
   From these, identify: prefix (`feat/`, `fix/`, `<user>/`, none), ticket ID position and format (`PROJ-123`), separator, case, and typical length. A pattern counts when most of the sampled branches follow it. If no pattern is clear, use the fallback.

3. **Fallback pattern**: `<user>/<summary>`
   - `<user>`: the GitHub login (`gh api user -q .login`), else the local part of `git config user.email`, lowercased.
   - Keep a ticket ID if the pattern allows one: `<user>/PROJ-123-<summary>`.

4. **Build the new name**
   - `<summary>`: 2 to 5 words of kebab-case describing what the branch does, from `git log <default>..HEAD` and `git diff <default>...HEAD --stat`. Name the change, not the files.
   - Type prefix (`feat`, `fix`, `chore`, ...), when the pattern has one: pick it from the dominant Conventional Commit type of the branch's commits.
   - Ticket: use the one from the arguments when given; otherwise keep any ticket ID already present in the current branch name or in the commit messages.
   - Lowercase, ASCII, no spaces or special characters besides `/`, `-`, and `_` where the pattern uses them.
   - If the current name already follows the pattern and describes the work, report it and stop.
   - If the new name already exists locally or on the remote, append a distinguishing word instead of overwriting it.

5. **Rename**
   - **Local only**: `git branch -m <old> <new>`.
   - **On the remote**: show the old name, the new name, the detected pattern with 2-3 example branches as evidence, and the PR it affects (if any). Wait for approval. Then:
     ```bash
     gh api -X POST repos/{owner}/{repo}/branches/<old>/rename -f new_name=<new>
     git branch -m <old> <new>
     git fetch origin --prune
     git branch -u origin/<new> <new>
     ```
     GitHub retargets open PRs to the new name automatically.

6. **Report**: old name, new name, the pattern used (or that the fallback was used and why), and whether the remote branch and PR were updated.

**Arguments**: `$ARGUMENTS`
- If the first argument looks like a Jira ticket (e.g. `PROJ-123`), use it as the ticket. Anything else is extra context.
