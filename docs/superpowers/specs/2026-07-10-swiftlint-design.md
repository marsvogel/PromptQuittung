# Design: SwiftLint in the Build Pipeline

**Date:** 2026-07-10
**Status:** Implemented

## Goal

Every push and pull request is automatically checked for SwiftLint violations. A
violation fails the workflow and thereby also prevents the release that is
created on every push to `main`.

## Decisions

### Lint as a step in the existing build job

Alternatives considered:

1. **Step in the build job, before the build (chosen):** One runner, simplest
   structure. Since the release lives in the same job, a lint failure
   automatically prevents the release — without any `needs:` wiring.
2. **Separate lint job:** Runs in parallel and gives slightly faster feedback
   on PRs, but would need `needs: lint` on the build job (otherwise a
   release would be created despite a lint failure) and a second macOS runner
   startup. No win for a project of this size.

### Installation on the runner

`command -v swiftlint >/dev/null || brew install swiftlint` — the
GitHub macOS images usually ship with SwiftLint; if the `macos-26` image
does not (or no longer) include it, the Homebrew fallback kicks in.

### Strict mode

`swiftlint lint --strict` treats warnings as errors. The existing codebase was
brought down to zero violations, so the baseline stays permanently clean. The
`github-actions-logging` reporter produces annotations directly in the PR diff.

### Configuration `.swiftlint.yml`

- `included: [PromptQuittung]` — only the app sources; `build/` and other
  generated paths are never scanned.
- `identifier_name.excluded: [SQLITE_TRANSIENT]` — the name deliberately
  mirrors the C macro convention from `sqlite3.h`; renaming it would obscure
  the 1:1 mapping to the C API.
- Otherwise the SwiftLint default rules apply unchanged.

### Pre-existing violations: code adjusted instead of rules disabled

37 violations (23 errors, 14 warnings) were fixed in the code — purely
mechanically, without behavior changes:

- Short identifiers spelled out (`c` → `container`, `e` → `event`,
  `db` → `database`, `n` → `count`, `s` → `string`, …).
- `else`/`else if` moved onto the line of the closing brace
  (`statement_position`), expanding the compact decoders in
  `CursorUsageModels.swift` into multi-line form in the process — the
  decode order of the branches remains identical.
- Overlong lines (> 120 characters) wrapped, or log interpolations pulled
  into local constants (privacy annotations unchanged).
- Trailing comma removed from the request body literal.

## Verification

- `swiftlint lint --strict` (portable SwiftLint 0.65.0): 0 violations, exit 0.
- `xcodebuild … -configuration Release build` with the CI flags:
  **BUILD SUCCEEDED**.
