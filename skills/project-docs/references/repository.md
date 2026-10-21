# The repository on GitHub

`CLAUDE.md` says "`main` is protected and is the only merge target". This file is what makes that
sentence true: the repository settings, the ruleset on the default branch, the security features,
and the hosted workflows whose jobs the ruleset requires. Every profile uses it; the profile
changes the jobs, not the shape.

The plan carries it in two places. `NN-engineering-practices.md` §3 states the settings and the
ruleset with the reason for each, and §5 lists the hosted jobs next to the local gate's. The
roadmap's `M0` gets the tasks that apply it: create the repository, run
`scripts/configure-repo.sh`, land `.github/`.

---

## 1. Settings

One script applies them (§6), so they are reviewed as code and re-applied rather than clicked.

| Setting | Value | Why |
|---|---|---|
| Merge methods | Squash only | The pull request title becomes the one commit on `main`, which is why the title follows Conventional Commits and is checked |
| Squash commit message | Title and body of the pull request | The four-section body ends up in `git log`, where the next person looks |
| Auto-merge | Allowed | `gh pr merge --squash --auto` merges the moment the required checks pass, so the loop's wait step needs nobody watching |
| Delete branch on merge | On | The remote branch disappears with the merge. The loop's clean-up only has to prune and remove the worktree |
| Update branch | Allowed | A stale branch is brought up to date from the pull request page rather than by a local rebase |
| Wiki, Projects | Off | The plan lives in `docs/`, versioned with the code it describes. A second place for it drifts |
| Default `GITHUB_TOKEN` permissions | Read | A workflow asks for `write` per job, where the reason is visible |
| Dependabot alerts and security updates | On | A vulnerable dependency arrives as a pull request through the same gate as everything else |
| Secret scanning and push protection | On, when the repository is public | Free on public repositories, and a pushed secret is a rotated secret. On a private one it is a paid feature; gitleaks in the hook and in CI covers it |
| Labels | `needs-human`, and `goal:<milestone>` for each milestone in the roadmap | The loop applies them. `gh pr create --label` fails on a label that does not exist |

## 2. The ruleset on the default branch

A repository ruleset, not classic branch protection: it is one JSON document, it targets
`~DEFAULT_BRANCH`, and the script replaces it whole on every run.

| Rule | Why |
|---|---|
| Restrict deletions | `main` is not deletable, by anyone |
| Block force pushes | History on `main` is never rewritten |
| Require linear history | Follows from squash only, and says so where a reader of the rules looks |
| Require a pull request | Every change arrives through one. **Approvals: 0** when there is one committer, because GitHub does not let an author approve their own pull request and the rule would block every merge. **1** once there is a second committer |
| Resolve conversations before merging | A review comment is answered or explicitly dismissed, never scrolled past |
| Allowed merge method: squash | The settings say it; the ruleset enforces it |
| Required status checks | Every job of the hosted workflow, by job name (§4). Not "strict": requiring the branch to be up to date makes every merge invalidate every other open pull request, which is the wrong trade when agents run tasks in parallel. `main` runs the workflow again on push to catch the rare semantic conflict |
| Bypass actors | None. Not the owner, not an app |

**Rulesets on a private repository need a paid plan** (GitHub Pro for a personal account, Team for
an organization). On the free plan the script warns that the ruleset was not applied. The plan must
then say out loud what that leaves: the local pre-push gate is the only gate there is, and
`--no-verify` gets past it. That is the same sentence the "Where the check suite runs" slot
already requires.

## 3. Dependabot and the pull request template

`.github/dependabot.yml`, weekly, one group per ecosystem so a week of updates is one pull request,
and a commit prefix so the title passes the Conventional Commits check:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: weekly }
    commit-message: { prefix: ci, include: scope }
    groups: { actions: { patterns: ["*"] } }
  - package-ecosystem: npm
    directory: /
    schedule: { interval: weekly }
    commit-message: { prefix: chore, include: scope }
    groups: { tooling: { patterns: ["*"] } }
  # macos: also package-ecosystem swift, directory /apps/macos/Packages/<Name>Kit
```

`.github/pull_request_template.md` is the four sections of `references/workflow.md` §5, so a pull
request opened from the browser has the same shape as one an agent opened:

```markdown
## What changed

## Why
<!-- Milestone, FR-xx, the document section this implements. -->

## How it was verified

## Risk if this is wrong
```

## 4. The hosted workflows

`.github/workflows/ci.yml` runs on pull requests, on push to `main` and by hand. Its jobs are the
jobs of `scripts/ci.sh`, calling the same package scripts, so the local gate and the hosted one
cannot disagree about what "green" means. **One job per test layer** — unit, integration, end to
end — so a red check names the layer that broke.

Rules every workflow follows:

- **Every job has `timeout-minutes`.** A hung job otherwise holds a runner for six hours.
- **`concurrency` cancels the older run** of the same pull request when a new push arrives.
- **`permissions: contents: read`** at the top; a job that needs more asks for it.
- **Never filter paths at the workflow level.** A required check from a workflow that did not run
  stays pending forever and blocks the merge. Filter at the job level instead: a `changes` job
  with `dorny/paths-filter`, and `if:` on the jobs it gates. A job skipped by `if:` counts as
  passing.
- **A job whose subject does not exist yet still exists**, and its step prints why it skipped and
  exits 0, as the local gate does. The ruleset is written once in `M0` and never edited when the
  subject arrives.
- **Actions pinned to a major**, kept current by Dependabot. The majors below are today's; check
  them when scaffolding.

### web

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.head_ref || github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - &checkout
        uses: actions/checkout@v7
      - &pnpm
        uses: pnpm/action-setup@v6
      - &node
        uses: actions/setup-node@v7
        with: { node-version-file: .nvmrc, cache: pnpm }
      - &install
        run: pnpm install --frozen-lockfile
      - run: pnpm biome ci .
      - name: Migrations are generated
        run: |
          if [ ! -d packages/db/drizzle ]; then echo "skipped: no schema package yet"; exit 0; fi
          ./scripts/check-migrations.sh

  typecheck:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps: [*checkout, *pnpm, *node, *install, { run: pnpm turbo typecheck }]

  unit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps: [*checkout, *pnpm, *node, *install, { run: pnpm turbo test }]

  # Testcontainers starts Postgres itself; the runner already has Docker.
  integration:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps: [*checkout, *pnpm, *node, *install, { run: pnpm turbo test:integration }]

  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - *checkout
      - *pnpm
      - *node
      - *install
      - name: End to end
        run: |
          if [ ! -d apps/web/e2e ]; then echo "skipped: no browser surface yet"; exit 0; fi
          pnpm --filter @<project>/web exec playwright install --with-deps chromium
          pnpm turbo test:e2e
      - if: failure()
        uses: actions/upload-artifact@v6
        with: { name: playwright-report, path: apps/web/playwright-report, retention-days: 7 }

  secrets:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v7
        with: { fetch-depth: 0 }
      - run: docker run --rm -v "$PWD:/repo" ghcr.io/gitleaks/gitleaks:v8.30.1 git /repo --redact --no-banner

  pr-title:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions: { pull-requests: read }
    steps:
      - uses: amannn/action-semantic-pull-request@v6
        env: { GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}" }
```

GitHub Actions accepts YAML anchors, which keeps the four setup steps written once. Required
checks: `lint`, `typecheck`, `unit`, `integration`, `e2e`, `secrets`, `pr-title`. The `e2e` job's
database comes from the same Testcontainers setup the integration tests use, so it runs the same
way on a laptop and on a runner.

### macos

Hosted macOS minutes count ten times against a private repository's allowance, so the workflow is
shaped around that one expensive runner:

| Job | Runner | Runs | When |
|---|---|---|---|
| `changes` | Ubuntu | `dorny/paths-filter`: app sources, Swift files, the workflow itself, each filter excluding Markdown and version-only files | Always |
| `lint` | Ubuntu | swift-format and SwiftLint in their Docker images, Biome when there is JavaScript | Always; the Swift steps only when Swift changed |
| `secrets` | Ubuntu | gitleaks | Always |
| `pr-title` | Ubuntu | The semantic pull request check | Pull requests |
| `macos` | `macos-<current>` | `make ci`: build, then the unit and integration suites of every package and the app's UI tests in one `xcodebuild test`, so everything compiles once; then the `--snapshot` render, and code signing when the certificate secret exists | Only when app sources changed |

One `macos` job, not three. The layers stay distinct — Swift Testing suites per target for unit and
integration, an XCUITest target for end to end once the app has flows worth driving — and `make ci`
reports each, but splitting them across runners pays for three builds. Cache SwiftPM's `.build`,
the derived data directory and the XcodeGen binary, keyed on `Package.swift` and `project.yml`. A
release pull request touches only version files, so the filter skips the `macos` job on it. The
macos workflow does not run on push to `main`: that is ten-times minutes spent re-proving a merge.

When the "Where the check suite runs" slot chose the local gate, the workflow keeps only the
Ubuntu jobs, and the ruleset requires only those.

### cli

The web workflow's `lint`, `typecheck`, `unit`, `secrets` and `pr-title`, and:

| Job | Runs |
|---|---|
| `integration` | The commands in-process against a temporary home directory and a local stub server (`references/stack-cli.md` §5) |
| `e2e` | A matrix over the supported operating systems and Node majors: `pnpm pack`, install the tarball into an empty directory, run the installed binary's golden tests |

The matrix produces one check per cell (`e2e (ubuntu-latest, 22)`); require every cell.

## 5. The release workflow

release-please runs on push to `main` and keeps a release pull request open. That pull request has
to pass the same required checks as any other, and a pull request opened with the workflow's own
`GITHUB_TOKEN` does not start workflows the normal way. Either let release-please act through a
GitHub App's token, or have the release workflow approve the runs it left waiting, as a step after
release-please; the plan picks one and says which. Publishing — an npm package, release assets, a
signed app — happens in the same workflow when release-please reports a release was created, never
on an arbitrary tag push.

## 6. `scripts/configure-repo.sh`

Idempotent: run it after creating the repository, and again whenever a required check or a
milestone is added. Fill the three variables from the plan.

```bash
#!/usr/bin/env bash
# Applies the repository settings, labels and the default branch ruleset. Safe to re-run.
# See docs/NN-engineering-practices.md §3.
set -euo pipefail

repo="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
required_checks=(lint typecheck unit integration e2e secrets pr-title) # the hosted jobs, by name
milestones=(M0 M1 M2)                                                   # from docs/NN-roadmap.md
approvals=0                                                             # 1 once there is a second committer

gh api --method PATCH "repos/$repo" --silent \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F allow_auto_merge=true \
  -F delete_branch_on_merge=true \
  -F allow_update_branch=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -F has_wiki=false \
  -F has_projects=false

gh api --method PUT "repos/$repo/actions/permissions/workflow" --silent \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=false

gh api --method PUT "repos/$repo/vulnerability-alerts" --silent
gh api --method PUT "repos/$repo/automated-security-fixes" --silent

if [[ "$(gh api "repos/$repo" --jq .visibility)" == "public" ]]; then
  gh api --method PATCH "repos/$repo" --silent --input - <<'JSON'
{ "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" } } }
JSON
fi

gh label create needs-human --repo "$repo" --force --color d93f0b \
  --description "Stopped: a person has to decide" >/dev/null
for m in "${milestones[@]}"; do
  gh label create "goal:$m" --repo "$repo" --force --color 0e8a16 --description "Milestone $m" >/dev/null
done

checks_json=$(printf '{"context":"%s"},' "${required_checks[@]}")
ruleset=$(cat <<JSON
{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": $approvals,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [${checks_json%,}]
      }
    }
  ]
}
JSON
)

existing=$(gh api "repos/$repo/rulesets" --jq '.[] | select(.name == "main") | .id')
if [[ -n "$existing" ]]; then
  method=PUT path="repos/$repo/rulesets/$existing"
else
  method=POST path="repos/$repo/rulesets"
fi
if ! gh api --method "$method" "$path" --input - --silent <<<"$ruleset"; then
  echo "warning: the ruleset was not applied. A private repository needs GitHub Pro or Team for it;" >&2
  echo "until then the pre-push hook is the only gate." >&2
fi

echo "Configured $repo"
```

The script changes settings on a live repository, so it is run by a person, once, and the run is
the `M0` task's evidence. An agent never runs it unprompted.
