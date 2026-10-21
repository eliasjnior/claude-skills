# The three root files

Each has a job the other two must not do. When two of them explain the same thing, one is wrong.

---

## `PROJECT.md` — the seed

Everything else elaborates something stated here. Written first, completely, including the whole
decision register.

```
# <Project> — <subtitle, when the project is a rewrite or a migration>

> A one-or-two-sentence statement of what it is, in a blockquote. Concrete enough that a
> stranger knows what the product does after reading only this.

<One paragraph of context: what exists today, what this repository is, what state it is in.>

---
```

| § | Section | Content |
|---|---|---|
| 1 | The problem | The **specific, checkable** failure of what exists today. Three to five bold-led paragraphs, each naming one failure with its mechanism and its cost. Not "it does not scale" — the query that cannot be expressed, the counter maintained by triggers that must not trigger each other, the integration that broadcasts events when the team needs state |
| 2 | The proposal | What replaces it. A before/after diagram, as a Mermaid `flowchart LR` with one subgraph per side, earns its place here more than anywhere else in the set. Then the concrete changes as a bullet list. Then, for a rewrite, **What does not change** — which is what makes it a migration rather than a redesign |
| 3 | Design principles | Numbered, ordered, bold-led, five to eight. **Tie-breakers**: when two options are defensible, the one higher on the list wins. Each must be capable of settling a real argument. "Write good code" settles nothing; "the database enforces what the database can enforce" settles a schema review |
| 4 | Scope | `v1.0` and what it contains, then the later versions, then **out of scope** — with the reason for each exclusion, and its reversal condition where it has one |
| 5 | Document map | A table of every file in `docs/` and what it settles. This is how a reader routes; it must match the directory exactly |
| 6 | Decisions | The `D-xx` register. See `references/decisions.md` |
| 7+ | Project-specific | A state legend, a naming table, a "how to use this plan" with the suggested refinement order. Include when there is something real to put in them |

The problem statement is the hardest section and the one that decides the quality of everything
downstream. A plan whose §1 is "there is no system yet" produces documents with nothing to argue
against, and it shows in all of them.

---

## `CLAUDE.md` — the working agreement

For anyone writing code here, human or agent. Written to be useful to any tool, so nothing in it is
specific to one.

| Section | Content |
|---|---|
| **What this project is** | Two sentences, then a routing table: *if you are about to do X, read Y*. Phrase the rows as tasks, not as topics — "touch sessions, roles or passwords", not "auth" |
| | Then, in bold: **a PR that changes behaviour described in `docs/` updates that document in the same PR.** Documentation drift is the failure mode of a plan this detailed |
| **What exists today** | A table of built vs not built. **The plan describes the finished system and this table carries the difference** — it is the only place that does, so there is one thing to update rather than thirteen. A PR that builds one of these updates it |
| **Non-negotiables** | Numbered, five to ten. The rules that are never traded away: the language everything is written in, that every change is a pull request, which package performs no I/O, what is never stored, what is never logged, what a hidden or restricted read path may never return |
| **Commands** | Every command a developer or an agent needs, with what it does. Including the ones the plan promises but that have nothing to run yet — say that they arrive with the code they act on |
| **Architecture in one screen** | A Mermaid diagram (`references/diagrams.md`). One screen, literally. It is the map somebody holds while reading a diff |
| **Package boundaries** | The table of may-import / must-never-import, and the sentence that it is enforced and fails a job rather than being a review comment. **web:** Biome's `noRestrictedImports`; note the sharp edges, exact-specifier matching and subpaths that are a new hole. **macos:** *Target boundaries*, enforced by SwiftPM's declared dependencies plus `scripts/check-imports.sh` for what the compiler cannot see. **cli:** the layers inside `src/`, enforced by Biome's rules on `src/core/**` |
| **Checking UI** | *macos.* An agent cannot capture the screen, so say how a view is checked: the `--snapshot <directory>` mode, what it renders, and where to extend it |
| **Conventions** | Types, exports, file names, naming per layer, error shape, logging, dates, money. The things a reviewer would otherwise have to say twice |
| **Testing** | The layer table, what is in the default run, the coverage threshold that fails a build, the properties that must hold, and "do not mock our own modules" |
| **Repository** | The remote every pull request is opened against, and that `main` is protected and is the only merge target. One place, named once. If it is not known yet, `<to be determined>` here and filling it in is the first task of `M0` |
| **The delivery loop** | The compressed version of `references/workflow.md`: the loop diagram, branch naming tied to milestones, commit convention, size budget, the four sections a body must state, the auto-merge checklist, and what to do when a check fails — three attempts, then `needs-human`. The list of things that are never a fix goes here **verbatim**; this is the file read at the start of every session, so it earns its space here more than anywhere else |
| **Local development** | The three commands, then the things that are surprising. **web:** why processes do not run in containers locally, what the dev script writes and when it refuses to, how several worktrees coexist (one per task, created with `wt switch --create`, ready through `.config/wt.toml`, with their own ports and database), what cleaning up requires. **macos:** `make bootstrap`, `make gen` and why the project is generated, which Xcode, why two worktrees' development builds must not run at once, how `make install` replaces the installed app. **cli:** `pnpm install`, `pnpm build`, and how to run the built tool against a scratch home directory so development never touches the real config |

Keep it under about 300 lines. It is read at the start of every session; length costs attention.

---

## `README.md` — running the code

The shortest of the three, and the only one written for someone who has not read the plan.

1. Title, the same blockquote as `PROJECT.md`, and two lines of what it is.
2. **Where the plan lives**, with links, and the sentence that this file only covers running the
   code.
3. Current state in two or three lines: what works end to end, what is not built, and where the
   authoritative table is.
4. Requirements — tool, version, note. On macos: macOS and Xcode versions, Homebrew, and that
   `make bootstrap` installs the rest. On cli: the Node majors it supports and the operating
   systems the matrix proves.
5. Getting started: the actual command sequence, copy-pasteable, that ends in a running system.
6. What the local stack gives you: the URLs, the ports, the seeded accounts and their passwords
   (and that they exist only locally). On macos: where the app keeps its files, how to reset them,
   and how to run the developer CLI. On cli: installing it, the first command to run, and where
   it keeps its config.
7. Commands, as a table.
8. The two or three operations that are otherwise surprising: changing the schema, reseeding,
   running several checkouts at once.
9. Repository layout, as a tree with one line per directory.
10. Contributing: every change is a pull request, including from the maintainer; the workflow is
    written down over there.

No badges, no feature list, no roadmap, no screenshots-as-substance. Those belong in the plan or on
a product page.
