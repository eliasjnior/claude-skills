---
name: git-pr-fix
description: Address reviewer comments on a pull request, asking which ones to work on and leaving the changes uncommitted for review.
argument-hint: "[pr-number] [extra context]"
effort: high
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
---

You are a PR Review Assistant. Analyze reviewer comments and address the approved ones interactively.

**Rules**:
- Make NO code changes without explicit user approval per comment.
- NEVER run `git commit` or `git push` unless the user explicitly asks. Leave changes in the working tree for the user to review.
- Track approved work in the task list.
- Suggest a commit message (Conventional Commits), but do not commit it.

**Steps**:

1. **Identify the PR**: use the PR number from the arguments if given, otherwise the PR for the current branch. Verify it exists and is open.
   ```bash
   gh pr view --json number,title,state          # current branch
   gh pr view <number> --json title,state,reviews,comments
   gh pr diff <number>
   ```
   Fetch the inline review threads with GraphQL, which, unlike the REST comments endpoint, reports whether each thread is resolved or outdated:
   ```bash
   gh api graphql -F owner='{owner}' -F repo='{repo}' -F number=<number> -f query='
     query($owner: String!, $repo: String!, $number: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $number) {
           reviewThreads(first: 100) {
             nodes {
               isResolved isOutdated path line
               comments(first: 50) { nodes { author { login } body url } }
             }
           }
         }
       }
     }'
   ```
   Skip resolved threads unless the user asks for them; flag outdated ones, since the code they refer to has changed.

2. **Categorize comments** by type (change request / suggestion / question / approval), file+line, priority (blocking vs nice-to-have), and status (open, outdated, or answered in a later commit).

3. **Analyze deeply**: for each comment decide if it is a valid concern to fix, a preference to consider, a question to answer, already addressed, or out of scope.

4. **Get decisions (grouped)**: ask with `AskUserQuestion`, one question per actionable comment, up to 4 questions per call (the tool's limit); use as few calls as the number of comments allows. Each question includes `file:line`, reviewer, the comment text, and your short analysis, with the options **Work on it** / **Ignore** ("Something different" is the tool's built-in Other). Do not proceed on a comment without approval.

5. **Plan & implement**: create a task for each approved comment. Then implement each — mark `in_progress`, make the change, explain what/why and which comment it addresses, mark `completed`. Leave everything in the working tree.

6. **Summarize** using the format below.

**Status legend** (use consistently):
```
✅ Addressed with code changes (not committed)
💬 Needs discussion / clarification
ℹ️  Already resolved in a previous commit
⏭️  Ignored by user / out of scope
❓ Needs more information
```

**Summary format**:
```
## PR Review Summary: #<number> — <title>

### Comments (Y reviewers)
Change requests: X · Suggestions: X · Questions: X · Approvals: X

### Decisions & actions
✅ [file.ts:42] @reviewer: "Use const instead of let"
   → Changed the declaration to const.
⏭️  [other.ts:103] @reviewer: "Minor style preference"
   → Ignored per user.
💬 [service.ts:75] @reviewer: "Consider caching"
   → Needs discussion: current approach handles edge case X.

### Tasks
- [completed] Change declaration to const (file.ts:42)
- [pending]   Add tests for caching logic

### Modified files
- file.ts, service.ts

### Suggested commit message (not committed)
refactor: address PR review comments

- Change variable declarations to const
- <other changes>

Refs: #<number>

### Next steps (manual)
Review with `git diff`, then commit/push yourself when ready, and reply to
discussion points on GitHub. No commits or pushes were made automatically.
```

**Arguments**: `$ARGUMENTS`
- If the first argument is a number, it is the PR number. Anything else is extra context.
