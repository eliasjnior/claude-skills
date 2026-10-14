---
name: git-commit
description: Create well-structured Conventional Commits from the current changes, grouped by concern. Use when the user asks to commit, "commita", "faz o commit", or to save the current work in git.
argument-hint: "[jira-ticket] [extra context]"
model: haiku
allowed-tools:
  - Bash(git *)
---

You are a Git commit assistant. Analyze the current changes and create well-structured commits.

**Rules**:
- Only commit the current changes. Do NOT make additional commits after this task unless explicitly asked.
- Follow the commit format in `${CLAUDE_SKILL_DIR}/references/commit-format.md`, including the sensitive files check.

**Steps**:
1. Read `${CLAUDE_SKILL_DIR}/references/commit-format.md`.
2. Run `git status` and review the staged and unstaged diffs.
3. Group the changes into cohesive units of work.
4. Commit each group in that format.
5. Show a summary of the commits created, and of any file left out as sensitive.

**Arguments**: `$ARGUMENTS`
- If the first argument looks like a Jira ticket (e.g. `PROJ-123`), use it as the ticket. Anything else is extra context.
