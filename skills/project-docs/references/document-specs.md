# Document specifications

What each document owes. Sections are the reference set's, numbered so `§n` references work.
A section with nothing real in it is deleted, not padded. Where a document's sections differ by
profile, both tables are here; use the one for the profile chosen in Phase 0. Diagrams follow
`references/diagrams.md`.

---

## `01-product.md` — Product

Short. An inventory is short.

| § | Section | Content |
|---|---|---|
| 1 | Personas | Table: persona · who they are · what they need · **what they hate**. The last column is the one that produces requirements |
| 2 | Jobs to be done | One line each, in the user's voice: "When X, I want Y, so that Z" |
| 3 | Functional requirements | `FR-xx` tables, grouped by subsystem, each row with a priority (`P0` ships in v1.0, `P1` in v1.x, `P2` later). Number in tens per group so rows can be inserted |
| 4 | Non-functional requirements | `NFR-xx` with a **target that is a number**: a percentile and a latency, a quota fraction, a coverage threshold |
| 5 | Success metrics | Baseline · target. Plus **anti-metrics**: what would tell you the product made things worse |
| 6 | Explicit non-goals | What this is not, stated so nobody proposes it twice |

When the project replaces an existing system, each `FR` also names the file or feature it replaces,
and a `§3.n` lists what is **deliberately dropped**, with a reason. Anything not on that list and
not implemented is a gap in this document, and say so in those words.

`FR` ids are referenced from the roadmap, the test plan, and the integration document. They are the
spine of "done".

---

## `02-<domain core>.md` — the one thing this does

Named for the subject, never `domain`. Usually the longest document in the set.

Specified to the level of a test: the actual rule, the actual ordering, the actual tie-break, the
actual precedence. Required:

- **The flow end to end**, as a numbered walk or a Mermaid diagram, with what is true after each
  step. A lifecycle with states is a `stateDiagram-v2`.
- **The inputs it needs**, and where each comes from.
- **The rules**, one section each, in the order they apply.
- **Worked examples.** Concrete inputs, the expected outcome, and *why* — including at least one
  where the naive answer is wrong. These become test cases verbatim.
- **What can go wrong, and what happens** — every failure mode with the system's response.

Where the product's surface is what people judge (a message, a screen, a report), add a **state
gallery**: every state rendered, with the composition and precedence rules that decide which one
wins when two apply.

---

## `03-architecture.md` — Architecture

### web

| § | Section | Content |
|---|---|---|
| 1 | The central idea | One paragraph naming the property everything else serves — "reconcile, do not react"; "one process, one database, one transaction". Everything below is downstream of this |
| 2 | Repository layout | The tree, with one line per directory saying what it is |
| 3 | Boundaries | Which package may import which, and **how it is enforced** — a lint rule with a message, not a convention |
| 4 | The request path | Middleware in its exact order, what each rejects, what reaches a handler |
| 5 | Background work | The outbox or the queue: what is written when, what drains it, retry and backoff, idempotency key |
| 6 | The scheduler | Every periodic job, its cadence, its timezone, and what makes it safe to run twice |
| 7 | Ports and adapters | The interface per external system, and the adapters behind it including the fake used in tests |
| 8 | Configuration | Where environment lives, how it is validated, which process gets which variable |
| 9 | Storage | Buckets, key layout, access model |
| 10 | Observability | What is logged, what is never logged, what is measured |
| 11 | Deployment | Images, processes, topology, what recreates what |
| 12 | Open technical questions | The ones that are honestly still open, each pointing at its `D-xx` |

### macos

| § | Section | Content |
|---|---|---|
| 1 | The central idea | The same paragraph, for an app — "the kit decides, the app shows" |
| 2 | Repository layout | The tree, with one line per directory, `apps/macos` down to the feature folders |
| 3 | Targets and boundaries | Every target of `<Name>Kit`: responsibility, what it depends on. Then the graph as a Mermaid `flowchart`, and **how it is enforced**: SwiftPM's declared dependencies, plus `check-imports.sh` for what the compiler cannot see |
| 4 | The main path | The poll, the event or the user action the product exists for, step by step: who performs it, through which port. A `sequenceDiagram` |
| 5 | Scheduling | Every timer and trigger: cadence, backoff, what happens on sleep and wake, on network loss, at launch, and what makes a tick safe to repeat |
| 6 | Credentials | Where the app's credentials come from, where they live (the Keychain), when they are re-read, what a `401` does |
| 7 | Ports and adapters | The protocol per external system, the adapter behind it, and the fake used in store tests |
| 8 | Configuration | `Info.plist` keys, the xcconfig, build settings per configuration, and why there is no `.env` |
| 9 | Storage | Pointer to `04-data.md`, plus the write path: atomic writes, who owns each file |
| 10 | Distribution and updates | Signing, how a build reaches the Mac, how the app updates itself and what it verifies first. Its own document when `NN-distribution.md` was earned |
| 11 | Concurrency | Which actors exist, what runs on the main actor, how a store publishes one value per update |
| 12 | Observability | `os.Logger` subsystems and categories, what is never logged, how to read the log |
| 13 | Open technical questions | The ones honestly still open, each pointing at its `D-xx` |

### cli

| § | Section | Content |
|---|---|---|
| 1 | The central idea | The same paragraph, for a tool — "the core decides, the command renders" |
| 2 | Repository layout | The tree, `src/` down to the command files |
| 3 | Layers and boundaries | `core`, `commands`, `adapters`, `render`: what each may import, and **how it is enforced** (Biome's rules on `src/core/**`). Then `main(argv, io)` and why the process is an argument |
| 4 | The command tree | **Every command and subcommand**: its arguments, its flags with defaults, what it prints, its `--json` shape, its exit codes. A table per command. This is the public interface, and a rename is a breaking change |
| 5 | The command-line contract | stdout and stderr, `--json`, the exit code table, TTY rules, colour, errors, Ctrl-C (`references/stack-cli.md` §3), adapted |
| 6 | The main path | The command the product exists for, step by step through its ports. A `sequenceDiagram` |
| 7 | Ports and adapters | The interface per external system, the adapter behind it, the stub server used in tests |
| 8 | Configuration | The precedence chain, every config key and every environment variable, and `config show` |
| 9 | Storage | Pointer to `04-data.md`, plus the write path: atomic writes, what is safe to delete |
| 10 | Distribution | How it reaches a machine, what the published artifact contains, the supported platforms and Node majors. Its own document when `NN-distribution.md` was earned |
| 11 | Observability | `--verbose`, what is never printed, and that there is no telemetry |
| 12 | Open technical questions | The ones honestly still open, each pointing at its `D-xx` |

The stack belongs here as a `§` only in summary form, pointing at `NN-stack.md`, which owns it.

---

## `04-data.md` — Data, identity and privacy

### web

| § | Section | Content |
|---|---|---|
| 1 | Conventions | Naming, key type and why, timestamps (`timestamptz`, always), money and counters as integers, soft delete or not |
| 2 | Core tables | **Every table**: columns with types, nullability, defaults, foreign keys with their `ON DELETE`, `CHECK` constraints, unique constraints, indexes with the query each one serves. Prose under each table for the invariants the schema cannot express |
| 3 | Derived data | Denormalized counters, views, materialized state — and for each, what keeps it true. A counter that is money-adjacent moves in the transaction that caused it to move, or it does not move |
| 4 | Retention | What is deleted when, and what deletes it |
| 5 | What we deliberately do not store | The most valuable section here. Customer code, diffs, message bodies, card numbers — with the reason |
| 6 | Security | Grants, row-level security, what the browser can reach (nothing), how secrets are held |
| 7 | Privacy | The regime that applies (LGPD, GDPR), the lawful basis, the subject-access and deletion paths |

Write the schema as SQL-shaped tables, not as ORM code. The ORM is an implementation of this
document, not a substitute for it. An `erDiagram` above the tables shows the relations; the tables
stay authoritative.

### macos

| § | Section | Content |
|---|---|---|
| 1 | Conventions | Where files live, encoding, dates (ISO 8601, UTC), `schemaVersion`, atomic writes, what happens to a file that does not decode |
| 2 | Files | **Every file**, split by who writes it (`config.json`, `state.json`, `cache/`), with every key: type, default, what writes it, what reads it. Then every Keychain item and every `UserDefaults` key, with why it lives there |
| 3 | Derived data | What is computed from the files at launch rather than stored, and why |
| 4 | Retention | What is pruned when, and by what |
| 5 | What we deliberately do not store | The most valuable section here, as on web |
| 6 | Security | What is in the Keychain, file permissions, what leaves the Mac and to whom |
| 7 | Privacy | What a reset removes, how the user exports or deletes everything, and the regime that applies if anything leaves the Mac |

If persistence took GRDB (`references/stack-macos.md` §8), §2 is SQL-shaped tables as on web.

### cli

The macos sections, with §2 as: the config file with every key (type, default, the environment
variable that overrides it), the state and cache directories with every file in them, and every
credential — where it is read from, in which order, and where it is stored when the tool stores
it. §6 adds what the tool sends over the network and to whom; §7 is usually short, and says so.

---

## `NN-admin.md` — the operator surface

Shape · access · **screens, one per section** · cross-cutting behaviour · testing.

Each screen: what it lists, what it filters by, what can be edited, what cannot and why, what an
action does downstream. If it replaces an existing tool, the acceptance test is walking the old
tool's screens one by one against the new ones, and say so.

---

## `NN-integrations.md` — the ports and their adapters

One section per provider, each with: what we send, what it answers, the failure modes that are
specific to it, the retry policy, the idempotency key, and what the fake does in tests. Then a
cross-cutting section for the rules that apply to all of them.

State the client policy and defend it: hand-written clients over `fetch` rather than vendor SDKs,
because we use a fraction of each API, the failure modes are ours to handle, and an injectable
`fetch` is the whole testing strategy.

---

## `NN-auth.md` — identity, sessions, authorisation

Why this mechanism and not a library (or the reverse) · configuration · roles, as a table of what
each may do · claims and the token · every flow end to end · migration of existing credentials, if
any · operators and API keys · what could go wrong · tests.

Two properties to state explicitly: authorisation is re-read per request rather than carried in the
session, and a refusal never reveals which half of a credential was wrong and costs the same
whether or not the account exists.

---

## `NN-design.md` — design direction

Only when the UI's look is a product decision.

Diagnosis of what to avoid, and why · the design thesis in one paragraph · the rule set per surface
(marketing and product are not the same) · typography with the actual faces and scale · color as
tokens with contrast ratios · space, shape and surface · imagery and motion · the component and
library stack · data visualization · copy rules · **a review checklist** somebody can run against a
screen · the decisions taken here, as `D-xx`.

---

## `NN-billing.md` — tenancy and billing

What a tenant is, exactly, and what creates one · the install flow step by step · what is billed
and where the prices live (**in the payment provider and nowhere else**) · reconciling rather than
reacting, applied to money · where the trial clock lives · what happens when nobody pays, stated as
suspension rather than deletion · webhook configuration · environment · seats · comped accounts.

---

## `NN-migration.md` — migrating from the old system

The migrator as a program, not a runbook of manual steps: resumable, idempotent, verifiable.

Sections: the migrator · each source → target mapping, field by field, with what happens to a field
that does not map (it is a reject, and rejects fail the run) · reference data first · credentials ·
files · **verification**, as counts and spot checks and a replay of real historical inputs through
both systems · the cutover runbook with a named point of no return · rollback · behaviour that
changes at cutover · tests.

---

## `NN-engineering-practices.md` — how we work

Principles · toolchain · branches and commits · **the delivery loop** · the check suite, job by
job · hooks · local development · environments · secrets · definition of done.

`references/workflow.md` is the source for the middle three sections. Adapt the commands to the
project; do not soften the gates. In particular this document must state, unambiguously:

- **The loop**, as the Mermaid diagram and command table in `workflow.md` §1: a worktree per task → implement code and tests
  and the documents the change touches → push, which runs the gate → open the pull request → wait →
  squash merge → remove the worktree and the branch → next task. One task in, one merged commit
  out.
- **How worktrees coexist**, from `workflow.md` §1.1: what the `.config/wt.toml` hooks do, what
  each worktree gets of its own, and the two commands kept out of the loop.
- **Which repository** pull requests are opened against, that `main` is protected and is the
  only merge target, and **what protected means**: the settings and the ruleset from
  `references/repository.md` §1 and §2 as a table of setting, value and why, applied by
  `scripts/configure-repo.sh`. On a private repository without a paid plan, that the ruleset is
  not enforced and what that leaves.
- **Where the check suite runs** — a hosted workflow or `scripts/ci.sh` behind the pre-push hook
  (`.husky/pre-push` on web, lefthook on macos) —
  and what that choice costs. If it is the local hook, say plainly that `--no-verify` is the way
  past the only gate there is.
- **The check suite job by job**, with **one job per test layer** (unit, integration, end to end),
  and that a job whose subject does not exist yet skips *with its reason printed* rather than
  failing or passing silently. When the checks are hosted, the jobs of `.github/workflows/ci.yml`
  (`references/repository.md` §4), each named as the ruleset requires it.
- **The pull request body's four sections**: what changed, why (milestone and `FR-xx`), how it was
  verified, and the risk if it is wrong.
- **The auto-merge conditions**, as a checklist every item of which must hold.
- **What to do when a check fails**: read the failing job, fix the actual cause, push. Three
  attempts maximum, then label `needs-human`, write down what was tried, and stop. **Never "fix" a
  check by deleting a test, skipping a test, loosening a lint rule, widening a type, adding `any`,
  pushing with `--no-verify`, or re-running and hoping.**
- **When to stop and come back to a human**: the milestone is done, `needs-human` was applied, a
  decision in the register turns out to be wrong, or the work needs a `D-xx` that does not exist.
  Those four.

---

## `NN-testing.md` — testing

Only as its own document when there are **properties to prove**, not just layers to list.

Layers, as a table of layer · tool · what it runs against · whether it is in the default test run ·
fixtures and where they come from · **the properties that must always hold**, asserted over
generated inputs rather than as a handful of examples · end to end · non-functional · what is not
tested, and why.

The principle underneath: **do not mock our own modules.** Providers are replaced at the network
edge — an injected `fetch`, a small local server — never at the port. If a test needs to mock
something we wrote, the boundary is wrong.

---

## `NN-roadmap.md` — roadmap and risks

Milestones `M0` upward. Each ends in something **demonstrable** — not "the schema is done" but "a
request to the new route produces the right rows and the right side effects". Each is a series of
pull requests, not one.

Every milestone has a **Done when** sentence that is checkable by someone who did not write it.

`M0` always includes the repository: create it, land `.github/` (the workflow, Dependabot, the
pull request template), run `scripts/configure-repo.sh`, and prove the gate by opening a pull
request that a deliberately failing check blocks. Its **Done when** names that proof.

No dates. Then: dated tasks *after* launch, for the things whose failure mode is being forgotten
(a licence to cancel, a fallback to delete, a compatibility route to remove) · the next versions ·
a **risks table** of risk · impact · what we do about it, where the third column is a mechanism
already in the plan and not a promise to be careful · definition of done for the project.

---

## `NN-stack.md` — the stack

Written **to be read from outside**. The rest of `docs/` explains the product; this one explains
the choices it happens to be made of, so a later project can inherit the reasoning rather than
re-derive it.

Open with how to read the **Cost to replace** column — Low (behind an interface we own), Medium (a
day or two of mechanical change), High (reaches into how the product is written). That column
matters more than the version: a low-cost dependency can be chosen quickly and revisited cheaply; a
high-cost one is a decision that will still be true in three years.

Then one table per layer. **web:** language and runtime · backend · frontend · provider
integrations · testing · tooling · infrastructure · observability. **macos:** language and UI ·
project and packages · persistence · networking and providers · testing · tooling · distribution ·
observability. **cli:** language and runtime · command line (parser, prompts, output) ·
configuration and credentials · networking and providers · testing · tooling and build ·
distribution · observability. Every row: what · version · **why** · cost to
replace. Close with **what was deliberately not used**, which is the section worth exporting most,
because an absence leaves no trace in a lockfile.

Say explicitly that versions are the ones pinned today and will drift, and that the reasoning is
what should not.

---

## `NN-provider-setup.md` — providers and configuration

Written for someone doing it for the first time, in order, field by field: which screen, which
permission, which event, which scope, which URL goes where, and what to do after the first install.

Then: first run · **every environment variable**, as a table of name · what it is · where it comes
from · which process needs it · what breaks without it · rotation, per secret · and a closing
section of gaps to know about before you blame the configuration.

Say which credentials are **not** needed to develop, and what stands in for them locally.

On **macos** the document covers the signing certificate (creating it, exporting the PKCS#12, the
CI secrets that hold it), the update signing key, any token the app reads, and the first launch
(Gatekeeper, notification permission, launch at login). Environment variables are only the CI
secrets; the app itself reads none.

On **cli** the document covers the token for each API the tool calls (how a user creates one, its
scopes, the environment variable and the `auth login` path), and the release side: npm trusted
publishing configured on the package, and the Homebrew tap's token when there is one.

---

## `NN-distribution.md` — signing, releases and updates *(macos, cli)*

Only when earned (`references/doc-set.md`). Signing identity and why it is stable · the release
pipeline from a merged release pull request to the published assets · versioning and the build
number · every release asset and what it contains · the update flow end to end, with **every check
the app makes before replacing itself, in order** · what happens when a check fails · development
builds and what they skip · how to recover a broken install by hand.

On **cli**: every artifact and where it is published (the npm package and its provenance, each
binary and its target, the Homebrew formula), how the release workflow builds and publishes them,
how each install path upgrades, and how a bad release is deprecated or yanked.
