# Intake

The user gives a project description. It is almost never complete. The job of this phase is to get
to a document set without turning it into an interrogation.

## The one thing you may not infer

**The repository every pull request is opened against.** Ask for it, or write
`<to be determined>` into the one place `CLAUDE.md` keeps it and make filling it in the first task
of `M0`. Never guess a remote, and never open a pull request against a repository the user did not
name. See `references/workflow.md` §2.

## The eight questions that change the output

Answer each from the description if you can. These are the only ones worth asking about, because
each one changes either the document set or a baseline slot.

| # | Question | What it decides |
|---|---|---|
| Q1 | **What does this replace?** Nothing, a manual process, or a running system | `NN-migration.md`; whether the plan's first principle is parity |
| Q2 | **Who touches it?** End users, internal operators, developers, machines | `NN-admin.md`, `NN-design.md`, the personas table |
| Q3 | **What is the one thing it does?** The operation the product would be judged on | The name and content of document `02` |
| Q4 | **Does money change hands, and is it multi-tenant?** | `NN-billing.md`; `org_id` in every table from day one |
| Q5 | **Which external systems does it speak to?** | `NN-integrations.md`, `NN-provider-setup.md`, the ports-and-adapters shape |
| Q6 | **Is there a UI, and is its look a product decision?** | `NN-design.md`; whether Next.js is in the stack at all |
| Q7 | **What is the shape of the work?** Request/response, scheduled, event-driven, long-running | Queue vs transactional outbox; how many processes; the deployment topology |
| Q8 | **Which repository do pull requests go to?** | The `Repository` block in `CLAUDE.md`, and every `gh pr create` in the delivery loop |

## What to ask, and what to decide yourself

**Ask** when two answers would produce materially different document sets, and the description
gives you nothing to prefer one. Batch the questions into one message. Three is a lot; five is too
many.

**Decide yourself** for everything else, and record it as a `D-xx` with the reasoning and a
"Revisit if". This is the default. A decision written down with an argument costs the user ten
seconds to overturn; a question costs them a context switch.

Specifically, decide yourself: every baseline slot in `references/stack-baseline.md`, naming
conventions, the roadmap's milestone boundaries, testing layers, the repository layout, and
anything the reference projects already settled the same way twice.

## Reading a thin description

A one-paragraph description usually still answers Q3 and Q5 implicitly, and it always answers Q1
by omission. Extract:

- **Nouns that recur** — those are the entities, and they become `04-data.md` tables. Settle their
  names *now*, as a `D-xx`, before anything is written; renaming an entity across thirteen
  documents is the most expensive edit in this set.
- **The verb in the middle** — that is document `02`.
- **Who complains today** — that is the personas table and the problem statement.
- **Anything the user was specific about** — a technology, a provider, a constraint, a name. That
  was specific for a reason. It is a closed decision, not a suggestion, and the register should say
  so: "Closed — the user named it."

## What the problem statement needs

`PROJECT.md` §1 is not a summary of the description. It is the specific, checkable failure of
whatever exists today — the query that cannot be expressed, the integration that broadcasts events
when the team needs state, the manual step that is done wrong under pressure.

If the description does not contain one, find it by asking what happens today and what it costs.
A plan whose problem statement is "there is no system yet" produces documents with nothing to
argue against, and it shows in every one of them.

## Existing codebase

If the project already has code, read it before writing: entry points, the schema or its
equivalent, the routes, `package.json`, the deployment config. The plan then describes the target
and `CLAUDE.md`'s "What exists today" table carries the difference.

Where the plan and the code disagree about what the product does, **the code is right and the plan
has a bug**. Say that in `CLAUDE.md`, in those words.
