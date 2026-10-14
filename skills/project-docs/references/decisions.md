# The decision register

`PROJECT.md` §Decisions. A numbered table, `D-01` upward, that outlives the questions it answers.

## Why it exists

Two failure modes, both expensive, both prevented by the same table:

- A settled question gets re-opened months later because nobody remembers the argument.
- An unsettled question gets silently answered by whoever writes the code first.

So: an open decision carries a recommendation, a closed one keeps its ID and gains the reasoning.
Nothing is ever deleted from the register.

## Format

| ID | Decision | Resolution | Impact |
|---|---|---|---|

- **ID** — `**D-07**`, bold, never reused, never renumbered.
- **Decision** — the question in five to nine words. Strike it through when closed
  (`~~Stack and hosting~~`) so the table is scannable for what is still live.
- **Resolution** — `**Open.** Recommendation: …` or `**Closed — <the answer>.**` followed by the
  argument.
- **Impact** — `High`, `Medium`, `Low`, or `Resolved`. What it costs to get wrong, not how hard it
  was to decide.

## What a closed resolution owes

1. **The answer, in the first clause, in bold.** A reader skimming the column gets it from the
   first six words.
2. **The strongest alternative, named.** Not "we considered other options" — the actual name, and
   the specific property of *this* project that decided against it.
3. **A reversal condition**, where one could exist: `**Revisit if** …` / `**Revisit when** …`.
4. **A pointer** to the document that elaborates it, by path and section.

A closed decision that reverses an earlier closed decision says so and says why — the reference
set does this repeatedly (`Reversed from an earlier choice of …`, `Reopened and closed again:`) and
it is more useful than a clean-looking table.

## What belongs in the register

- Anything that would be expensive to change later: runtime, framework, database, identity, queue,
  hosting, tenancy model.
- Anything where a reasonable engineer would pick differently: naming, conventions, build vs buy,
  where a boundary sits.
- Anything the user was specific about — closed on arrival, with "the user named it" as the reason.
- Names of core entities, and any name carried over from a previous system that was not clear
  enough to keep. Rename once, while it is still only documentation, and record every rename with
  the reason. This is the cheapest edit in the project's life and the most expensive one to defer.

## What does not

Implementation details a PR can settle. If the answer is discoverable from the code in thirty
seconds and changing it touches one file, it is not a decision, it is a line of code.

## Impact ratings

| Rating | Meaning |
|---|---|
| **High** | Getting it wrong means a rewrite, or it decides how the product feels to use |
| **Medium** | A day or two of mechanical change, or a bounded product consequence |
| **Low** | Behind an interface we own; swap the implementation, keep the callers |
| **Resolved** | Closed. Kept for the reasoning |

## Referencing

Cite decisions inline everywhere: `(D-03, D-23)`, `Both halves of D-23's one process run`. Every
`D-xx` cited anywhere in the set must exist in the register — this is checked in the consistency
pass.

## A worked entry

> | **D-07** | Job runner: in-process or separate | **Closed — in-process, one deployable.** The
> worker is a loop over `SELECT … FOR UPDATE SKIP LOCKED` in the same container as the HTTP server,
> guarded so that N replicas do not double-send. Volume does not justify a second deployable, and a
> single image is a smaller cutover. Splitting it later is a compose change, not a rewrite — the
> worker is already a separate entry point. | Medium |

Answer first, in bold. Mechanism. The reason volume decides it. The escape hatch, and why taking it
later is cheap. Sixty words.
