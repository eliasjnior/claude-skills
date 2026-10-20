# The stack baseline

The reference projects are two different products on one toolchain. That is deliberate: the
toolchain is not re-derived per project, so a decision made once stays made and the register only
carries what is genuinely project-dependent.

**Do not re-litigate §1 to §7.** Carry them, and write them into `NN-stack.md` with the reasons
below adapted to the project's own facts. Versions here are the ones pinned in the reference
projects today; check the registry for current versions when scaffolding, and say in the document
that the reasoning is what should not drift.

---

## 1. Language, runtime, workspace — fixed

| What | Version | Why | Cost to replace |
|---|---|---|---|
| **TypeScript** | 5.9+ | `strict` plus `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes` turn a class of runtime bug into a compile error. Types are the cheapest test available for a shape that crosses several APIs | High |
| **Node.js** | ≥ 22 | Native `--env-file`, stable `fetch`, the LTS the base images ship. Same language both sides of the stack. Bun is the alternative and it is a decided slot, not a default — see §8 | High |
| **pnpm** | pinned in `packageManager` | Workspaces plus a content-addressed store. The strictness is the feature: a package cannot import what it does not declare, which is what makes the boundary rules enforceable rather than aspirational. Provided by corepack, never installed globally | Medium |
| **Turborepo** | 2.x | Task graph and caching. The whole check gate finishes in seconds because most of it is cached | Medium |

Layout, always:

```
apps/           deployables. Only these produce build artifacts
packages/       libraries, consumed as TypeScript source
docs/           the plan
scripts/        repository scripts — not a workspace package, plain .mjs, own test run
```

Two properties that come with the layout and are worth stating explicitly in `NN-stack.md`:

- **`packages/domain` has zero runtime dependencies and performs no I/O.** No `fetch`, no database
  client, no `fs`, no `process.env`, no clock — time and randomness arrive as arguments. It is the
  most portable thing in the repository, and it is portable *because* of the absence. Enforced by
  lint, not by discipline.
- **Internal packages are consumed as TypeScript source** (`"exports": { ".": "./src/index.ts" }`),
  not as build artifacts. This removes a build step and its staleness failure mode from the inner
  loop, at the cost of every consumer needing a TypeScript toolchain — which, in a repository that
  is TypeScript end to end, is not a cost.

## 2. Tooling — fixed

| What | Why |
|---|---|
| **Biome** | Lint and format in one tool, fast enough to run on every commit. It replaces ESLint and Prettier and **adding either back is out of bounds**. It also enforces the package boundaries via `noRestrictedImports`, which is what makes them real rather than a review comment |
| **Husky** + **lint-staged** | `pre-commit` formats staged files; `pre-push` runs the gate |
| **worktrunk** (`wt`) | One worktree per task. `.config/wt.toml` makes a new worktree ready on creation (install, env files, its own ports and database), so parallel tasks and parallel agents never share a working tree |
| **commitlint** | Conventional Commits, scope is the workspace package name. Enforced in a hook and again in CI, because hooks can be bypassed |
| **Vitest** | Every unit and integration test, in every package |
| **Testcontainers** | Real Postgres (and Redis, and an SMTP sink) for `*.integration.test.ts` |
| **Playwright** | Any browser surface, against a seeded throwaway database |

## 3. Data — fixed

| What | Why | Cost to replace |
|---|---|---|
| **PostgreSQL** | The source of truth. Constraints are the cheapest correctness mechanism available: foreign keys, `NOT NULL`, `CHECK`, unique and exclusion constraints. Application-level invariants are the fallback, not the plan | High |
| **Drizzle ORM** | SQL that types itself, with no runtime the migration path depends on. The schema is hand-written TypeScript; the SQL is generated from it and reviewed **as SQL**, which matters when the review question is "does this lock the table" | High |
| **drizzle-kit** | Generates migrations from the schema. Build-time only, deliberately absent from the runtime image | Low |
| **Zod** | Every boundary the process does not control: environment, request bodies, provider responses, job payloads. Parsing at the edge is what lets everything inside assume its inputs. Types are inferred from schemas, never declared twice | Medium |

Migrations are forward-only, generated, committed, and reviewed as SQL. Nobody hand-edits a
migration that has been applied anywhere. `drizzle-kit push` never runs against a database anyone
cares about.

## 4. HTTP

What is fixed here is the **property**, not the framework. The framework is a slot, and both
options reach the property — they differ in what they charge for it and what else they bring.

### 4.1 The property — fixed

**A route is declared once, and that one declaration is three things:** the validation, the OpenAPI
document, and the type the client is generated from. Nothing is hand-written twice, and a route
cannot be documented into existence without existing.

Four consequences, and they hold whichever framework you pick:

| | |
|---|---|
| **Zod is the schema language** | Not the framework's own builder. Zod is already needed at every boundary the framework does not touch — environment, provider responses, job payloads — and a second schema language is a translation layer nobody asked for |
| **The document is generated** | Never hand-maintained. It is derived from the same schemas that reject a bad request |
| **Scalar serves it** | At `/reference`. Open in development, behind an admin session in production |
| **A check job holds it true** | `openapi.json` is committed, and the job fails when the committed copy and the running app disagree |

Where the API has no client of ours, the third of the three — the generated client — is worth
nothing, and that is exactly the case that decides the slot below.

### 4.2 The framework — a decided slot

Both are good. They are good at different shapes of project, so decide it per project and record it
as a `D-xx` naming the loser and why.

| | **Elysia** | **Hono** |
|---|---|---|
| Schema | Zod directly, via Standard Schema | Zod directly, via `@hono/zod-openapi` |
| OpenAPI | `@elysia/openapi`, Scalar included | `@hono/zod-openapi`, Scalar as a second package |
| Typed client | **Eden Treaty**, inferred from the server's own type | `hc<AppType>()`, inferred from the route definitions |
| Runtime | Bun natively; Node and others through adapters | Web-standard everywhere, no adapter |
| Surface | Larger. Lifecycle hooks, DI-ish `.decorate`/`.derive`, plugins | Smaller. A router and a `Request`/`Response` pipeline |

**Take Elysia when the API is a product surface**: many routes, a client we also own, payloads that
will change. Eden Treaty derives the client from the server's inferred type rather than from a
schema both ends have to agree about, which is the difference that keeps paying as the surface
grows. Its ergonomics are also where they are most enjoyable, and if Bun is or could be the
runtime, this is the pairing the framework was designed for.

**Take Hono when the API is an ingress**: webhooks, a health check, a handful of endpoints with no
client of ours. The typed-client argument buys nothing there, and what is left is a router — so
take the smaller one. Hono is also the answer when the runtime is unusual or might change
(Cloudflare Workers, Deno, Lambda, the edge): it is web-standard with nothing underneath, so there
is no adapter to depend on and handlers are testable as plain functions over `Request` and
`Response`.

**The tiebreak, when both fit:** how much of the surface a client of ours calls. High, Elysia. Low,
Hono.

Note the interaction with the runtime slot: **Elysia on Node** is a deliberate combination and
costs something real — you get the ergonomics and not the benchmarks, because Elysia's performance
story assumes Bun. That is usually the right trade, since the rest of this baseline is Node. Say so
in the register rather than leaving it as an accident.

### 4.3 What each looks like

```ts
// Elysia — Zod goes straight into the route
import { Elysia } from 'elysia'
import { openapi } from '@elysia/openapi'
import { z } from 'zod'

new Elysia()
  .use(openapi({ provider: 'scalar', mapJsonSchema: { zod: z.toJSONSchema } }))
  .post('/users', ({ body }) => create(body), {
    body: z.object({ name: z.string(), email: z.email() }),
  })
```

```ts
// Hono — the route is declared from the contract, and the contract is the OpenAPI entry
import { OpenAPIHono, createRoute } from '@hono/zod-openapi'
import { z } from 'zod'

const create = createRoute({
  method: 'post',
  path: '/users',
  request: { body: { content: { 'application/json': { schema: NewUser } } } },
  responses: { 201: { content: { 'application/json': { schema: User } }, description: 'Created' } },
})

new OpenAPIHono().openapi(create, (c) => c.json(createUser(c.req.valid('json')), 201))
```

Packages, per choice:

| Elysia | Hono |
|---|---|
| `elysia` · `@elysia/openapi` · `@elysia/eden` · `@elysia/node` (Node only) | `hono` · `@hono/zod-openapi` · `@scalar/hono-api-reference` · `@hono/node-server` (Node only) |

In both cases the typed-client package belongs to whatever **consumes** the API — the web app, not
the API. Putting `@elysia/eden` or `hono/client` in `apps/api` is the common mistake and it inverts
the dependency.

## 5. Web surface — fixed, when there is one

**Next.js** (App Router) + **React** + **Tailwind CSS**. Server components read the database
directly, so there is no API tier to build and keep in sync — and no second place to enforce
tenancy. The standalone output is what the image runs.

Own the components: a `packages/ui` with design tokens, over headless primitives
(**@base-ui/react**), rather than a component library as a dependency. Charts as React components
over D3 scales (**visx**) rather than a charting library, when there are few chart shapes and they
should sit on the product's own tokens.

## 6. Observability — fixed

**Pino**, structured JSON, fast enough to leave on; `pino-pretty` in development only. Every log
line carries the correlating id. Never log an email address, a phone number, a customer name, or a
capability URL.

Ship what the container runtime already wrote — Alloy → Loki → Grafana as an overlay that can be
started, stopped, upgraded or lost without the application noticing, which is the property to want
from anything whose job is to watch.

## 7. What was deliberately not used — carry this table

| Not used | Why |
|---|---|
| **ESLint, Prettier** | Biome does both, faster, in one config |
| **Vendor SDKs** | We use a fraction of each API, the failure modes are ours to handle, and an injectable `fetch` is the whole testing strategy. Hand-written clients over `fetch` |
| **A separate API tier for the dashboard** | Server components read the database directly. An API tier would be a second place to enforce tenancy |
| **An ORM with a runtime migration engine** | Migrations are committed SQL, reviewed as SQL |
| **A state manager** (Redux, Zustand) | The dashboard's state is the database's, fetched per request |
| **A component library** (MUI, Chakra, shadcn as a dependency) | `packages/ui` owns the tokens and the components |
| **A hosted identity provider** (Auth0, Clerk, WorkOS) | The part they sell is the user directory, and every account here already belongs to a tenant we resolve ourselves. It would also put the sign-in screen on somebody else's domain and the sign-in outage on somebody else's status page, for a flow that is four screens |
| **A second schema language** | The framework's own schema builder — Elysia's `t`, or a Fastify JSON-schema dialect — is good, and it is still a second one. Zod is already needed at every boundary the framework does not touch: environment, provider responses, job payloads. Both frameworks in §4.2 take Zod directly, so there is no reason to run two |
| **A backend-platform-as-a-service** (Supabase, Firebase, Amplify) | Managed Postgres is worth buying; a managed *data access path* is not. The browser reaching the database directly is the coupling this layout exists to avoid, and the pieces that come attached — a second auth system, an edge-function runtime, a realtime channel — are each a decision made for us, in a place we cannot test |
| **Express, Fastify, NestJS** | §4.1's property — one declaration producing validation, document and client — is what the framework is chosen for, and none of the three has it. Express has no schema story at all, Fastify's does not reach a client, and NestJS brings a DI container and a module system for a repository whose boundaries are already enforced by lint |
| **GraphQL** *(as our own API)* | One consumer, one team. It is a cost with no counterparty |
| **Kubernetes** | Compose runs the whole topology on one host |
| **Microservices** | One database, one API process. Splitting later is a compose change |

Adapt the rows, keep the shape. Any technology a reader would expect and not find belongs here with
a reason.

---

## 8. The variable slots — decide these per project, in the register

Each is a real fork. Pick with the rule, record it as a `D-xx` naming the other option.

| Slot | Options | Rule |
|---|---|---|
| **Background work** | Transactional outbox in Postgres, drained in-process · BullMQ + Redis | Outbox by default: the row and its side effects commit together, and a few hundred jobs a day do not justify a second stateful service. BullMQ when you need **delayed jobs** or **job-id collapsing** (a debounce window, "exactly one message per entity" under a burst), or the volume is thousands per hour |
| **HTTP framework** | Elysia · Hono | §4.2 has the comparison and the rule. Short version: **Elysia when the API is a product surface** with many routes and a client we also own, because Eden Treaty derives that client from the server's own type; **Hono when the API is an ingress** — webhooks and a health check, no client of ours — or when the runtime is unusual or might change, because it is web-standard with nothing underneath. Tiebreak: how much of the surface a client of ours calls |
| **Runtime** | Node ≥ 22 (adapter for Elysia, native for Hono) · Bun | **Node by default**, because the rest of the toolchain is built on it: `postgres:*` and Testcontainers, the `node:22-alpine` base image, pnpm through corepack, and every native addon the project might reach for. Elysia is WinterTC-compliant and the adapter is one line. **Bun when the API is the whole deployable and throughput is a stated requirement** — that is where Elysia's performance story lives, and on Node you are paying for the framework's ergonomics rather than its benchmarks. Say which one you took, and say what it costs |
| **Postgres hosting** | Postgres in Compose on one host · a managed cloud Postgres (RDS, Neon, Cloud SQL) | Compose when the deployment is already one host and the operational surface should stay there — it is the same image the integration tests run. Managed when backups, failover and point-in-time recovery are worth more than co-location, which is usually the moment real customer data arrives |
| **Identity** | Better Auth over your own schema · a hand-rolled session cookie | **Better Auth.** Sessions, passwords, reset, email verification, OAuth and TOTP, stored through an adapter into your own Drizzle schema, so `users` stays your table. Each of those written by hand is a small amount of code with a large number of ways to be quietly wrong, and the password hasher is still injectable, so the library owns the flow and not the primitive. Hand-rolled only when the product has exactly one door and no password |
| **Object storage** | S3-compatible (MinIO in development) · the filesystem | S3-compatible, with MinIO in `compose.dev.yaml` so development and production differ by an endpoint rather than a code path. Private bucket always; deliver through capability URLs your own API issues, so revocation is a key rotation rather than a sweep |
| **Mail** | SMTP via nodemailer · a provider's HTTP API | SMTP by default. It is the only interface every relay agrees on, so the development mailbox and the production relay differ by a URL rather than by a code path |
| **Where the check suite runs** | GitHub Actions · `scripts/ci.sh` behind `.husky/pre-push` | Actions when the repository is public or has more than one committer. The pre-push hook when it is private and metered — and then say out loud that `--no-verify` is the way past the only gate there is |
| **Deployment** | Compose on one host · a container platform (Fly, Railway) · Vercel for the web half | Compose when there is state to co-locate and one host is enough. Split the web half onto a platform only when it is genuinely stateless |
| **Tenancy** | Single tenant · multi-tenant from day one | If money changes hands per organization, `org_id` in every table from the first migration. Adding it later is a migration of everything |

Two more, always decided explicitly and always in the register:

- **Naming per layer.** SQL `snake_case` throughout; TypeScript `camelCase`, with the ORM carrying
  the mapping; HTTP paths lowercase `kebab-case`; JSON payload fields whatever existing clients
  already send. Files `kebab-case.ts`, one main export named after the file. Named exports only, no
  default exports, including React components.
- **Domain vocabulary.** One word per concept, everywhere, and the boundary where a different word
  survives because it is the user's word. Settle it before writing document `02`.

---

## 9. Scaffold files (Phase 7 only)

Emit these only when the user asks for a scaffold. Fill the marked slots; leave the rest.

### `package.json`

```json
{
  "name": "<project>",
  "private": true,
  "type": "module",
  "packageManager": "pnpm@<pinned>",
  "engines": { "node": ">=22" },
  "scripts": {
    "prepare": "husky",
    "dev": "turbo dev",
    "build": "turbo build",
    "typecheck": "turbo typecheck",
    "test": "turbo test",
    "test:integration": "turbo test:integration",
    "test:e2e": "turbo test:e2e",
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "format": "biome format --write .",
    "check": "turbo typecheck test && biome ci .",
    "db:generate": "pnpm --filter @<project>/db db:generate",
    "db:migrate": "pnpm --filter @<project>/db db:migrate",
    "db:seed": "pnpm --filter @<project>/db db:seed"
  },
  "devDependencies": {
    "@biomejs/biome": "^2",
    "@commitlint/cli": "^21",
    "@commitlint/config-conventional": "^21",
    "husky": "^9",
    "lint-staged": "^17",
    "turbo": "^2",
    "typescript": "^5.9",
    "vitest": "^4"
  },
  "lint-staged": {
    "*": ["biome check --write --no-errors-on-unmatched --files-ignore-unknown=true"]
  }
}
```

### `pnpm-workspace.yaml`

```yaml
packages:
  - apps/*
  - packages/*

# Install scripts are denied by default: an install script is code that runs before any of ours
# does. esbuild is the exception — drizzle-kit loads its config through it and the install script
# is what puts the platform binary in place. Every other entry is an optional native acceleration
# with a JavaScript fallback, so this list is meant to be read, not grown.
allowBuilds:
  esbuild: true
  cpu-features: false
  protobufjs: false
  ssh2: false
```

### `tsconfig.base.json`

```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "target": "ES2023",
    "lib": ["ES2023"],
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "resolveJsonModule": true,
    "verbatimModuleSyntax": true,
    "isolatedModules": true,
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "noPropertyAccessFromIndexSignature": true,
    "skipLibCheck": true,
    "declaration": true,
    "sourceMap": true,
    "noEmit": true
  }
}
```

### `turbo.json`

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "topo": { "dependsOn": ["^topo"] },
    "build": { "dependsOn": ["^build"], "outputs": [".next/**", "!.next/cache/**", "dist/**"] },
    "typecheck": { "dependsOn": ["^topo"] },
    "test": { "dependsOn": ["^topo"], "outputs": ["coverage/**"] },
    "test:integration": { "dependsOn": ["^topo"], "cache": false },
    "test:e2e": { "dependsOn": ["build"], "cache": false },
    "dev": { "cache": false, "persistent": true },
    "db:generate": { "cache": false }
  }
}
```

### `biome.json`

Formatter at `lineWidth: 100`, two-space indent. Linter: `noExplicitAny` error,
`noConsole` error, `noDefaultExport` error, `noUndeclaredDependencies` error. Then one `overrides`
entry per package that has a boundary, each `noRestrictedImports` path carrying a **message that
names the rule and where it is written down**:

```json
{
  "overrides": [
    {
      "includes": ["packages/domain/**"],
      "linter": {
        "rules": {
          "style": {
            "noRestrictedImports": {
              "level": "error",
              "options": {
                "paths": {
                  "@<project>/db": "packages/domain imports nothing. See CLAUDE.md, Package boundaries."
                }
              }
            }
          }
        }
      }
    }
  ]
}
```

Write the rules for packages that do not exist yet. They bite the moment one is created, and there
is nothing to remember at that point.

Note the sharp edge, and write it into `CLAUDE.md`: Biome matches an import specifier **exactly**,
so forbidding `@<project>/db` does not forbid `@<project>/db/testing`. A new subpath is a new hole
until it is named in every rule that names the package.

### `commitlint.config.js`

```js
export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [2, "always",
      ["feat", "fix", "refactor", "perf", "test", "docs", "build", "ci", "chore", "revert"]],
    "subject-case": [2, "never", ["upper-case", "pascal-case", "start-case"]],
    "header-max-length": [2, "always", 100],
  },
};
```

### `apps/api/package.json`

Whichever framework §4.2 chose, and only that one:

```jsonc
// Elysia
{ "dependencies": {
  "elysia": "^1",
  "@elysia/openapi": "^1",   // OpenAPI document, Scalar included
  "@elysia/node": "^1",      // only when the runtime slot took Node
  "zod": "^4"
} }

// Hono
{ "dependencies": {
  "hono": "^4",
  "@hono/zod-openapi": "^1",           // routes declared from Zod contracts
  "@scalar/hono-api-reference": "^0",  // the playground
  "@hono/node-server": "^1",           // only when the runtime slot took Node
  "zod": "^4"
} }
```

The typed-client package — `@elysia/eden` or `hono/client` — belongs to whatever **consumes** the
API. It goes in `apps/web`, never in `apps/api`.

### `scripts/ci.sh` and the hooks

`references/workflow.md` §4 has the script itself, ready to write, along with the two properties
that make it worth having: it runs **every** job before reporting, and a skipped job prints its
reason. Emit it with the scaffold, and wire the three hooks:

| Hook | Runs |
|---|---|
| `.husky/pre-commit` | `pnpm lint-staged` |
| `.husky/commit-msg` | `pnpm commitlint --edit "$1"` |
| `.husky/pre-push` | `./scripts/ci.sh` |

Add `"ci": "./scripts/ci.sh"` and `"ci:fast": "CI_FAST=1 ./scripts/ci.sh"` to the root scripts, so
the gate is runnable by hand and by the hook through one path.

### `.config/wt.toml` and `.worktreeinclude`

What makes a worktree from `wt switch --create` usable the moment it exists
(`references/workflow.md` §1.1). Every per-worktree value lands in `.env.worktree`, gitignored and
loaded after `.env`, so the copied `.env` stays identical to the primary one and the dev script
reads both.

```toml
# Worktree lifecycle for worktrunk (`wt`). Every task runs in its own worktree.

[[pre-start]]
# The env files listed in .worktreeinclude, copied from the primary worktree
copy = "wt step copy-ignored"

[[pre-start]]
# Dependencies, and the git hooks husky writes during install, so the push gate exists here too
install = "pnpm install --frozen-lockfile"

[[pre-start]]
# This worktree's own ports and database, derived from the branch so they never collide
env = """
cat > .env.worktree <<EOF
API_PORT={{ (repo ~ '-api-' ~ branch) | hash_port }}
WEB_PORT={{ (repo ~ '-web-' ~ branch) | hash_port }}
DATABASE_URL=postgres://postgres:postgres@localhost:5432/{{ branch | sanitize_db }}
EOF
"""

[[post-start]]
# The database on the shared dev Postgres. Background, so a stopped Postgres is a log line, not a
# failed worktree; run `wt hook post-start` again once it is up
db = '''
docker compose -f compose.dev.yaml exec -T postgres psql -U postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname = '{{ branch | sanitize_db }}'" | grep -q 1 \
  || docker compose -f compose.dev.yaml exec -T postgres createdb -U postgres {{ branch | sanitize_db }}
'''

[[post-start]]
migrate = "pnpm db:migrate"

[list]
url = "http://localhost:{{ (repo ~ '-web-' ~ branch) | hash_port }}"

[aliases]
# `wt dev`: this worktree's dev servers, on its own ports
dev = "pnpm dev"
```

```text
# .worktreeinclude — gitignored files every new worktree needs
.env
apps/*/.env
```

`compose.dev.yaml` sets a top-level `name: <project>-dev`, so every worktree talks to the **same**
backing services instead of starting its own on the same host ports. Isolation comes from a
database per worktree, not a server per worktree. Dropping the database of a removed worktree is
deliberately not a hook: it destroys data, so it is a command in the engineering-practices
document, run by hand. Add `.env.worktree` to `.gitignore`.

### Also

`.nvmrc` with the major. `.env.example` documenting every variable with a fake value, and `.env`
ignored and never printed to a log. `compose.dev.yaml` with backing services only — application
processes run on the host, because hot reload and real stack traces are worth more in the inner
loop than production parity, and parity is recovered in the container-backed check jobs.
