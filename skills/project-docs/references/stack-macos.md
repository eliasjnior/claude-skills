# The macOS baseline

The baseline for the **macOS profile**: a native Mac app (a menu bar app, a utility, a monitor)
written in Swift. Derived from one shipped app and one planned on top of it: they share one layout,
one toolchain, one release and update mechanism, so a third app inherits the reasoning instead of
re-deriving it.

**Do not re-litigate §1 to §7.** Carry them into `NN-stack.md` with the reasons adapted to the
project's own facts. Versions are the ones in use today; check for current ones when scaffolding,
and say in the document that the reasoning is what should not drift.

The parts of the web baseline that are not about the web still hold here: Conventional Commits
with commitlint, the `D-xx` register, worktrunk, `scripts/ci.sh` as the one gate, hand-written
clients rather than vendor SDKs, and "an absence is recorded". When the repository also has a web
surface (a page the app bundles, a marketing site), `apps/web` follows
`references/stack-baseline.md` and the two meet in §2's root toolchain.

---

## 1. Language, UI, project — fixed

| What | Version | Why | Cost to replace |
|---|---|---|---|
| **Swift** | 6.x, `SWIFT_STRICT_CONCURRENCY: complete` | A data race is a compile error, not a crash report. The poller, the scheduler and the stores cross threads by design, and actors plus `@MainActor` make that crossing checkable | High |
| **SwiftUI** | system | Every view. Declarative, previewable, and the only UI framework Apple is still adding to | High |
| **AppKit** | system | Where SwiftUI has no first-class answer: `NSStatusItem`, `NSPopover`, window activation for an `LSUIElement` app. Wrapped, never mixed into views | Medium |
| **Xcode** | latest stable | The toolchain. `xcodebuild` is the only build path, locally and in CI | High |
| **XcodeGen** | 2.x | `project.yml` is the project; the `.xcodeproj` is generated and gitignored. A committed project file is the merge conflict nobody can review, and every worktree generates its own | Low |
| **Swift Package Manager** | toolchain | One local package, `<Name>Kit`, with one target per concern. No CocoaPods, no Carthage | Medium |

Layout, always:

```
apps/macos/
  App/Sources/<feature>/        SwiftUI and AppKit: UI and wiring only
  App/Sources/Environment/      AppEnvironment, the composition root
  App/Resources/                Assets, Localizable.xcstrings
  Packages/<Name>Kit/           Sources/<one folder per target>, Tests/<one per target>
  Config/Version.xcconfig       Version and build number, written by release-please
  project.yml                   XcodeGen spec
  Makefile                      bootstrap, gen, build, test, lint, format, install, ci
  scripts/                      Signing, icons, check-imports.sh
  CHANGELOG.md                  Bundled into the app for What's New
docs/                           The plan
scripts/ci.sh                   The gate
```

`apps/macos` even with one app, so a second one (a bundled web page, a CLI) lands where it would in
a repository that already has two.

Three properties come with the layout and are worth stating in `NN-stack.md`:

- **The app target holds UI and wiring only.** Everything that can be tested without a window
  lives in `<Name>Kit`: stores, rules, adapters. A behaviour that only exists in the app target is
  a behaviour without a test.
- **`<Name>Core` and the rules target import only `Foundation`, and perform no I/O.** No
  `URLSession`, `FileManager`, `Process`, `UserDefaults`, `Date()`, `Date.now` or `.random`. Time
  arrives as a `now: Date` argument. Then every rule is a pure function over values, and every bug
  in it reproduces as an input and an expected output.
- **The boundaries are compiler errors.** SwiftPM refuses an `import` of a target that is not a
  declared dependency, so the target graph in `Package.swift` *is* the boundary table.
  `scripts/check-imports.sh` covers the two things the compiler cannot see: forbidden APIs inside
  the pure targets, and the app target importing an adapter outside `App/Sources/Environment/`.

## 2. Tooling — fixed

| What | Why |
|---|---|
| **swift-format** (`swift format`, in the toolchain) | Formatting, and `lint --strict` in the gate. Ships with Swift, so there is nothing to install or pin |
| **SwiftLint** | `--strict`, for the rules swift-format does not have: `force_unwrapping`, `implicitly_unwrapped_optional`, `first_where`. Configured in `.swiftlint.yml` next to `project.yml` |
| **Swift Testing** | `import Testing`, `#expect`, parameterised tests for the worked examples of document `02`. XCTest only where Swift Testing has no equivalent |
| **lefthook** | Hooks for a polyglot repository: a job per glob, a `root:` per app, `{staged_files}` per job. Husky with lint-staged is shaped for JavaScript and runs Swift tools through it awkwardly |
| **pnpm at the root** | Only for the JavaScript tools the repository needs anyway: commitlint, lefthook, Biome for JSON config. No workspace packages unless there is a web app |
| **Turborepo** | **Only with two or more apps.** One app is a task graph of one node, which is configuration without a job. Add it when the second app arrives; each app then exposes `build`, `test`, `lint`, `format` scripts, and `apps/macos/package.json` wraps the `Makefile` |
| **commitlint** | Conventional Commits, scope is the app (`feat(macos): …`). In `commit-msg` and again in CI |
| **gitleaks** | `pre-commit` over staged files and a CI job over history. A Mac app handles tokens, account names and personal identifiers, and the repository may become public |
| **Homebrew `Brewfile`** | `make bootstrap` installs XcodeGen, SwiftLint and gitleaks, so a new machine is one command |
| **release-please** | Version, changelog and tag per app (`macos-vX.Y.Z`). The version lives in `Config/Version.xcconfig`, `version.txt` and `apps/macos/package.json` and never in `project.yml`, so a release pull request does not trigger the macOS build |
| **worktrunk** (`wt`) | One worktree per task, `.config/wt.toml` in §9 |

Two conventions that cost nothing and pay for themselves:

- **`--snapshot <directory>`.** The built binary, run with this flag, renders self-contained views
  (popover rows in each state, settings sections, What's New, About) to PNG in light and dark
  appearance and exits. An agent cannot capture the screen, so this is how a UI change is checked
  at all; extend `App/Sources/Support/Snapshots.swift` when a view needs it, and say so in
  `CLAUDE.md`.
- **A developer CLI** (`<name>-cli`, an executable target in the kit), when the app talks to
  external providers. It runs the real adapters against live data without the app — one poll,
  printed — which is how a provider's behaviour is investigated without clicking.

## 3. Persistence — the property fixed, the store a slot

**The property: files are split by who writes them.** In
`~/Library/Application Support/<App>/`:

| File | Written by | Losing it costs |
|---|---|---|
| `config.json` | The user: settings, selections, their own tags and names | Everything the user decided. Backed up, exported, never reset by the app |
| `state.json` | The app: cursors, delivered notifications, bookkeeping | One round of re-baselining |
| `cache/` | The remote, last seen | Nothing but a slower first launch |

A corrupt `state.json` then never touches a tag. Every file is written atomically (write to a
temporary file, then replace), carries a `schemaVersion`, and decodes old versions; a file that
does not decode is moved aside with a timestamp and replaced with defaults, and the app says so
instead of crashing.

**Secrets live in the Keychain**, never in a JSON file and never in `UserDefaults`. `UserDefaults`
holds nothing the app would have to migrate, back up or explain.

The store itself is a slot (§8).

## 4. Networking — fixed

`URLSession`, `async`/`await`, `Codable`, and a hand-written client per provider behind a protocol
in `<Name>Core`. No vendor SDKs and no Alamofire, for the web baseline's reason: the app uses a
fraction of each API, the failure modes are the app's to handle, and an injectable transport is the
whole testing strategy.

Testing follows the boundary:

- **An adapter** is tested at the network edge: a `URLProtocol` stub serving recorded fixtures,
  synthetic and committed under `Tests/<Target>Tests/Fixtures`. Never a real address, key or account.
- **A store** is tested with fake adapters, which are second implementations of a port, not mocks.
  Never mock a store, a rules function, or anything else in the kit.

## 5. Observability — fixed

`os.Logger`, one subsystem (the bundle identifier) and one category per target. Interpolated values
are `.private` unless they are safe to read in a bug report; never log a token, an address, an
account name or a URL with a credential in it. Read with Console.app or
`log stream --predicate 'subsystem == "com.<owner>.<app>"'`.

No analytics, no crash reporter: see §7.

## 6. UI conventions — fixed

- **Stores are `@Observable`**, live in `<Name>Stores`, and publish one immutable value per update,
  so a view never renders a half-applied poll.
- **Copy lives in `Localizable.xcstrings`**, never inline, even when the app ships in one language.
  A translation is then a file, not a refactor.
- **Launch at login with `SMAppService.mainApp`.** No helper app, no LaunchAgent plist.
- **The bundle identifier is decided before the first release.** Keychain items and notification
  permission are bound to it, so renaming it later loses both for every user.

## 7. What was deliberately not used — carry this table

| Not used | Why |
|---|---|
| **Electron, Tauri** | 100 to 200 MB of memory for a popover of twenty rows, rendered in a web view that does not look like the menu bar it sits under |
| **Mac Catalyst** | An iPad app shape on a platform whose surface here is a status item and a popover |
| **A committed `.xcodeproj`** | Unreviewable merge conflicts. XcodeGen generates it |
| **CocoaPods, Carthage** | SwiftPM is in the toolchain |
| **The Composable Architecture, RxSwift, Combine as the architecture** | Observation plus `async`/`await` and ports cover an app this size. An architecture framework is a High-cost dependency that every file is written against |
| **Core Data, SwiftData** | An opaque schema whose migrations are hard to test. Persistence is files or GRDB (§8), both inspectable |
| **Vendor SDKs, Alamofire** | §4 |
| **Analytics and crash-reporting SDKs** | The data never leaves the Mac except to the providers the app exists to talk to. A crash is reproduced from the logs and the user's report |
| **A backend of our own** | The app talks to its providers directly; there is no server to run, secure or pay for. **Revisit when** sync across devices becomes a requirement |
| **Husky, lint-staged** | lefthook (§2) |
| **ESLint, Prettier** | Biome, for the little JavaScript and JSON there is |

Adapt the rows, keep the shape. Any technology a reader would expect and not find belongs here with
a reason.

---

## 8. The variable slots — decide these per project, in the register

| Slot | Options | Rule |
|---|---|---|
| **Deployment target** | The current macOS major · the previous one | **The previous major**, unless an API only in the current one is load-bearing. Say which API it was |
| **Persistence** | JSON files (§3) · SQLite through GRDB | **JSON** when the data is read whole into memory and stays in the hundreds of entries. GRDB when a query crosses several dimensions, entries reach the thousands, or a searchable history is a requirement |
| **Signing** | Self-signed certificate · Developer ID with notarization · the Mac App Store | **Self-signed** when the only users are the author: the designated requirement stays stable across builds, which is what keeps Keychain access and notification permission across updates. It costs a Gatekeeper warning and a right-click → Open on first launch. **Developer ID** (paid account) as soon as anyone else installs it. **App Store** only when the sandbox is acceptable, which rules out running other CLIs and reading their credentials |
| **Updates** | An updater of our own over GitHub Releases · Sparkle · the App Store | **Our own**, when releases are on GitHub and signing is self-signed: an Ed25519-signed zip, a `release.json` asset, a designated-requirement check on the new bundle, no appcast host. **Sparkle** when there is Developer ID signing and an appcast host already, or delta updates matter. When a sibling app already has the updater, **copy the target rather than share a package**: a package shared between two repositories version-locks them for code that changes once a year |
| **Credentials** | A token the user pastes into the Keychain · borrowing a CLI's token (`gh auth token`) · OAuth (device flow) | **Borrow** when the user is already signed in to a CLI whose access the organization approved; it adds no application anyone has to approve. **Paste** as the fallback behind the same port. **OAuth** when the app is distributed and has to stand on its own |
| **Sandbox** | Off · on | **Off** outside the App Store when the app runs other processes or reads files outside its container. On for the App Store, and say what it rules out |
| **Where the check suite runs** | A macOS job on GitHub Actions · `scripts/ci.sh` behind lefthook's `pre-push` plus a cheap Ubuntu job | Hosted macOS minutes count **ten times** against a private repository's allowance, so a six-minute build is sixty minutes. **Public repository: Actions**, one macOS job for build, tests and signing so it compiles once. **Private: the local gate**, with an Ubuntu job for the pull request title, gitleaks, and swift-format and SwiftLint in Docker — and say out loud that `--no-verify` is the way past the only gate there is. The hosted workflow, and the ruleset that requires its jobs, are in `references/repository.md` |
| **Menu bar only or a Dock app** | `LSUIElement: true` · a regular app | A product decision, not a technical one. Menu bar only when the app is glanced at, never worked in |

Two more, always decided explicitly and always in the register:

- **Naming.** Types `UpperCamelCase`, one main type per file named after it, targets prefixed with
  the app's name (`BeaconCore`, `BeaconStores`). JSON keys `camelCase`. Bundle identifier
  `com.<owner>.<app>`.
- **Domain vocabulary.** One word per concept across code, documents and copy, and the boundary
  where a different word survives because it is the user's. Settle it before writing document `02`.

---

## 9. Scaffold files (Phase 7 only)

Emit these only when the user asks for a scaffold. Fill the marked slots; leave the rest.

### `apps/macos/project.yml`

```yaml
name: <App>
options:
  bundleIdPrefix: com.<owner>
  deploymentTarget:
    macOS: "<target>"
  createIntermediateGroups: true

configFiles:
  Debug: Config/Version.xcconfig
  Release: Config/Version.xcconfig

settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    MACOSX_DEPLOYMENT_TARGET: "<target>"
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Manual

packages:
  <Name>Kit:
    path: Packages/<Name>Kit

targets:
  <App>:
    type: application
    platform: macOS
    sources:
      - path: App/Sources
      - path: App/Resources
      - path: CHANGELOG.md
        buildPhase: resources
    dependencies:
      - package: <Name>Kit
        product: <Name>Core
      - package: <Name>Kit
        product: <Name>Stores
    info:
      path: App/Info.plist
      properties:
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        LSUIElement: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.<owner>.<app>
      configs:
        # A development build never reads or rewrites the installed app's files and Keychain items
        Debug:
          PRODUCT_BUNDLE_IDENTIFIER: com.<owner>.<app>.debug
```

### `apps/macos/Packages/<Name>Kit/Package.swift`

One library and one test target per concern. The dependency list of each target is the boundary
table; write it to match `03-architecture.md` §3 exactly.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "<Name>Kit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "<Name>Core", targets: ["<Name>Core"]),
        .library(name: "<Name>Stores", targets: ["<Name>Stores"]),
        .executable(name: "<name>-cli", targets: ["<Name>CLI"]),
    ],
    targets: [
        .target(name: "<Name>Core"),
        .target(name: "<Name>Persistence", dependencies: ["<Name>Core"]),
        .target(name: "<Name>Stores", dependencies: ["<Name>Core", "<Name>Persistence"]),
        .executableTarget(name: "<Name>CLI", dependencies: ["<Name>Core"]),
        .testTarget(name: "<Name>CoreTests", dependencies: ["<Name>Core"]),
        .testTarget(name: "<Name>PersistenceTests", dependencies: ["<Name>Persistence"]),
        .testTarget(name: "<Name>StoresTests", dependencies: ["<Name>Stores"]),
    ]
)
```

### `apps/macos/Makefile`

```make
PROJECT := <App>.xcodeproj
SCHEME := <App>
KIT := Packages/<Name>Kit
BUILD_DIR := build
CONFIG ?= Debug
SWIFT_SOURCES := App scripts $(KIT)/Sources $(KIT)/Tests $(KIT)/Package.swift

.PHONY: bootstrap gen build test lint format ci clean

bootstrap:
	brew bundle --file=../../Brewfile

gen:
	xcodegen generate --quiet

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR) -destination 'platform=macOS' CODE_SIGN_IDENTITY=- build

test:
	swift test --package-path $(KIT)

# Builds the app and runs every package test in one invocation, so the gate compiles once
ci: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(BUILD_DIR) -destination 'platform=macOS' CODE_SIGN_IDENTITY=- test

lint:
	swift format lint --strict --recursive $(SWIFT_SOURCES)
	swiftlint lint --strict --quiet

format:
	swift format --in-place --recursive $(SWIFT_SOURCES)
	swiftlint lint --fix --quiet

clean:
	rm -rf $(BUILD_DIR) $(PROJECT) $(KIT)/.build
```

Add `install` (build Release, sign, replace `/Applications/<App>.app`, relaunch) once the signing
slot is decided.

### `lefthook.yml`

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: swift-format
      root: apps/macos/
      glob: "*.swift"
      run: swift format lint --strict {staged_files}
    - name: swiftlint
      root: apps/macos/
      glob: "*.swift"
      run: swiftlint lint --strict --quiet {staged_files}
    - name: biome
      glob: "*.{js,mjs,ts,json,jsonc}"
      run: pnpm exec biome check --no-errors-on-unmatched --files-ignore-unknown=true {staged_files}
    - name: gitleaks
      run: gitleaks git --staged --redact --no-banner

commit-msg:
  jobs:
    - name: commitlint
      run: pnpm exec commitlint --edit {1}

pre-push:
  jobs:
    - name: gate
      run: ./scripts/ci.sh
```

The root `package.json` carries `"prepare": "lefthook install"`, so `pnpm install` writes the hooks
in every clone and every worktree.

### `Brewfile`

```ruby
brew "xcodegen"
brew "swiftlint"
brew "gitleaks"
```

### `scripts/ci.sh`

The same two properties as the web gate in `references/workflow.md` §4: every job runs before the
script reports, and a job whose subject does not exist yet skips with its reason printed.

```bash
#!/usr/bin/env bash
# Every check this project has. Run by lefthook's pre-push, and by hand.
set -uo pipefail

failed=()
run() { # run <name> <command...>
  local name="$1"; shift
  printf '\n\033[1m── %s\033[0m\n' "$name"
  if "$@"; then
    printf '\033[32m   ok\033[0m\n'
  else
    printf '\033[31m   FAILED\033[0m\n'
    failed+=("$name")
  fi
}
skip() { printf '\n\033[1m── %s\033[0m\n\033[33m   skipped — %s\033[0m\n' "$1" "$2"; }

run "commit messages" ./scripts/check-commits.sh
run "secrets"         gitleaks git --redact --no-banner

if [ -f apps/macos/project.yml ]; then
  run "format and lint" make -C apps/macos lint
  run "imports"         apps/macos/scripts/check-imports.sh
  run "build and test"  make -C apps/macos ci
else
  skip "format and lint" "no app yet"
  skip "imports"         "no app yet"
  skip "build and test"  "no app yet"
fi

if [ ${#failed[@]} -gt 0 ]; then
  printf '\n\033[31m%d job(s) failed: %s\033[0m\n' "${#failed[@]}" "${failed[*]}"
  exit 1
fi
printf '\n\033[32mall checks passed\033[0m\n'
```

### `apps/macos/scripts/check-imports.sh`

```bash
#!/usr/bin/env bash
# What the compiler cannot enforce. See CLAUDE.md, Target boundaries.
set -euo pipefail
cd "$(dirname "$0")/.."
status=0

# The pure targets perform no I/O and read no clock
pure="Packages/<Name>Kit/Sources/<Name>Core"
if grep -rnE 'URLSession|FileManager|Process\(|UserDefaults|Date\(\)|Date\.now|\.random' $pure; then
  echo "pure targets perform no I/O and read no clock: time arrives as an argument"
  status=1
fi

# Views see stores, not adapters
if grep -rnE '^import <Name>(Persistence|Notify)' App/Sources --exclude-dir=Environment; then
  echo "the app target imports adapters only in App/Sources/Environment"
  status=1
fi

exit $status
```

Name every adapter target in the second pattern, including the ones that do not exist yet. The
rule then bites the moment one is created.

### `.config/wt.toml`

No ports and no database: what makes a worktree ready here is the hooks and the generated project.

```toml
# Worktree lifecycle for worktrunk (`wt`). Every task runs in its own worktree.

[[pre-start]]
# The JavaScript tools and, through `prepare`, the git hooks, so the gate exists here too
install = "pnpm install --frozen-lockfile"

[[pre-start]]
# The .xcodeproj is generated, never committed, so a fresh worktree has none
gen = "make -C apps/macos gen"

[aliases]
build = "make -C apps/macos build"
```

Build products land in `apps/macos/build`, inside the worktree, so two worktrees never share
derived data. **The sharp edge:** two worktrees' development builds share the Debug bundle
identifier, so they share `Application Support`, the Keychain items and the menu bar slot. Run one
at a time, and write that into `CLAUDE.md`.

### Also

`.gitignore` with `apps/macos/build/`, `apps/macos/*.xcodeproj`, `.build/`. `.swift-format` with
the line length and indentation the project picked; `.swiftlint.yml` with `included` pointing at
the same sources as the `Makefile`'s `SWIFT_SOURCES`. `.nvmrc` for the root JavaScript tools.
`.gitleaks.toml` allowlisting the synthetic fixtures.
