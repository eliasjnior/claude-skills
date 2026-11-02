---
name: report
description: Build my daily or weekly work report for the current repository from my merged PRs, my open PRs and the work sitting in my worktrees, as one Markdown list grouped into Merged, In review and In progress. Use when the user asks for a work report, standup or status update, or says "relatório diário", "relatório semanal", "report daily", "report weekly", "o que eu fiz ontem", "o que eu fiz essa semana", "prepara minha daily".
argument-hint: "daily | weekly [--current] [reviews] [-- other work done]"
model: sonnet
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Bash(wt *)
  - Bash(date *)
  - Bash(stat *)
  - Bash(command -v *)
---

You are preparing my work report for the current repository. Read only: no commits, no pushes, no edits to PRs or branches.

**Arguments**: `$ARGUMENTS`
- `daily` or `weekly` sets PERIOD. With neither, use `daily`.
- `--current` reports the current day or week, until now. Without it, the previous one, already closed.
- `reviews` also includes PRs by other people where I am a reviewer. Without it, only my own work.
- Anything else, usually after `--`, is work I did outside PRs (meetings, investigations, support, pairing, planning), in any language and any shape. See "Other work" below.

## 1. Period

Use my local timezone (`date +%Z`, `date +%u` for the weekday). Every period has a `<start>` and an `<end>`. State the exact range at the top of the report.

| PERIOD | Default (previous) | `--current` |
|---|---|---|
| `daily` | the previous business day, 00:00 to 23:59. On Monday, Saturday or Sunday, that is Friday | today, 00:00 until now |
| `weekly` | the previous week, Monday 00:00 to Sunday 23:59 | this week, Monday 00:00 until now |

Keep `<start>` and `<end>` both as dates (`YYYY-MM-DD`, for `gh` search) and as full timestamps (for `git log --since/--until` and for filtering the JSON timestamps, which are UTC). Every item must have activity between `<start>` and `<end>`; activity after `<end>` does not count.

## 2. Sources

Collect from all four. Do not skip any.

First, who I am: `gh api user --jq .login` for my login, plus `git config user.name` and `git config user.email`. A commit is mine when its author matches any of them.

1. **Merged PRs**
   - `gh pr list --author "@me" --state merged --search "merged:<start-date>..<end-date>" --limit 100 --json number,title,url,mergedAt,headRefName`
   - Keep only those whose `mergedAt` is inside the period in my timezone.
2. **Open PRs**, drafts included, that I authored
   - `gh pr list --author "@me" --state open --limit 100 --json number,title,url,isDraft,updatedAt,createdAt,headRefName,reviewDecision`
   - Keep only PRs created or updated inside the period. `updatedAt` only holds the latest activity, so for a previous period also accept a PR whose branch has my commits in the period (`git log origin/<headRefName> --author=... --since=<start> --until=<end>`).
3. **Worktrees**
   - `git worktree list --porcelain` for every worktree. If `command -v wt` finds Worktrunk, also read `wt list`.
   - For each worktree (run every command with `git -C <path>`):
     - `git log <branch> --author="$(git config user.name)" --since="<start>" --until="<end>" --oneline`
     - `git status --short` for uncommitted changes
     - unpushed commits: `git log @{upstream}..HEAD --oneline`, or `git log origin/main..HEAD --oneline` (the repository's default branch) when there is no upstream
   - A worktree whose branch matches the `headRefName` of a PR from sources 1 or 2 is attached to that PR. Never list it twice.
   - A worktree with no PR of mine: run `gh pr list --head <branch> --state all --json number,title,url,author,state,isDraft,mergedAt,reviewDecision,headRefName`. A PR by someone else there makes it a contribution (source 4), attached to that PR.
   - A worktree with no PR at all is work in progress.
   - Skip worktrees with no commits in the period and no uncommitted changes from the period. Uncommitted changes count for a previous period only when the changed files were modified inside it (`stat -f '%Sm' -t '%Y-%m-%d %H:%M' <file>`); with `--current`, any uncommitted change counts.
   - Skip the primary checkout when it sits on the default branch with no changes.
4. **Contributions to other people's PRs**, to cover commits pushed from elsewhere or from a worktree already removed
   - `gh pr list --search "-author:@me updated:<start-date>..<end-date>" --state all --limit 100 --json number,title,url,author,state,isDraft,mergedAt,reviewDecision,headRefName`
   - For each, `gh pr view <n> --json commits` and keep the PR only when at least one commit is mine and its `authoredDate` is inside the period. Run these lookups in parallel when there are many.
   - Merge with the contributions found through the worktrees in source 3, one item per PR.

With `reviews`, also run `gh pr list --search "reviewed-by:@me -author:@me updated:<start-date>..<end-date>" --state all --limit 100 --json number,title,url,author,state` and list those under a separate **Reviewed** heading. A PR already listed as a contribution is not repeated there.

## 3. Understanding each item

- For each PR, mine or a contribution, read `gh pr view <n> --json title,body,headRefName` and `gh pr diff <n> --name-only` to understand what changed and why.
- Take the Jira key from the branch name or the PR title (pattern `[A-Z][A-Z0-9]+-\d+`, e.g. `PROJ-1234`, `WEB-42`), uppercase, and keep it in the item. No key found: no prefix.
- For worktree-only work, read the commits and the diff (`git -C <path> diff --stat`, `git -C <path> diff`, `git -C <path> log -p origin/main..HEAD`) to describe what is being built.
- For a contribution, describe my part (from my commits: `gh pr view <n> --json commits` and `git show <sha> --stat`), not the whole PR.
- Describe the user-facing or technical outcome. Do not repeat the commit message.
- Describe what happened **in the period**, not the PR as a whole. When a PR's only activity in the period was a state change, with no commits of mine (marked ready for review, converted to draft, approved, changes requested, reopened), the item says that, e.g. `: marked ready for review.` Find it with `gh api repos/{owner}/{repo}/issues/<n>/timeline --paginate --jq '.[] | select(.created_at >= "<start-utc>" and .created_at <= "<end-utc>") | .event'`.

## Other work

When the arguments carry other work, for any report (`daily` or `weekly`, with or without `--current`):
- Split it into separate pieces of work and summarize each as one item, in English, under an **Other** heading after **In progress**.
- Keep only what I wrote: no invented detail, outcome or ticket. A Jira key I mention stays in the item as `[KEY]`.
- A note about a PR or worktree already in the report goes into that item instead of becoming a second one, still within the one-line limit.
- Drop filler ("normal stuff", "a few things") that says nothing a reader can use.

## 4. Output format

Return one Markdown list and nothing else: no intro, no closing remarks, no notes about what was empty, skipped or left out.

Keep it terse. Every item is **one line**: a title and at most one short clause after the colon (about 15 words), the kind of line someone reads aloud at a standup. No second sentence, no implementation details (query keys, endpoints, row counts, request counts), no testing notes, no stack relationships. Those live in the PR.

- First line: the range, e.g. `**Daily report, Fri 2026-10-30 00:00 to 23:59 (BRT)**` or, with `--current`, `**Daily report, Mon 2026-11-02 00:00 to 14:10 (BRT)**`.
- Group items under the headings **Merged**, **In review**, **In progress**, **Other** (from the arguments) and **Reviewed** (with `reviews`), in that order.
- One list item per piece of work, in plain English. Stacked PRs for the same ticket may share one item when they deliver one outcome; otherwise one item each.
- Items with a PR embed the link in the text, never a bare URL:
  `- [PROJ-1234] [Add filters to the orders table](https://github.com/org/repo/pull/101): filter orders by status and date.`
- Items without a PR (worktree only) have no link. Add the branch and its state, e.g. `(branch proj-1240-foo, uncommitted)`, `(branch proj-1240-foo, unpushed)` or `(branch proj-1240-foo, pushed, no PR)`.
- Contributions to other people's PRs go in the section that matches the PR's state: **Merged** when merged inside the period, **In review** when open (or merged after `<end>`), **In progress** with `(closed, not merged)` when closed without merging. Mark them `(contributed to @<author>'s PR)`.
- In **In review**, mark drafts with `(draft)` and PRs whose `reviewDecision` is `CHANGES_REQUESTED` with `(changes requested)`.
- Order by importance, then by date.
- Example of the expected length:
  ```
  **Daily report, Fri 2026-10-30 00:00 to 23:59 (-03)**

  **In review**
  - [PROJ-1250] [Fix the reports page hanging on large accounts](https://github.com/org/repo/pull/102) (draft): page no longer freezes on accounts with ~10k rows.
  - [PROJ-1250] [Load report rows from the summary endpoint](https://github.com/org/repo/pull/103) (draft): one request instead of paging through every row.

  **Other**
  - Investigated the slow data sync with the backend team.
  - Sprint planning.
  ```
- Omit empty headings.
- For `weekly`, end with a one-line **Next** list of what continues in the following week, taken from the open PRs (contributions included) and the worktrees still in progress.

## Rules

- Report only what the data shows. Do not invent work and do not guess when a diff is unclear: write "unclear" instead.
- Do not include other people's PRs, except the ones with my commits in the period (always) and the ones I reviewed (only with `reviews`).
- Leave out chores with no value to the reader (merge commits, lockfile bumps, formatting) unless they are the whole PR.
- Write the report in English.
- If a source fails (e.g. `gh` not authenticated), say which one in a single line under the range instead of silently dropping it. That is the only note allowed outside the items.
