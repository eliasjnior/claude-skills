<!-- TEMPLATE. Spec: references/document-specs.md. Keep it short — an inventory is short. -->
# 01 — Product

## 1. Personas

| Persona | Who | What they need | What they hate |
|---|---|---|---|
| **<Name>** | <one line> | <what they need, concretely> | <the specific friction today> |

<!-- The last column is the one that produces requirements. If it is vague, the FRs will be too. -->

## 2. Jobs to be done

- When <situation>, I want <outcome>, so <consequence>.

## 3. Functional requirements

Priority: **P0** ships in v1.0, **P1** in v1.x, **P2** is a candidate for later.

### 3.1 <Subsystem>

| ID | Requirement | Prio |
|---|---|---|
| FR-01 | <one line, checkable, no "support" or "handle" without saying what> | P0 |

<!-- Number in tens per group so rows can be inserted later without renumbering.
     For a rewrite, add a column naming the file or feature each FR replaces. -->

### 3.n What is deliberately dropped

<!-- Rewrites only. Each with a reason. Then, in these words: anything not on this list and not
     implemented is a gap in this document. -->

## 4. Non-functional requirements

| ID | Requirement | Target |
|---|---|---|
| NFR-01 | <what> | <a number, with a percentile where it is a latency> |

## 5. Success metrics

| Metric | Baseline | v1 target |
|---|---|---|

Anti-metrics, watched to make sure we are not making things worse:

- <what would tell you the product made things worse>

## 6. Explicit non-goals

- <what this is not, stated so nobody proposes it twice>
