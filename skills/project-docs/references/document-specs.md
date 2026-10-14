# Document specifications

What each document owes. Sections are the reference set's, numbered so `§n` references work.
A section with nothing real in it is deleted, not padded.

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

- **The flow end to end**, as a numbered walk or a diagram, with what is true after each step.
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

The stack belongs here as a `§` only in summary form, pointing at `NN-stack.md`, which owns it.

---

## `04-data.md` — Data, identity and privacy

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
document, not a substitute for it.

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

- **The loop**, as the diagram in `workflow.md` §1: branch → implement code and tests and the
  documents the change touches → push, which runs the gate → open the pull request → wait → squash
  merge and delete the branch → next task. One task in, one merged commit out.
- **Which repository** pull requests are opened against, and that `main` is protected and is the
  only merge target.
- **Where the check suite runs** — a hosted workflow or `scripts/ci.sh` behind `.husky/pre-push` —
  and what that choice costs. If it is the local hook, say plainly that `--no-verify` is the way
  past the only gate there is.
- **The check suite job by job**, and that a job whose subject does not exist yet skips *with its
  reason printed* rather than failing or passing silently.
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

Then one table per layer: language and runtime · backend · frontend · provider integrations ·
testing · tooling · infrastructure · observability. Every row: what · version · **why** · cost to
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
