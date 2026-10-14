# Pull request format

Shared by `/git-pr` and `/git-stack`.

## Title

Conventional format: `<type>: <description>`, for example `feat: Add user authentication`.

## Description

```
## Summary
[What this PR does]

## Context
[Why these changes were made, relevant background + Jira link]

## Changes
- [Main changes]

## Affected routes
[Table: route path | impact | notes (component)]

## Testing
[How to test the changes, if applicable]
```

- Include **Affected routes** only when the PR changes user-facing routes or pages (web apps, API endpoints). Leave the section out otherwise.
- Leave **Testing** out when there is nothing to test manually (docs, config).

## Formatting

- Write the body as raw Markdown, with no shell escaping: `$`, `"` and backticks appear as is, never as `\$`, `\"` or `` \` ``. Write it to a file and pass it with `--body-file`, never inline with `--body`.
- One line per paragraph or list item. Do not hard-wrap prose at a fixed width: GitHub keeps those line breaks, so the text renders as short, ragged lines instead of filling the width.

## Jira

When a Jira ticket is provided, fetch it through the Atlassian MCP server, link it in Context, enrich the description with its background, and add a label based on the ticket type.
