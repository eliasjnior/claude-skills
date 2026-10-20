# project-docs

Turns a project description into a complete plan: `PROJECT.md`, `CLAUDE.md`, `README.md` and a
numbered `docs/` set, on a fixed TypeScript monorepo baseline.

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
  ├─ worktree    wt switch --create <type>/<milestone>-<slug>
  ├─ implement   the code AND its tests AND the docs it changes
  ├─ gate        git push → .husky/pre-push runs ./scripts/ci.sh
  ├─ open        gh pr create --base main --label goal:<milestone>
  ├─ wait        gh pr checks --watch
  ├─ merge       gh pr merge --squash
  ├─ clean up    git fetch origin && wt remove && git push origin --delete <branch>
  └─ next task ──┘
```

Every task runs in its own [worktrunk](https://worktrunk.dev) worktree, made ready on creation by
`.config/wt.toml` (install, env files, its own ports and database), so parallel tasks never share a
working tree.

The gate runs before the pull request exists, so a red branch never becomes somebody's review.
Three failed attempts on the same check means `needs-human` and stop. Deleting a test, loosening a
lint rule, widening a type or `--no-verify` are never a fix. The repository is named once, in
`CLAUDE.md`, and is never inferred.

Ask for a scaffold and it also emits the toolchain the documents promise. Ask it to build, and it
runs the loop until the milestone is done.

**Calibration.** [`references/calibration.md`](references/calibration.md) holds illustrative passages
written in the target voice, about fictional products. That is what keeps the generated prose from
reading like generated prose.
