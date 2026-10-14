<!-- TEMPLATE. Spec: references/document-specs.md. Baseline: references/stack-baseline.md. -->
# NN — The stack

Every technology this repository depends on, why it was chosen, and what replacing it would cost.

This document exists to be **read from outside**. The rest of `docs/` explains <project>; this one
explains the *choices* <project> happens to be made of, so that a later project can inherit the
reasoning rather than re-derive it. A row here is only useful if it says why — a list of package
names is something `package.json` already provides.

Versions are the ones pinned today. They will drift; the reasoning is what should not.

---

## 1. How to read the "Cost to replace" column

| Cost | Meaning |
|---|---|
| **Low** | Behind an interface we own. Swap the implementation, keep the callers |
| **Medium** | A day or two of mechanical change, no product decisions |
| **High** | Reaches into how the product is written. Budget a project, not a chore |

The column matters more than the version. A dependency with a low replacement cost can be chosen
quickly and revisited cheaply; a high one is a decision that will still be true in three years, and
those are the rows worth arguing about before adopting.

---

## 2. Language and runtime

| What | Version | Why | Cost to replace |
|---|---|---|---|

## 3. Backend

## 4. Frontend

## 5. Provider integrations

## 6. Testing

## 7. Tooling

## 8. Infrastructure

## 9. Observability

## 10. What was deliberately not used

The rows worth exporting most, because an absence leaves no trace in a lockfile.

| Not used | Why |
|---|---|
