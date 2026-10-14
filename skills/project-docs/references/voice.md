# Voice

The reference documents read the way they do because of a small number of habits. These are the
habits, stated as rules. They are the highest-value part of this skill: structure can be copied
from a template, voice cannot.

---

## 1. State what the document settles, in the first two lines

Every document opens with one or two lines saying what question it closes, then goes straight in.
No "this document will describe", no table of contents, no restating the project.

> `# 11. The stack`
> `Every technology this repository depends on, why it was chosen, and what replacing it would cost.`

## 2. Tables carry decisions; prose carries reasoning

A table is for things that line up in columns: requirements, dependencies, states, boundaries,
milestones, environment variables. Anything that needs an argument goes in prose under the table,
or in a wide "Why" column that actually argues.

A cell that says `yes`, `high`, or a package name and nothing else is a defect. `package.json`
already lists the names; the document exists for the reasons.

## 3. Name the rejected option, and why it lost

This is the single strongest habit in the reference set. Every significant choice names its
strongest alternative and the specific thing that decided against it — not a generic tradeoff, the
actual property of this project that broke the tie.

> React Admin over an auto-generated data provider was evaluated and rejected: half of this admin
> is not CRUD (coverage editing with per-subject state and neighbourhood sets, request delivery
> inspection, template preview, plan management), and a generic data provider forces the database to be
> readable by the browser — exactly the coupling D-03 removes.

The alternative is evaluated on its own strongest argument, and it loses on a property of *this*
project rather than on a general opinion about the tool.

And keep a "What was deliberately not used" table. An absence leaves no trace in a lockfile, so
the only place it can leave one is here.

## 4. Attach a reversal condition

A closed decision that could ever change carries **Revisit if** / **Revisit when**, naming the
observable event that reopens it.

> **Revisit when** a second person commits, or when the repository goes public — at which point the
> honest answer is a workflow, and the script is already the thing it would run.

A decision with no reversal condition is either genuinely permanent or under-examined. Which one
it is should be visible.

## 5. Be concrete, at the level of a test

Not "the system matches requests to agencies" but the actual rule, the actual ordering, the actual
tie-break, with worked examples. Not "good performance" but `p99 < 500ms`. Not "small PRs" but
"under ~400 changed lines, excluding lockfiles, generated migrations and snapshots".

Where a shape is easier to see than to read, draw it — ASCII before/after diagrams, message
mockups over time, request paths. The reference set uses these heavily and they carry more than the
paragraphs around them.

## 6. Say the uncomfortable thing out loud

Known drift, a gate held only by discipline, a column that decides nothing, a test layer that is
blocked rather than written — all of it is written down, in the document, in the same voice as
everything else.

> **What is lost is real**: the checks are enforced by the author's own machine, so
> `git push --no-verify` is a way past them and a green PR proves only that whoever pushed it did
> not use that flag.

A plan that only contains good news is a plan nobody can act on.

## 7. Cross-reference, never restate

A fact lives in exactly one document. Everywhere else links to it by path and section:
`docs/03-architecture.md` §8.2. When two documents would both need to explain something, one of
them is wrong about its scope.

## 8. The system is the subject

Third person, present tense, declarative. "The worker drains the outbox." Not "we will implement a
worker that will drain". Second person appears only in operational instructions — a runbook, a
setup walkthrough.

No hedging (`should probably`, `might want to`), no marketing (`seamless`, `powerful`,
`best-in-class`, `robust`), no filler openers (`It's worth noting that`, `In order to`).

## 9. Numbers are specific and sourced

Versions are the ones pinned today, and the document says so: "Versions are the ones pinned today.
They will drift; the reasoning is what should not." Targets are numbers with a percentile. Coverage
is a threshold that fails a build.

## 10. Formatting

- Wrap prose at 100 columns. It matches the formatter's line width and makes diffs readable.
- `# NN — Title` for document headings (the reference set uses both `—` and `-`; pick one and hold
  it across the set). `## n. Section` numbered, so `§n` references work.
- Backticks for every path, identifier, command, table name, route and environment variable.
- Bold for the load-bearing clause of a paragraph, not for emphasis generally.
- Markdown links with the real relative path, so they resolve in an editor and on a forge.
- The reference set uses em dashes freely. Match it.

## 11. Length

Documents in the reference set run 150 to 1000 lines. That range is a consequence, not a target:
`01-product.md` is short because an inventory is short, `03-architecture.md` is long because it
carries the whole shape of the system.

Write what the document owes and stop. If a section has nothing real in it, delete the section —
an empty "Observability" heading is worse than no heading, because it reads as answered.

---

## Failure modes to check for before delivering

| Symptom | What it means |
|---|---|
| Sections that could belong to any project | The description was not converted into specifics. Go back to the domain. |
| Every decision is "closed" with no alternative named | Choices were assumed, not made. |
| No "Revisit if" anywhere | Same. |
| A dependency table that is a list of names | The "why" column was skipped. |
| Two documents explaining the same mechanism | A scope boundary is wrong. |
| A roadmap milestone with no "Done when" | It is a heading, not a milestone. |
| No bad news anywhere | Rule 6 was skipped. |
