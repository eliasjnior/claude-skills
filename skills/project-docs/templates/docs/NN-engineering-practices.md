<!-- TEMPLATE. Spec: references/document-specs.md. Source for §3–§5: references/workflow.md. -->
# NN — How we work

## 1. Principles

<!-- Three to five. Each must decide something. "The gate runs before the pull request exists."
     "A skipped job prints its reason, because a silent skip is indistinguishable from a pass." -->

## 2. Toolchain

| Tool | Role |
|---|---|

<!-- pnpm via corepack, Turborepo, Biome (no ESLint, no Prettier — say that adding them back is
     out of bounds), Husky, lint-staged, commitlint, Vitest, Testcontainers, Playwright. -->

## 3. The repository, branches and commits

Pull requests are opened against `<remote>`. `main` is protected and is the only merge target.

- **Branches:** `feat/m2-<slug>`, `fix/<slug>`. The milestone prefix ties the branch to
  [`NN-roadmap.md`](NN-roadmap.md).
- **Commits:** Conventional Commits, scope is the workspace package name. Allowed types: `feat`,
  `fix`, `refactor`, `perf`, `test`, `docs`, `build`, `ci`, `chore`, `revert`.
- **PR titles** follow the same convention — squash merge makes the title the commit on `main`.

## 4. The delivery loop

One task in, one merged commit out. Repeat until the milestone's **Done when** is true.

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

A task is done when three things are true, not one: the code, the tests for the layer it belongs
to, and **the documents it changes, in the same pull request**. Documentation drift is the failure
mode of a plan this detailed.

Size budget: under ~400 changed lines, excluding lockfiles, generated migrations and snapshots. If
it does not fit, it is more than one pull request.

The body states four things, always the same four:

```
## What changed
## Why            — milestone, FR-xx, the document section this implements
## How it was verified
## Risk if this is wrong
```

### 4.1 Auto-merge conditions

<!-- The checklist. Every item must hold. Then: if any fails, apply needs-human, write why, stop —
     do not work around the condition. -->

### 4.2 When a check fails

Read the failing job, fix the actual cause, push. **Three attempts maximum**, then label
`needs-human`, write down what was tried, and stop.

Never "fix" a check by deleting a test, skipping a test, loosening a lint rule, adding an ignore
comment, widening a type, adding `any`, pushing with `--no-verify`, or re-running the job hoping
for a different result. Each of those converts a caught problem into an uncaught one.

### 4.3 When to stop

The milestone is done · `needs-human` was applied · a decision in the register turns out to be
wrong · the work needs a `D-xx` that does not exist. Those four.

## 5. The check suite

<!-- Where it runs, and what that costs. If it is the local hook, say plainly that `--no-verify`
     is the way past the only gate there is, and name the condition that would move it to a
     hosted workflow. -->

| Job | What it runs | Skips when |
|---|---|---|
| format and lint | `biome ci .` | never |
| typecheck | `turbo typecheck` | never |
| unit tests | `turbo test` | never |
| integration | `turbo test:integration` | Docker is not running, or `CI_FAST=1` |
| migrations | regenerate and assert nothing new appears | there is no schema package yet |

A job whose subject does not exist yet **skips with its reason printed** — never fails, and never
passes silently. That is what lets the same `scripts/ci.sh` be correct from `M0` to the last
milestone.

## 6. Hooks

| Hook | Runs |
|---|---|
| `pre-commit` | `lint-staged` — Biome over staged files |
| `commit-msg` | `commitlint` |
| `pre-push` | `./scripts/ci.sh` |

## 7. Local development

## 8. Environments

## 9. Secrets

<!-- `.env.example` documents every variable with a fake value; `.env` is ignored and never printed
     to a log. Rotation lives in NN-provider-setup.md. -->

## 10. Definition of done

- <checkable>
