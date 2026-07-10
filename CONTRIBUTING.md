# Contributing

Thanks for your interest in contributing!

## Prerequisites

- macOS 15+ and a recent Xcode (the project is built with Xcode 26 in CI)
- [SwiftLint](https://github.com/realm/SwiftLint) — CI runs `swiftlint lint --strict`, so warnings fail the build

## Building

```sh
xcodebuild -project PromptQuittung.xcodeproj -target PromptQuittung -configuration Release build
```

Note that the project uses build **targets**, not schemes, for plain builds (`-target`, not `-scheme`).

## Testing

```sh
xcodebuild test -project PromptQuittung.xcodeproj -scheme PromptQuittung
```

Please add tests for new logic where practical — the pure parts (token parsing, diffing, decoding) are deliberately kept testable.

## Ground rules

- **Everything checked into this repository must be written in English**: code, comments, string literals, documentation, CI configuration, and commit messages.
- Commit messages follow the `type: subject` convention (e.g. `fix: …`, `feat: …`, `docs: …`).
- Keep the app small and dependency-free — it currently builds with no third-party dependencies.
- Never commit tokens, personal data, or absolute user paths.

## Pull requests

Open an issue first for larger changes so the direction can be discussed. Small fixes can go straight to a PR.
