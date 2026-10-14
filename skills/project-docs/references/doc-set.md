# The document set

## Root files — always all three

| File | What it is |
|---|---|
| `PROJECT.md` | The seed. Problem, proposal, principles, scope, document map, decision register |
| `CLAUDE.md` | The working agreement for anyone — human or agent — writing code here |
| `README.md` | Running the code. Nothing else; it points at `PROJECT.md` for everything else |

`docs/` holds the plan. Numbered, two digits, `NN-kebab-name.md`.

## The spine — always, in this order

| # | File | Settles |
|---|---|---|
| 01 | `01-product.md` | Personas, jobs to be done, the `FR-xx` / `NFR-xx` inventory, success metrics, non-goals |
| 02 | `02-<domain core>.md` | The one thing this product actually does, specified to the level of a test |
| 03 | `03-architecture.md` | Components, boundaries, the request path, jobs, deployment |
| 04 | `04-data.md` | Every table, column, constraint, index; retention; what is deliberately not stored; security; privacy |

**`02` is named for the project's centre of gravity**, never `02-domain.md`. In the reference set
it is `02-request-routing.md` (a marketplace whose product is the routing rule) and
`02-slack-experience.md` (a bot whose product is the message). Ask: if this system got exactly one
thing right, what would it be? That is document 02, and it is usually the longest one.

## Conditional documents — include only when the project earns them

Numbered after `04`, in this order, skipping the ones that do not apply.

| File | Include when | Otherwise |
|---|---|---|
| `NN-admin.md` | There is an internal operator surface with more than two screens | A `§` in `03-architecture.md` |
| `NN-integrations.md` | Three or more external providers, each with its own failure modes | A `§` per provider in `03-architecture.md` |
| `NN-auth.md` | Roles, claims, sessions or a password migration are non-trivial | `04-data.md` §Security |
| `NN-design.md` | There is a user-facing UI whose visual language is a product decision | Skip |
| `NN-billing.md` | Money changes hands, or the system is multi-tenant | Skip |
| `NN-migration.md` | The project replaces an existing running system | Skip |
| `NN-<domain module>.md` | A subsystem carries real product risk of its own — a scoring model, a pricing engine, a matching algorithm that did not fit in `02` | Fold into `02` |

## The tail — always, in this order, after the conditionals

| File | Settles |
|---|---|
| `NN-engineering-practices.md` | Toolchain, branches, commits, hooks, the check suite, local development, environments, secrets, definition of done |
| `NN-testing.md` | *Only when* the strategy has properties to prove, not just layers to list. Otherwise a `§` in engineering practices |
| `NN-roadmap.md` | Milestones with "Done when", risks, definition of done for the project |
| `NN-stack.md` | Every dependency, why it is there, what replacing it would cost, what was deliberately not used |
| `NN-provider-setup.md` | Registering each external provider field by field, and what every `.env` value is |

## Worked examples (fictional projects)

**A marketplace rewrite** (13 documents): product, request-routing, architecture, data, admin,
integrations, auth, migration, engineering-practices, testing, roadmap, stack, provider-setup.
Earned `admin` (replacing a hosted no-code admin), `integrations` (several providers), `auth`
(several roles plus a password migration), `migration` (it replaces a live system), `testing` (four invariants
asserted over generated input).

**A SaaS bot** (11 documents): product, slack-experience, architecture, data, gamification,
roadmap, design, engineering-practices, provider-setup, billing, stack. Earned `design` (the
dashboard's visual language is a product decision), `billing` (multi-tenant with subscriptions),
`gamification` (a scoring model with real cultural risk). No `migration`, no `admin` as its own
document, no separate `testing`.

## Numbering

Sequential from `01`, no gaps. Decide the full set in Phase 1 and number it once — renumbering
after the fact breaks every cross-reference in the set, and the cross-references are load-bearing.

A document added later takes the next free number and goes at the end, even if its subject would
have sorted earlier. The reference set does exactly this and it is the right trade: a stable path
is worth more than a tidy order.
