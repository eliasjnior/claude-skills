# Intake

The user gives a project description. It is almost never complete. The job of this phase is to get
to a document set without turning it into an interrogation.

## First: the profile

Decide it before anything else, because it decides which baseline you read (`SKILL.md` §Profiles).
Usually the description settles it in one word: "menu bar", "Mac app", "native", "SwiftUI",
"notifications on my Mac" mean **macos**; "API", "dashboard", "SaaS", "bot", "site", "webhook" mean
**web**; "CLI", "command", "terminal", "`npx`", "a tool I run in CI" mean **cli**. Ask only when it
truly reads two ways, and then as the first question of the batch.

## A sibling project is the baseline

When the user points at a project of theirs as the model ("like my other app", "the same shape as
`<repo>`"), **read it before writing anything**: its layout, its manifests, its hooks, its CI, its
release setup, and its `CLAUDE.md` and `docs/`. Its choices win over the baseline file wherever the
two differ, because they were made for the same person and already survived contact with code.
Record each difference as a `D-xx` that names the sibling as the reason, and carry over the parts
that are not in the baseline at all (an updater, a signing script, a snapshot mode) as decisions
too, with "copied, not shared" or "shared" decided explicitly.

## The one thing you may not infer

**The repository every pull request is opened against.** Ask for it, or write
`<to be determined>` into the one place `CLAUDE.md` keeps it and make filling it in the first task
of `M0`. Never guess a remote, and never open a pull request against a repository the user did not
name. See `references/workflow.md` §2.

## The questions that change the output

Answer each from the description if you can. These are the only ones worth asking about, because
each one changes either the document set or a baseline slot. Q9 applies to the macos and cli profiles.

| # | Question | What it decides |
|---|---|---|
| Q1 | **What does this replace?** Nothing, a manual process, or a running system | `NN-migration.md`; whether the plan's first principle is parity |
| Q2 | **Who touches it?** End users, internal operators, developers, machines | `NN-admin.md`, `NN-design.md`, the personas table |
| Q3 | **What is the one thing it does?** The operation the product would be judged on | The name and content of document `02` |
| Q4 | **Does money change hands, and is it multi-tenant?** | `NN-billing.md`; `org_id` in every table from day one. On **macos** and **cli** it is almost always no, and then skip it without asking |
| Q5 | **Which external systems does it speak to?** | `NN-integrations.md`, `NN-provider-setup.md`, the ports-and-adapters shape |
| Q6 | **Is there a UI, and is its look a product decision?** | `NN-design.md`; whether Next.js is in the stack at all |
| Q7 | **What is the shape of the work?** Request/response, scheduled, event-driven, long-running | **web:** queue vs transactional outbox, how many processes, the deployment topology. **macos:** polling vs push, what runs while the app is closed, whether a background agent is needed. **cli:** one-shot commands vs a long-running watch mode, interactive vs scripted, whether it is run by people, by CI, or both |
| Q8 | **Which repository do pull requests go to?** | The `Repository` block in `CLAUDE.md`, and every `gh pr create` in the delivery loop |
| Q9 | **Who installs it?** *(macos, cli)* Only the author, a few people, or the public, and on which systems | **macos:** the signing and update slots: self-signed with our own updater, Developer ID with notarization, or the App Store, and whether the sandbox applies. **cli:** the distribution and platforms slots: npm, or binaries with a Homebrew tap, and whether Windows is in the matrix |

## What to ask, and what to decide yourself

**Ask** when two answers would produce materially different document sets, and the description
gives you nothing to prefer one. Batch the questions into one message. Three is a lot; five is too
many.

**Decide yourself** for everything else, and record it as a `D-xx` with the reasoning and a
"Revisit if". This is the default. A decision written down with an argument costs the user ten
seconds to overturn; a question costs them a context switch.

Specifically, decide yourself: every baseline slot in the profile's baseline file, naming
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
equivalent, the routes, `package.json`, the deployment config; on macos, `project.yml`,
`Package.swift`, the `Makefile` and the release workflow. The plan then describes the target
and `CLAUDE.md`'s "What exists today" table carries the difference.

Where the plan and the code disagree about what the product does, **the code is right and the plan
has a bug**. Say that in `CLAUDE.md`, in those words.
