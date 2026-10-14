<!-- TEMPLATE. Spec: references/document-specs.md. Usually 400–1000 lines when finished. -->
# 03 — Architecture

## 1. The central idea: <the property everything else serves>

<!-- One paragraph. "Reconcile, do not react." "One process, one database, one transaction."
     Everything below is downstream of this, and every later section should be recognisable as a
     consequence of it. -->

## 2. Repository layout

```
apps/
  <app>/        <one line>
packages/
  domain/       Pure product logic. Zero workspace dependencies, zero I/O
  …
```

## 3. Boundaries

| Package | May import | Must never import |
|---|---|---|

Enforced by <the lint rule>, with a message naming the rule and where it is written down. A
violation fails a job; it is not a review comment.

## 4. The request path

<!-- Middleware in its exact order, what each rejects and with what status, what reaches a
     handler. A numbered list or a diagram. -->

## 5. <The outbox | The queue>

<!-- What is written in which transaction, what drains it, retry and backoff, the idempotency key,
     what makes a replay safe. Cite the D-xx that chose this. -->

## 6. The scheduler

<!-- Every periodic job: cadence, timezone, what makes it safe to run twice, how a missed tick is
     recovered. -->

## 7. Ports and adapters

<!-- One interface per external system, the adapters behind it, and the fake used in tests. -->

## 8. Configuration

<!-- Where environment lives, how it is validated, which process gets which variable and why the
     others do not. -->

## 9. Storage

## 10. Observability

<!-- What is logged, what is never logged, what is measured. -->

## 11. Deployment

<!-- Images, processes, topology, what recreates what, and what is deliberately separate. -->

## 12. Open technical questions

<!-- The ones honestly still open, each pointing at its D-xx. -->
