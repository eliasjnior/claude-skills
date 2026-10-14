# Commit format

Shared by `/git-commit`, `/git-pr` and `/git-stack`.

## Grouping

- Group changes into cohesive units of work, split by concern or feature when needed.
- Commit only what is already staged. If nothing is staged, stage the relevant files yourself, grouped logically.

## Message

Conventional Commits:

```
<type>(<scope>): <description>

<body: what changed and why (not how), plus relevant context or side effects>

Refs: PROJ-123   <- only when a Jira ticket is provided
```

- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore.
- The scope is optional; use it when the change is confined to one module or area.
- When a Jira ticket is provided, fetch it through the Atlassian MCP server, enrich the body with its context, and add the `Refs:` footer. Otherwise omit the footer.

## Sensitive files

Before staging, check the files for secrets. Never commit `.env*` files (except templates such as `.env.example`), private keys (`*.pem`, `*.key`, `id_rsa*`), credential files, or diffs containing tokens or passwords. If one is part of the changes, leave it out, tell the user, and suggest adding it to `.gitignore`.
