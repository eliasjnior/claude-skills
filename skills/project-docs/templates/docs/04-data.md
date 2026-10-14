<!-- TEMPLATE. Spec: references/document-specs.md. Write SQL-shaped tables, not ORM code. -->
# 04 — Data, identity and privacy

## 1. Conventions

<!-- Naming, primary key type and why, timestamptz always, money and counters as integers,
     soft delete or not, and how the TypeScript ↔ SQL mapping is carried. -->

## 2. Core tables

### `<table_name>`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | `<type>` | no | | <why this key type> |

Constraints and indexes:

- `UNIQUE (<cols>)` — <the invariant it holds>
- `<index>` — serves <the query>

<!-- Prose under each table for the invariants the schema cannot express, and for anything a
     reader would otherwise have to ask about. -->

## 3. Derived data

<!-- Denormalized counters, views, materialized state. For each: what keeps it true, and in which
     transaction. Money-adjacent counters move in the transaction that caused them to move, or
     they do not move. -->

## 4. Retention

| Data | Kept for | Deleted by |
|---|---|---|

## 5. What we deliberately do not store

<!-- The most valuable section in this document. Each with the reason. -->

## 6. Security

<!-- Grants, row-level security, what the browser can reach, how secrets are held at rest. -->

## 7. Privacy (<LGPD | GDPR>)

<!-- Lawful basis, subject access, deletion path, what a deletion actually removes. -->
