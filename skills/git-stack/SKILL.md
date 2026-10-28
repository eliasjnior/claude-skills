---
name: git-stack
description: Split the current branch into a stack of smaller draft PRs managed by gh stack, or change an existing stack (remove a part, mark it ready, turn it back to draft).
argument-hint: "[jira-ticket] [extra context] | remove <part> | ready [parts] | draft"
model: sonnet
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
---

You are a Pull Request splitting assistant. Take the work on the current branch and break it into a **stack of pull requests managed by `gh stack`** (GitHub's stacked PRs extension, https://gh.io/stacks).

**Rules**:
- Do NOT modify code. You only regroup existing changes into new branches. The single exception is the comment cleanup in step 2.
- The stack MUST be created with `gh stack`. Never hand-roll it with `git checkout -b` + `gh pr create --base <previous-branch>`: a chain of base branches is *not* a stack. Only `gh stack init` / `gh stack add` / `gh stack submit` register the stack locally and on GitHub.
- The original branch is scaffolding, not a deliverable. It is the source of the changes while the parts are built, and is deleted at the end, once verified that the parts reproduce its tree exactly. **Only the part branches survive.**
- NEVER close, edit, or comment on an existing PR of the original branch. If one exists, report it at the end and ask the user to close it manually.
- Ask for confirmation EXACTLY ONCE, before creating anything (step 4, one `AskUserQuestion` question per part). After approval, run the whole plan without further prompts.
- New PRs are created as **drafts** (`gh stack submit --auto` defaults to draft). The user marks them ready afterwards.
- NEVER pass `--no-verify` to any git command, even if the prompt asks for it. Every part becomes its own PR and must stand on its own, so hooks run on every commit and push.

**Steps**:

1. **Preflight**
   - `gh stack --version`. If the extension is missing, STOP and tell the user to run `gh extension install github/gh-stack`. Do not fall back to a manual `gh pr create` chain. Requires Git 2.36+.
   - Worktrees: `git worktree list`. Run the whole split from the worktree that has the original branch checked out, since `gh stack` checks out the part branches there. A part branch name already checked out in another worktree cannot be checked out here: pick another name.
   - `git config rerere.enabled true`, so `gh stack init` does not stop to ask for it.
   - Remotes: if the repo has more than one remote and `git config remote.pushDefault` is unset, pass `--remote origin` (or the right remote) to every `submit`, `sync`, `rebase`, and `link`.
   - `git fetch` and make sure the trunk is up to date. The trunk is the default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.
   - Read `${CLAUDE_SKILL_DIR}/../git-commit/references/commit-format.md` and `${CLAUDE_SKILL_DIR}/../git-pr/references/pr-template.md`.
   - Find the project's **check command**: what CI and the git hooks run (build/typecheck, lint, tests). Look at the project's CLAUDE.md, `package.json` scripts, `Makefile`, the hook config (`.husky/`, `lefthook.yml`, `.pre-commit-config.yaml`, …) and the CI workflows. Run it on the original branch: if it already fails there, STOP before splitting and report it, since no split can make the commits pass.

2. **Gather state**
   - `git status`, current branch, trunk branch.
   - `gh pr view --json number,title,url,headRefName,state` to detect an existing PR for this branch. Record it; do not touch it.
   - `git log <trunk>..HEAD` and `git diff <trunk>...HEAD --stat` for the full scope.
   - Commit any uncommitted changes first, in the commit format. The working tree must be clean before `gh stack init`.
   - **Clean up comments** so they do not pollute the PRs. In the lines the branch adds or changes (`git diff <trunk>...HEAD`), remove every comment that is not strictly necessary: comments that narrate what the code does, restate a name, describe the change itself ("added X", "now uses Y"), commented-out code, and debug leftovers. Keep only comments that explain a non-obvious *why* (a workaround, an invariant, a constraint, a link to an issue), plus license headers, tool directives (`eslint-disable`, `@ts-expect-error`, `// biome-ignore`, …), and doc comments on public APIs when the project documents them. Never touch comments that already exist on the trunk. Commit the cleanup on the original branch (e.g. `style: remove unnecessary comments`) before planning, so the split and the step 6 check work on the cleaned tree. Change nothing but comments.

3. **Plan the split**
   - Target roughly 200 changed lines per part. Coherence wins over the number: never split a feature mid-way just to hit the target, and never merge unrelated concerns just to fill a part.
   - Prefer these seams, in order: independent feature or concern, refactor/rename separated from behaviour change, config/tooling separated from application code, tests alongside the code they cover.
   - Order parts so each one builds and passes tests on its own, with foundations (types, schema, shared utilities) before consumers. The same holds for **every commit** inside a part, not just the last one: a commit never references something a later commit adds.
   - Regroup at **commit level** when the existing commits already map cleanly onto parts (cherry-pick them). Fall back to **file level** (`git checkout <original-branch> -- <paths>`) when a single commit spans several concerns.
   - The original history is not sacred: rewrite the commits whenever that organizes the parts better. Squash fixups, WIP and back-and-forth commits, split a commit that mixes concerns, reorder, and reword messages to the commit format, so each part reads as a few coherent commits. The step 2 comment cleanup should not survive as its own commit: fold it into the parts whose files it touches. Rewriting changes only the history, never the content: the parts must still add up to the original tree (step 6).
   - Every file changed on the original branch must land in exactly one part — the parts have to add up to the original tree (step 6 enforces this).
   - **Branch naming**: name each branch after what that part actually does, never `-part-<n>`. Keep the ticket identifier from the original branch when it has one, in the same position and format, and append a short kebab-case slug describing the part. Examples: `feat/PROJ-123-user-auth` → `feat/PROJ-123-auth-types`, `feat/PROJ-123-auth-middleware`, `feat/PROJ-123-login-ui`; `PROJ-123/checkout` → `PROJ-123/checkout-schema`, `PROJ-123/checkout-api`. With no ticket, use the plain slug with the original prefix style: `feat/auth-types`. The order lives in the stack and in the PR titles, not in the branch names.

4. **Confirm (single checkpoint)**
   Present the plan as text first:
   - A table per part: branch name, PR title, approximate line count, files covered, the planned commit messages, one-line rationale.
   - The stack diagram (`trunk → <branch-1> → <branch-2> → …`) and a reminder that parts must be merged bottom-up.
   - That the original branch will be **deleted locally** after verification, and deleted on the remote too when it has no open PR.
   - The existing PR, if any, with a note that it stays open and must be closed manually.
   - The comments removed in step 2, as a short per-file summary (or that none were removed).

   Then get the decisions with `AskUserQuestion`, one question per part, up to 4 questions per call (the tool's limit); use as few calls as the number of parts allows. Each question includes the part position (`n/N`), branch name, PR title, approximate line count, files covered, and the one-line rationale, with the options **Approve** / **Merge with the next part** (**Merge with the previous part** for the last one) ("Something different" is the tool's built-in Other, for renames, moving files, or splitting further). These calls together are the single checkpoint.
   Do not build anything until every part is approved. If any answer asks for a change, revise the plan, present it again, and repeat the questions.

5. **Build the stack** (all branches locally, before any push)
   - Part 1: `gh stack init --base <trunk> <branch-1>` — creates the stack, creates the branch off the trunk, and checks it out.
   - Apply that part's changes: `git cherry-pick <sha>` (which commits by itself), `git cherry-pick --no-commit <sha>…` to squash several commits into one, or `git checkout <original-branch> -- <paths>` followed by `git add <paths>` + `git commit` in the commit format. A part can have several commits when that tells its story better (e.g. a refactor, then the behaviour change).
   - `checkout` cannot bring deletions: for files the original branch deleted, run `git rm <paths>`; for renames, check out the new path and `git rm` the old one.
   - Each following part, from the topmost branch: `gh stack add <branch-n>` (always with the branch name: bare `add` prompts), then apply its changes and commit the same way. Stage paths explicitly rather than using the `add -Am` shortcut, so each part gets exactly its files.
   - Never `git rebase`, `git merge`, or `git push --force` by hand inside the stack — `gh stack` owns the branch topology.
   - **Check every commit**: right after each commit, the working tree is exactly that commit, so run the check command there. If it fails because of the split (a missing import, type, or file that lives in a later commit), regroup instead of editing code: move the missing change into this commit, or reorder/squash with the next one. Amend or `git reset --soft` only the commits of the topmost branch, which has nothing stacked on it yet. Move on to the next commit only once this one passes.
   - Run `gh stack view --json` and check the stack has all the parts in the right order.

6. **Verify completeness** (before anything is destroyed or pushed)
   - `git diff <top-part-branch> <original-branch>` MUST be empty. If it is not, the split lost or duplicated changes: STOP, do not submit, do not delete anything, and report the leftover diff.

7. **Submit**
   - `gh stack submit --auto` — pushes every branch, creates the PRs as drafts with the correct bases, and creates the stack on GitHub. (The interactive editor is unusable here, hence `--auto`.) Exit code 9 means stacked PRs are not enabled on this repository: stop, keep the original branch, and tell the user.
   - `gh stack view --json` to collect every branch's PR number and URL.
   - Set the real title and body per part (each body includes the shared `## Stack overview`, see **PR description**): write the body to a temp file and run `gh pr edit <number> --title "<title>" --body-file <file> [--add-label <labels>]`.
   - `gh stack view --short` for the final state.

8. **Drop the original branch**
   - Only after step 6 passed and step 7 succeeded: `git branch -D <original-branch>`. The current worktree is on a part branch by now, so the original is checked out nowhere and git lets it go. If `git worktree list` still shows it in another worktree, leave that worktree and the branch alone and tell the user to run `wt remove <original-branch>` (or `/git-worktree clean`) once they are done with it.
   - If the original branch exists on the remote and has **no** open PR: `git push origin --delete <original-branch>`.
   - If it has an open PR, leave the remote branch alone (deleting it would close the PR) and ask the user to close the PR manually.
   - End on the bottom branch of the stack (`gh stack bottom`).

9. **Jira** (when a ticket is provided)
   Apply the Jira step of the PR format to every PR of the stack.

10. **Report**
    List each part with its branch, PR number/URL, and line count, plus the `gh stack view --short` output. State that the original branch was deleted. If an existing PR was found, end by asking the user to close it manually, naming the PR number and URL.

**If a hook fails** (commit or push rejected) and regrouping as in step 5 cannot fix it, stop immediately — the remaining parts are stacked on the branch that just failed. Keep the original branch (do not run step 8). Report which part failed, the hook output, and the parts already pushed. Then hand back to the user: the fix is a code change, and this skill does not modify code. Never retry with `--no-verify`.

**Never run the interactive forms** — they open a prompt or a full-screen TUI and hang: bare `gh stack view` (use `--json` or `--short`), `gh stack submit` without `--auto`, `gh stack init` or `gh stack add` without a branch name, `gh stack checkout` without an argument, `gh stack merge` without a target and `--yes`, `gh stack switch`, and `gh stack modify`. Use the non-interactive forms, or leave the operation to the user.

**Exit codes worth handling**: 3 rebase conflict (resolve, `git add`, `gh stack rebase --continue`, or `--abort`), 4 GitHub API failure (check `gh auth status`), 8 stack file locked (retry after a few seconds), 9 stacked PRs not enabled on the repository.

**Repair paths**
- Part branches already exist (e.g. resuming after a failed run): adopt them instead of recreating — `gh stack init --base <trunk> <branch-1> <branch-2> …`, bottom to top. Existing branches are adopted, missing ones are created.
- PRs already exist but are not linked as a stack (a previous split that only chained base branches): `gh stack link --base <trunk> <branch-1> <branch-2> …` links them on GitHub without local tracking.
- Wrong order or wrong parts after the stack exists: there is no non-interactive reorder. `gh stack unstack` (removes local tracking and the GitHub grouping, keeps branches and PRs), fix the branches, then `gh stack init --base <trunk> <branch-1> …` again.

**Changing an existing stack** (when the user asks to remove a part or change the stack's status; `gh stack modify` is interactive, so use these instead)
- Removing a part: first decide with the user whether its changes are **discarded** or **folded** into a neighbour, since the commands differ.
  1. `gh stack unstack` — removes the GitHub grouping and local tracking, keeps branches and PRs.
  2. Rewrite the branches. Discarding a middle or bottom part: `git rebase --update-refs --onto <part-below> <removed-part> <top-part>`, where `<part-below>` is the trunk when the bottom part is removed. `--update-refs` moves every part branch between them in the same pass. Do not use `gh stack rebase` for this, since it would replay the removed commits onto the parts above. Discarding the top part needs no rebase. Folding into the part above needs no rebase either, since that branch already contains the removed commits. Folding into the part below: `git checkout <part-below> && git merge --ff-only <removed-part>`.
  3. `gh stack init --base <trunk> <remaining branches, bottom to top>`, then `gh stack submit --auto` to push the rewritten branches, retarget the PR bases, and recreate the stack.
  4. The removed part's PR is still open. Ask the user before closing it: `gh pr close <number> --delete-branch` (closes the PR and deletes the remote and local branch).
  5. Renumber the `(part N/M)` suffixes of the remaining PR titles with `gh pr edit <number> --title …`.
- Marking ready for review: `gh stack submit --auto --open` marks every PR of the stack ready. To mark only some, use `gh pr ready <number>` per PR, bottom up: a PR can only merge together with every PR below it (see Merging), so a ready part above a draft one cannot land yet.
- Back to draft: `gh stack` has no command for it. List the PRs with `gh stack view --json` and run `gh pr ready --undo <number>` on each. Converting to draft depends on the repository's plan; if GitHub rejects it, report that and stop.

**Hand-off notes for the user** (include the relevant ones in the report):
- Review feedback on a middle part: `gh stack down` to that branch, commit the fix, then `gh stack rebase --upstack` to cascade it through the branches above, and `gh stack submit --auto` to update the PRs.
- Merging: `gh stack merge <pr-number>` (add `--yes` to skip the prompt, and `--squash`/`--merge`/`--rebase` to pick the method) or the Merge button on the highest PR you want to land — that PR and every unmerged PR below it merge together, all or nothing. Layers cannot be skipped. `gh pr merge` cannot merge a stack. Drafts must be marked ready first.
- After something lands: `gh stack sync --prune` fetches, rebases the rest of the stack (squash merges included), pushes, and deletes the merged local branches.
- Restructuring (drop, fold, reorder, rename parts): `gh stack modify`, then `gh stack submit`. Interactive, so the user runs it; to have it done instead, ask for it (see Changing an existing stack).
- Navigation and status: `gh stack view` (`--short`, `--json`), `up`/`down`/`top`/`bottom`, `switch` for a picker.
- Marking the parts ready for review: `gh stack submit --auto --open`, or per PR with `gh pr ready <number>`. Back to draft: `gh pr ready --undo <number>` per PR.

**PR title**: conventional format with the part suffix, e.g. `feat: Add user authentication (part 1/3)`.

**PR description**: follow `${CLAUDE_SKILL_DIR}/../git-pr/references/pr-template.md`, and add a `## Stack overview` section right after `## Summary` in **every** PR of the stack. It describes what the stack as a whole implements (the overall feature and its purpose, in a short paragraph), so a reviewer opening any single part understands the bigger picture. Write it once and use the same text in every PR; `## Summary` and the other sections stay specific to that part. Do NOT list or link the other PRs in it (no checklist of parts): GitHub renders the stack navigation automatically on every PR of the stack.

**Arguments**: `$ARGUMENTS`
- If the arguments ask to change an existing stack (remove or fold a part, mark parts ready, turn the stack back to draft), skip the split steps and follow **Changing an existing stack** on the stack of the current branch. The rules above about splitting do not apply, except that `--no-verify` is still never passed.
- If the first argument looks like a Jira ticket (e.g. `PROJ-123`), use it as the ticket. Anything else is extra context.
