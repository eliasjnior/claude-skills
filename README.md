# claude-skills

Personal collection of [Claude Code](https://claude.com/claude-code) skills.

A skill is a packaged set of instructions Claude loads on demand. These are mine: opinionated,
built around how I actually work, and kept here so every machine and every project gets the same
ones.

## Install

```bash
git clone git@github.com:eliasjnior/claude-skills.git
cd claude-skills
./install.sh
```

`install.sh` symlinks every directory under `skills/` into `~/.claude/skills/`, so a `git pull`
updates all of them at once and there is nothing to reinstall. To scope a skill to one repository
instead, symlink it into that repository's `.claude/skills/`.

As a plugin, if you prefer that:

```
/plugin marketplace add eliasjnior/claude-skills
/plugin install claude-skills@claude-skills
```

## Skills

| Skill | What it does | Invoke | Model |
|---|---|---|---|
| [`git-commit`](skills/git-commit) | Groups the current changes by concern and commits each group with Conventional Commits, leaving sensitive files out | `/git-commit [jira] [context]` | haiku |
| [`git-pr`](skills/git-pr) | Commits pending work, renames the branch to the project's pattern, pushes, and opens a pre-filled PR in the browser for you to submit | `/git-pr [jira] [context]` | haiku |
| [`git-pr-fix`](skills/git-pr-fix) | Triages the open review threads on a PR, asks which to address, and applies the approved ones without committing | `/git-pr-fix [pr] [context]` | default, high effort |
| [`git-rename-branch`](skills/git-rename-branch) | Detects the project's branch naming pattern and renames the current branch to match, falling back to `<user>/<summary>` | `/git-rename-branch [jira] [context]` | haiku |
| [`git-stack`](skills/git-stack) | Splits the current branch into a stack of draft PRs with [`gh stack`](https://gh.io/stacks), about 200 changed lines per part | `/git-stack [jira] [context]` | sonnet |
| [`project-docs`](skills/project-docs) | Writes a full project plan and documentation set from a project description | `/project-docs <description>` | default |

Installed as a plugin, the skills are namespaced: `/claude-skills:git-commit`. The short name
works too while no other skill shares it.

---

### Git workflow

`git-commit`, `git-pr`, `git-pr-fix`, `git-rename-branch` and `git-stack` cover the path from a dirty
working tree to reviewable pull requests.

- **`git-commit`** groups the staged and unstaged changes into cohesive units and commits each one
  in the format from `references/commit-format.md`. Files that look sensitive are left out and
  listed in the summary.
- **`git-pr`** commits anything pending, checks the branch name with `git-rename-branch`'s rules,
  pushes, and runs `gh pr create --web`. It never creates the PR itself: the form opens pre-filled
  in the browser and you submit it.
- **`git-pr-fix`** reads the PR's review threads through GraphQL, skipping resolved ones and
  flagging outdated ones, categorizes them, and asks per comment whether to address it. Approved
  changes stay in the working tree with a suggested commit message.
- **`git-rename-branch`** reads the naming rule from the project's docs, or infers it from recent
  PR and remote branches, and renames the branch. A remote branch is renamed through the GitHub
  API, so open PRs stay attached, and only after you confirm.
- **`git-stack`** removes unnecessary comments from the branch's changes, plans parts of roughly
  200 changed lines that each build and pass checks on their own, and asks once for approval per
  part. It then builds the stack with `gh stack`, rewriting commits where that makes the parts
  cleaner, verifies every commit and that the parts add up to the original tree, and submits
  draft PRs that share a stack overview. The original branch is deleted at the end.

Skills that take a Jira ticket fetch it through the Atlassian MCP server and add the context to
the commit or PR. The commit format and the PR template live once, in
`skills/git-commit/references/` and `skills/git-pr/references/`, and the other skills read them from
there, so the skills are meant to be installed together.

Only `git-commit` can be triggered by Claude on its own ("commit this"). The others push, open PRs,
rename remote branches or edit code, so they run only when typed.

Requirements: the [GitHub CLI](https://cli.github.com) (`gh`), plus the `gh stack` extension for
`git-stack` (`gh extension install github/gh-stack`), and the Atlassian MCP server only for the Jira
integration.

### Planning

- **`project-docs`** turns a project description into a full documentation set: `PROJECT.md`,
  `CLAUDE.md`, `README.md` and a numbered `docs/` spine, with a decision register, identified
  requirements and a delivery loop. It plans on a fixed TypeScript monorepo stack and decides only
  the slots that genuinely vary per project. [`skills/project-docs/README.md`](skills/project-docs/README.md)
  has the document set, the stack and the loop.

## Adding a skill

One directory under `skills/`, named for the skill:

```
skills/<name>/
  SKILL.md        frontmatter (name, description) + the process. Keep it short
  references/     loaded on demand, one file per concern
  templates/      scaffolds, when shape is hard to get right from prose
```

`SKILL.md` is the only file always loaded, so it stays an entry point rather than a manual —
everything long lives in `references/` behind a line in `SKILL.md` saying when to read it. The
`description` is what decides whether the skill triggers, so it names the artifacts and the phrases
someone would actually type, in every language they would type them in.

Then run `./install.sh` again to link it.

## Layout

```
skills/                     one directory per skill
.claude-plugin/             plugin and marketplace manifests
install.sh                  symlink every skill into ~/.claude/skills
```
