---
name: project-docs
description: Write a complete, opinionated project plan and documentation set from a project description — PROJECT.md, CLAUDE.md, README.md and a numbered docs/ spine (product, domain core, architecture, data, engineering practices, roadmap, stack, provider setup) on a fixed TypeScript monorepo baseline (pnpm, Turborepo, Biome, Zod, Drizzle, Postgres, with Elysia or Hono chosen per project), including the delivery loop of branch, pre-push gate, pull request and squash merge. Use when starting a new project, planning a rewrite, writing a spec or a technical plan, bootstrapping a repository, producing docs/ for an existing codebase, or when asked to "document this project", "plan this project", "write the docs", "montar a documentação", "criar o plano do projeto".
---

# Project documentation set

Turn a project description into the document set two reference projects already use: a
`PROJECT.md` that settles the problem and every decision, a `CLAUDE.md` working agreement, a
`README.md` that only covers running the code, and a numbered `docs/` spine.

The output is a **plan written as if the system already existed** — specified to the level of a
test, with the reasoning for each choice attached to it, so the plan can be handed to an agent or
a new engineer and executed without a conversation.

## What makes this different from "generate some docs"

Four properties. If the output does not have all four, it is not this skill's output:

1. **Every decision carries its reasoning and its reversal condition.** A `D-xx` register in
   `PROJECT.md`, where a closed decision keeps its ID and gains the argument — including the
   option that was rejected and why — so nothing is re-litigated by accident.
2. **Requirements are inventoried and identified.** `FR-xx` / `NFR-xx` with priorities, referenced
   by the roadmap and by the test plan, so "done" is checkable rather than felt.
3. **The stack is fixed, not chosen fresh.** A known-good TypeScript monorepo baseline carries
   over; only the genuinely project-dependent slots are decided, and each one is decided in the
   register with its alternative named.
4. **Absences are recorded.** "What was deliberately not used", with reasons. An absence leaves no
   trace in a lockfile, so it has to leave one in the plan.

## Process

Work through the phases in order. Do not skip Phase 1 — a doc set agreed in ten lines is worth
more than five thousand lines written against the wrong shape.

### Phase 0 — Intake

Read `references/intake.md`. Extract from the user's description everything it already answers.
Ask only about what is still missing **and** would change the document set or a baseline slot.
Anything else, decide yourself and record it as a `D-xx` with your reasoning — a decision written
down with an argument is easy to overturn; a question is a stall.

### Phase 1 — Choose the doc set

Read `references/doc-set.md`. Assemble the spine plus the conditional documents this project's
shape earns. Then show the user, in one short message:

- the file list with its final numbering;
- the two-line summary of what the project is;
- the baseline slots you are filling differently from the default, with why.

Get a yes. Then write.

### Phase 2 — `PROJECT.md`

Read `references/root-files.md` and `references/decisions.md`. `PROJECT.md` is the seed: every
later document elaborates something it states. Write it first and completely, including the full
`D-xx` register — the register is what the rest of the set is consistent with.

### Phase 3 — The spine, in order

`01-product.md` → `02-<domain core>.md` → `03-architecture.md` → `04-data.md`.

They depend on each other in that order: the FR inventory decides what the domain core must do,
the domain core decides the boundaries, the boundaries decide the schema. Read
`references/document-specs.md` for what each one owes, and `references/voice.md` before writing
the first sentence of prose.

### Phase 4 — The remaining documents

The conditional documents, then engineering practices, roadmap, stack, provider setup.

These are independent of each other once the spine exists, so they may be written in parallel by
subagents — give each one the finished `PROJECT.md`, its entry in `references/document-specs.md`,
and `references/voice.md`, and require it to return the file content only. Write `NN-stack.md`
yourself, last of these: it has to agree with every dependency the others named.

### Phase 5 — `CLAUDE.md` and `README.md`

Both index the finished set, so both come after it. `CLAUDE.md` is the working agreement — the
non-negotiables, the boundary table, the commands, and **the delivery loop from
`references/workflow.md`**, including the repository every pull request is opened against.
`README.md` covers running the code and nothing else; it points at `PROJECT.md` for the rest.

### Phase 6 — Consistency pass

Mandatory. Check, and fix what fails:

- every path referenced in prose exists in the set;
- the doc map in `PROJECT.md` §5 lists exactly the files that exist, with no extras;
- every `D-xx` referenced in a document exists in the register, and every register entry marked
  "Closed" has an argument and, where it could ever change, a "Revisit if";
- every `FR-xx` appears in the roadmap milestone that delivers it;
- every dependency named anywhere appears in `NN-stack.md` with a reason and a replacement cost;
- no document contradicts another about a name, a route, a table or a boundary;
- section numbers referenced as `§n` point at a section that exists.

### Phase 7 — Scaffold (only when asked)

`references/stack-baseline.md` §9 has the actual toolchain files the documents promise —
`package.json`, `pnpm-workspace.yaml`, `turbo.json`, `biome.json` with the boundary rules,
`tsconfig.base.json`, `commitlint.config.js`. `references/workflow.md` §4 has `scripts/ci.sh` and
the hooks that run it. Emit them only if the user asks for a scaffold; the default deliverable is
the plan.

### Phase 8 — Build it (only when asked)

When the user asks you to implement the plan rather than only write it, **read
`references/workflow.md` and run the loop it specifies**, one task at a time:

> branch → implement code, tests and the documents the change touches → push, which runs
> `scripts/ci.sh` through `.husky/pre-push` → wait for it green → `gh pr create` against the
> repository named in `CLAUDE.md` → wait for checks → `gh pr merge --squash --delete-branch` →
> next task

Continue until the milestone's **Done when** is true, updating the "What exists today" table in
`CLAUDE.md` as part of the last pull request of the milestone.

Do not skip the gate, do not open a pull request against a repository the user did not name, and
do not merge past the auto-merge conditions in `workflow.md` §6. Three failed attempts on the same
check means `needs-human` and stop. The four reasons to come back to the user are in §8 of that
file; "this task was hard" is not one of them.

## References

| File | Read it when |
|---|---|
| `references/intake.md` | Phase 0 — what to extract, what to ask, what to decide yourself |
| `references/doc-set.md` | Phase 1 — the spine, the conditional documents, numbering |
| `references/document-specs.md` | Before writing any document — what each one owes |
| `references/voice.md` | Before writing any prose. The rules that make these documents what they are |
| `references/decisions.md` | The `D-xx` register: format, what belongs in it, how a decision closes |
| `references/root-files.md` | `PROJECT.md`, `CLAUDE.md`, `README.md` |
| `references/stack-baseline.md` | The fixed technology baseline, the variable slots, and the scaffold files |
| `references/workflow.md` | The delivery loop: the gate, the pull request, the merge, and when to stop. Source for `CLAUDE.md` and engineering practices — and the procedure itself in Phase 8 |
| `references/calibration.md` | Illustrative passages in the target voice, about fictional products. Read when the prose is coming out generic |

`templates/` holds skeletons for the documents whose shape is hardest to get right. They are
section scaffolds with guidance, not fill-in-the-blank forms — a template section you have nothing
real to put in is a section to delete, not to pad.

## Rules that hold throughout

- **Everything is in English** — documents, identifiers, commit messages. Product copy may be
  another language when the users are; when it is, say so as a rule in `CLAUDE.md` and put the copy
  in data or a locale file, never inline.
- **Write the target, and say what is not built.** The documents describe the finished system.
  A "What exists today" table in `CLAUDE.md` carries the difference, and it is the only place that
  does, so there is one thing to update rather than thirteen.
- **No dates on a plan written before the first line of code.** Milestones are ordered and have
  dependencies; those are the real content. Dated tasks exist only for things whose failure mode is
  being forgotten — a licence to cancel, a fallback to delete.
- **A table cell that states a choice without a reason is a defect.** So is a requirement without an
  ID, a milestone without a "Done when", and a dependency without a replacement cost.
- **Every change reaches `main` through a pull request**, behind a check suite that ran before the
  pull request existed. The plan says which repository, which gate, and what is never a fix for a
  red check. `references/workflow.md` is the authority and the generated docs carry it.
- **Prefer deleting a section to padding it.** These documents are dense because nothing filler
  survived; length is a consequence, never a target.
