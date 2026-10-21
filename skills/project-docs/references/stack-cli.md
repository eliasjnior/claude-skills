# The CLI baseline

The baseline for the **cli profile**: a command-line tool people install and run in a terminal or a
pipeline — a developer tool, the client for an API, a generator, an automation. Written in
TypeScript on Node, so it shares the web baseline's language, package manager and tooling, and a
person who knows one of these repositories knows the other.

**Do not re-litigate §1 to §7.** Carry them into `NN-stack.md` with the reasons adapted to the
project's own facts. Versions are today's; check the registry when scaffolding, and say in the
document that the reasoning is what should not drift.

From the web baseline (`references/stack-baseline.md`) this profile keeps, unchanged: TypeScript
`strict` with the same compiler flags, Node ≥ 22, pnpm through corepack, Biome with boundary rules,
Zod at every edge, Vitest, Husky with lint-staged, commitlint, gitleaks, worktrunk, hand-written
clients rather than vendor SDKs, and `scripts/ci.sh` as the one gate. What it drops: Postgres,
Drizzle, an HTTP framework, Compose, Turborepo, everything about deployment.

---

## 1. Language, runtime, layout — fixed

| What | Version | Why | Cost to replace |
|---|---|---|---|
| **TypeScript** | 5.9+ | As on web. A CLI's whole surface is parsing strings into shapes; types are what make the parsed shape trustworthy past the parser | High |
| **Node.js** | ≥ 22, in `engines` | The runtime the users already have when they install from npm, with stable `fetch` and `node:util` `styleText`. The lowest supported major is a promise, tested in the matrix (§5) | High |
| **ESM only** | — | One module system. `"type": "module"`, no dual build | Low |
| **pnpm** | pinned in `packageManager` | As on web | Medium |

Layout, a single package unless §8 says otherwise:

```
src/
  cli.ts          the entry: a few lines that call main() with the real process
  main.ts         main(argv, io): parse, build the environment, dispatch, map errors to exit codes
  commands/       one file per command: its options, the call into core, the rendering
  core/           the rules. No I/O, no process, no clock: input, time and randomness are arguments
  adapters/       the HTTP clients, the filesystem, the credential store, each behind a port in core
  render/         the human output and the --json output of every result type
test/
  integration/    commands run in-process against a temporary home and stub servers
  e2e/            golden tests against the installed binary
  fixtures/       recorded provider responses, sample inputs, golden output files
docs/             the plan
scripts/          repository scripts
```

Two properties, stated in `NN-stack.md`:

- **`src/core` performs no I/O.** No `node:fs`, no `fetch`, no `process`, no `Date.now()`. Enforced
  by Biome's `noRestrictedImports` and `noRestrictedGlobals` on `src/core/**`, each with a message
  naming the rule. This is the package-boundary rule of the web baseline, inside one package.
- **`main(argv, io)` takes the process as an argument.** `io` carries `stdout`, `stderr`, `stdin`,
  `env`, `cwd`, `isTTY` and `now`. `cli.ts` passes the real ones; integration tests pass their own.
  That is what lets every command run in-process in a test without spawning anything.

## 2. Tooling — fixed

| What | Why |
|---|---|
| **commander** with `@commander-js/extra-typings` | Subcommands, help, typed options, no dependencies of its own. The help text is generated from the same declaration the parser uses, so they cannot disagree |
| **@clack/prompts** | Prompts and a spinner, used only when stdin and stdout are a TTY (§3) |
| **Zod** | The config file, every environment variable, every provider response |
| **tsdown** | Bundles `src/cli.ts` into one ESM file in `dist/` with its shebang. **Every pure-JavaScript dependency is bundled**, so the published package's `dependencies` holds only native modules: installing it runs no third-party install script and resolves nothing at startup |
| **Biome**, **Husky** + **lint-staged**, **commitlint**, **gitleaks**, **worktrunk**, **Vitest** | As on web |
| **release-please** | The version, the changelog and the release pull request from Conventional Commits |
| **npm trusted publishing** | The release workflow publishes through OIDC with provenance. There is no `NPM_TOKEN` secret to leak or rotate |

## 3. The command-line contract — fixed

The interface of a CLI is its arguments, its output and its exit code. `03-architecture.md`
specifies all three, and each rule here is a requirement the e2e tests assert.

| Rule | Why |
|---|---|
| **stdout is data, stderr is everything else.** Progress, warnings, prompts and logs go to stderr | `tool list \| jq` works, and a warning never corrupts a pipe |
| **Every command that prints data takes `--json`**, and the JSON shape is a contract: additive changes only, a removed field is a major version | Scripts parse it. A breaking change to it breaks someone's pipeline silently |
| **Exit codes are documented**: `0` success, `1` the operation failed, `2` usage error (unknown flag, missing argument, invalid value), `130` interrupted. Anything else is project-specific and listed in `03` | Scripts branch on them; "non-zero" is not a contract |
| **No prompt without a TTY.** Every prompt has a flag that answers it, and a confirmation has `--yes`. Without a TTY and without the flag, fail with exit `2` and name the flag | A prompt in CI hangs until the job times out |
| **Colour only on a TTY**, off with `NO_COLOR`, forced with `FORCE_COLOR`, through `node:util` `styleText` | Escape codes in a log file are noise, and these variables are what every other tool honours |
| **Errors are one line**: what failed, why, and what to do next. The stack trace only with `--verbose` | The user did not write the code; a stack trace answers a question they did not ask |
| **`--help` and `--version` are instant.** A command imports its heavy modules lazily, inside its action | Startup time is the whole experience of a command that does little. State a budget as an `NFR-xx` |
| **Ctrl-C stops cleanly**: temporary files removed, partial writes never left in place, exit `130` | The user will press it |

Naming: commands are `<noun> <verb>` (`tool project list`) once there is more than one noun,
lowercase. Flags are `--kebab-case`, with a short form only for the few used constantly.
Environment variables are `<TOOL>_SNAKE_CASE`. JSON fields are `camelCase`.

## 4. Configuration and state — fixed

| What | Where | Rule |
|---|---|---|
| User config | `$XDG_CONFIG_HOME/<tool>/config.json`, default `~/.config/<tool>/` (on Windows `%APPDATA%\<tool>\`) | Validated by Zod on read; an unknown key is an error that names it. `schemaVersion` in the file, with a decoder for the previous version |
| State | `$XDG_STATE_HOME/<tool>/`, default `~/.local/state/<tool>/` | What the tool remembers between runs. Written atomically: a temporary file, then a rename |
| Cache | `$XDG_CACHE_HOME/<tool>/`, default `~/.cache/<tool>/` | Safe to delete at any time, and the tool says so in `--help` |
| Secrets | Never in the config file | §8, credentials |

Precedence, highest first: flag → environment variable → project file (only if the product has
per-directory config, §8) → user config → default. One function resolves it, and `tool config
show` prints every value with where it came from.

The paths are computed by a small adapter, not a library: it is a dozen lines, and the tests point
every one of them at a temporary directory through `io.env`.

## 5. Testing — fixed

Three layers, each its own job in `scripts/ci.sh` and in the hosted workflow
(`references/repository.md` §4).

| Layer | Runs against | What it proves | Script |
|---|---|---|---|
| **Unit** | `src/core`, directly | Every rule in `02`, including the properties asserted over generated input | `test` |
| **Integration** | `main(argv, io)` in-process, with a temporary home directory, captured streams, and a local `node:http` server per provider serving recorded fixtures | A command end to end inside the process: parsing, config precedence, the adapter's request and its error mapping, the rendered output and the exit code | `test:integration` |
| **End to end** | The **installed** package: `pnpm pack`, install the tarball into an empty directory, spawn the installed binary | What only the published artifact can get wrong: the `bin` path, the shebang, the `files` list, a dependency left in `devDependencies`, a path that resolves only from source | `test:e2e` |

End-to-end tests are **golden**: the exact stdout, stderr and exit code for `--help`, `--version`,
a usage error, and the main path of every `Must` requirement, stored under `test/fixtures/golden/`
and compared byte for byte with colour off. `UPDATE_GOLDEN=1` rewrites them, and the rewrite is
reviewed in the diff like code. The hosted `e2e` job runs them on every supported operating system
and every supported Node major.

No layer mocks our own modules. A provider is replaced at the network edge, by the local server,
never at the port.

## 6. Observability — fixed

`--verbose` (and `<TOOL>_DEBUG=1`, for when the flag cannot be passed) writes what the tool is
doing to stderr: each request's method, URL and status, never its credentials. **No telemetry.** If
it is ever wanted, it is opt-in, documented in `01`, and a `D-xx`.

## 7. What was deliberately not used — carry this table

| Not used | Why |
|---|---|
| **oclif** | A framework with a plugin system and a generator, for a tool with one author and no plugins. commander is a parser, which is what is needed |
| **yargs** | Heavier, and its types are weaker than commander's with `extra-typings` |
| **chalk**, **ora** | `node:util` `styleText` covers colour and honours `NO_COLOR`; clack has the spinner |
| **cosmiconfig**, **dotenv** | One config file in one known place, validated by Zod. A CLI reads its environment from the shell it runs in |
| **pkg**, **nexe** | Unmaintained. When standalone binaries are needed, §8 has the options |
| **Turborepo** | One package. It returns with the monorepo layout in §8 |
| **ESLint**, **Prettier** | As on web: Biome, and adding either back is out of bounds |

Adapt the rows, keep the shape.

## 8. The variable slots — decide these per project, in the register

| Slot | Options | Rule |
|---|---|---|
| **Distribution** | npm (`npx`, `pnpm dlx`, a global install) · standalone binaries on GitHub Releases with a Homebrew tap | **npm** when the users are developers who have Node. **Binaries** when they do not: `bun build --compile` cross-compiles every target from one runner, and then the runtime is Bun, so the e2e matrix runs the compiled binaries instead of the tarball. Node's single executable applications are the alternative when staying on Node matters more than the build being simple |
| **Platforms** | macOS and Linux · also Windows | Windows when the audience uses it. It costs path handling, shell quoting in the e2e tests, and a matrix cell; say so |
| **Credentials** | An environment variable · the OS keychain (`@napi-rs/keyring`) · borrowing another CLI's token (`gh auth token`) | **The environment variable always works**, because CI has no keychain. The keychain behind a `tool auth login` when people use it interactively. Borrow when the tool fronts a service whose CLI the users already signed in to |
| **Layout** | One package · `packages/core` and `apps/cli` on the web baseline's monorepo layout | One package until the core is published as a library of its own or a second deliverable (a web surface, a bot) appears. Then the monorepo, with Turborepo back |
| **Per-directory config** | None · a project file (`<tool>.config.json`) found by walking up from the cwd | None unless the same user needs different settings per repository, which is a product statement in `01` |
| **Update notice** | None · a daily check of the registry, on stderr, off with an environment variable | **None** when a package manager installs it: the package manager owns updates. A notice only for binaries installed without one |
| **Where the check suite runs** | GitHub Actions · `scripts/ci.sh` behind `.husky/pre-push` | As on web. The e2e matrix is the argument for Actions: a laptop proves one operating system |

Two more, always decided explicitly and always in the register:

- **The command tree.** Every command and subcommand, before the first is written, in `03`. Adding
  a command later is cheap; renaming one is a breaking change.
- **Domain vocabulary.** One word per concept across commands, flags, output and documents. Settle
  it before writing document `02`.

---

## 9. Scaffold files (Phase 7 only)

Emit these only when the user asks for a scaffold. `tsconfig.json`, `biome.json`,
`commitlint.config.js` and the Husky hooks are the web baseline's (`references/stack-baseline.md`
§9), with the boundary override on `src/core/**` instead of `packages/domain/**`.

### `package.json`

```json
{
  "name": "<tool>",
  "version": "0.0.0",
  "type": "module",
  "packageManager": "pnpm@<pinned>",
  "engines": { "node": ">=22" },
  "bin": { "<tool>": "./dist/cli.js" },
  "files": ["dist"],
  "scripts": {
    "prepare": "husky",
    "build": "tsdown",
    "typecheck": "tsc --noEmit",
    "test": "vitest run --project unit",
    "test:integration": "vitest run --project integration",
    "test:e2e": "pnpm build && vitest run --project e2e",
    "lint": "biome check .",
    "ci": "./scripts/ci.sh"
  },
  "devDependencies": {
    "@biomejs/biome": "^2",
    "@clack/prompts": "^1",
    "@commander-js/extra-typings": "^15",
    "@commitlint/cli": "^21",
    "@commitlint/config-conventional": "^21",
    "commander": "^15",
    "husky": "^9",
    "lint-staged": "^17",
    "tsdown": "^0.23",
    "typescript": "^5.9",
    "vitest": "^4",
    "zod": "^4"
  }
}
```

Every runtime library sits in `devDependencies` because tsdown bundles it (§2). A native module
is the one exception: it goes in `dependencies` and in tsdown's `external`.

### `tsdown.config.ts`

```ts
import { defineConfig } from "tsdown";

export default defineConfig({
  entry: ["src/cli.ts"],
  format: "esm",
  platform: "node",
  target: "node22",
  outDir: "dist",
  // Bundle every pure-JavaScript dependency; list native modules here.
  external: [],
  banner: { js: "#!/usr/bin/env node" },
});
```

### `src/cli.ts`

```ts
import { main } from "./main.js";

process.exitCode = await main(process.argv.slice(2), {
  stdout: process.stdout,
  stderr: process.stderr,
  stdin: process.stdin,
  env: process.env,
  cwd: process.cwd(),
  isTTY: Boolean(process.stdout.isTTY && process.stdin.isTTY),
  now: () => new Date(),
});
```

### `scripts/ci.sh`

The web gate's script (`references/workflow.md` §4) with these jobs, every one run before
reporting and a skip printing its reason:

| Job | Runs | Skips when |
|---|---|---|
| format and lint | `pnpm biome ci .` | never |
| typecheck | `pnpm typecheck` | never |
| unit tests | `pnpm test` | never |
| commit messages | `./scripts/check-commits.sh` | never |
| integration tests | `pnpm test:integration` | there is no `test/integration` yet |
| end-to-end tests | `pnpm test:e2e` | there is no `test/e2e` yet, or `CI_FAST=1` |

### `.config/wt.toml`

```toml
# Worktree lifecycle for worktrunk (`wt`). Every task runs in its own worktree.

[[pre-start]]
# Dependencies, and the git hooks husky writes during install, so the push gate exists here too
install = "pnpm install --frozen-lockfile"
```

A CLI has no ports and no database, so a worktree needs nothing else. Its tests write only to the
temporary directories they create.

### Also

`.nvmrc` with the lowest supported major, which is what development runs on. `vitest.config.ts`
with the three projects (`unit` over `src/**/*.test.ts`, `integration` over
`test/integration/**`, `e2e` over `test/e2e/**`). `.gitignore` with `dist/` and `*.tgz`.
