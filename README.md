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
| [`project-docs`](skills/project-docs) | Turns a project description into a complete plan: `PROJECT.md`, `CLAUDE.md`, `README.md` and a numbered `docs/` set, on a fixed TypeScript monorepo baseline | `/project-docs <description>` | default |
| [`git-commit`](skills/git-commit) | Groups the current changes by concern and commits each group with Conventional Commits, leaving sensitive files out | `/git-commit [jira] [context]` | haiku |
| [`git-pr`](skills/git-pr) | Commits pending work, renames the branch to the project's pattern, pushes, and opens a pre-filled PR in the browser for you to submit | `/git-pr [jira] [context]` | haiku |
| [`git-pr-fix`](skills/git-pr-fix) | Triages the open review threads on a PR, asks which to address, and applies the approved ones without committing | `/git-pr-fix [pr] [context]` | default, high effort |
| [`git-rename-branch`](skills/git-rename-branch) | Detects the project's branch naming pattern and renames the current branch to match, falling back to `<user>/<summary>` | `/git-rename-branch [jira] [context]` | haiku |
| [`git-stack`](skills/git-stack) | Splits the current branch into a stack of draft PRs with [`gh stack`](https://gh.io/stacks), about 200 changed lines per part | `/git-stack [jira] [context]` | sonnet |

Installed as a plugin, the skills are namespaced: `/claude-skills:git-commit`. The short name
works too while no other skill shares it.

---

### `project-docs`

Derived from two existing projects whose documentation shares one shape and one toolchain, so a
third project inherits the reasoning rather than re-deriving it.

```
PROJECT.md          problem · proposal · principles · scope · document map · D-xx register
CLAUDE.md           non-negotiables · boundaries · commands · conventions · the delivery loop
README.md           running the code, and nothing else
docs/
  01-product.md              personas · FR-xx / NFR-xx inventory · metrics · non-goals
  02-<domain core>.md        the one thing this does, specified to the level of a test
  03-architecture.md         components · boundaries · request path · jobs · deployment
  04-data.md                 every table · retention · what is not stored · security · privacy
  …                          admin · integrations · auth · design · billing · migration, as earned
  NN-engineering-practices.md
  NN-roadmap.md              milestones with "Done when" · risks · definition of done
  NN-stack.md                every dependency: why, and what replacing it costs
  NN-provider-setup.md       field-by-field provider setup · every env var
```

**Four properties.** If the output does not have all four, the skill did not do its job:

1. **Every decision carries its reasoning and its reversal condition.** A `D-xx` register where a
   closed decision keeps its ID and gains the argument, including the option that was rejected and
   why.
2. **Requirements are inventoried and identified.** `FR-xx` / `NFR-xx` with priorities, referenced
   by the roadmap, so "done" is checkable rather than felt.
3. **The stack is fixed, not chosen fresh.** Only the genuinely project-dependent slots get
   decided, and each one is decided in the register with its alternative named.
4. **Absences are recorded.** "What was deliberately not used", with reasons.

**The stack it plans on.** Fixed: TypeScript strict · Node ≥ 22 · pnpm + Turborepo · Biome (no
ESLint, no Prettier) · Zod at every boundary · PostgreSQL + Drizzle · Pino ·
Vitest / Testcontainers / Playwright · Next.js + Tailwind where there is a UI.

For HTTP what is fixed is the property rather than the framework: a route is declared once, and
that declaration is the validation, the OpenAPI document, and the type the client is generated
from. Decided per project, each with its alternative named and priced: the HTTP framework (Elysia
or Hono), the runtime (Node or Bun), background work (transactional outbox or BullMQ), Postgres
hosting, identity, object storage, mail, where the check suite runs, deployment, and tenancy.

**The delivery loop.** The generated `CLAUDE.md` and engineering-practices document both carry one
loop, so a human and an agent run the same one:

```
  ┌─ pick the next task from the current milestone
  ├─ branch      git switch -c <type>/<milestone>-<slug>
  ├─ implement   the code AND its tests AND the docs it changes
  ├─ gate        git push → .husky/pre-push runs ./scripts/ci.sh
  ├─ open        gh pr create --base main --label goal:<milestone>
  ├─ wait        gh pr checks --watch
  ├─ merge       gh pr merge --squash --delete-branch
  └─ next task ──┘
```

The gate runs before the pull request exists, so a red branch never becomes somebody's review.
Three failed attempts on the same check means `needs-human` and stop. Deleting a test, loosening a
lint rule, widening a type or `--no-verify` are never a fix. The repository is named once, in
`CLAUDE.md`, and is never inferred.

Ask for a scaffold and it also emits the toolchain the documents promise. Ask it to build, and it
runs the loop until the milestone is done.

**Calibration.** `skills/project-docs/references/calibration.md` holds illustrative passages
written in the target voice, about fictional products. That is what keeps the generated prose from
reading like generated prose.

---

### Git workflow skills

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
