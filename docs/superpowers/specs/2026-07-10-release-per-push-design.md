# Design: Release on Every Push to main

**Date:** 2026-07-10
**Status:** Draft

## Goal

So far, a GitHub release is only created when a tag (`v*`) is pushed manually.
Going forward, every push to `main` should automatically produce its own permanent
release. The GitHub run number (`github.run_number`) serves as the build number.

## Decisions

1. **Release style:** A dedicated release per push to `main` (no rolling
   "latest" variant). Old builds remain downloadable.
2. **Build number:** `github.run_number`. Simple and monotonically increasing.
   Deliberately accepted quirk: PR builds also increment the number, so
   gaps appear in the release numbering (e.g. v1.0.42 → v1.0.45).
3. **App version:** The run number is baked into the app as
   `CURRENT_PROJECT_VERSION` (CFBundleVersion). The app then shows e.g. "1.0 (42)",
   so a download can be unambiguously matched to a release.
4. **Versioning scheme:** Tag and release title are `v<MARKETING_VERSION>.<run_number>`,
   e.g. `v1.0.42`. The `MARKETING_VERSION` is read from the project via
   `xcodebuild -showBuildSettings`, not hardcoded.
   A later version bump (e.g. to 1.1) happens only in the Xcode project.

## Changes to `.github/workflows/build.yml`

- **Trigger:** The `tags: ["v*"]` trigger is removed — every main push releases
  anyway; a manual tag would create a duplicate release for the same state.
  `pull_request` and `workflow_dispatch` remain (they build without releasing).
- **Build step:** `xcodebuild` additionally receives
  `CURRENT_PROJECT_VERSION=${{ github.run_number }}`.
- **Release step:** The condition becomes
  `github.event_name == 'push' && github.ref == 'refs/heads/main'`.
  The step reads the `MARKETING_VERSION`, derives the tag
  `v<MARKETING_VERSION>.<run_number>` from it, and creates the release with
  `gh release create <tag> PromptQuittung.zip --title <tag> --generate-notes --target "$GITHUB_SHA"`.
  `--target` ensures the tag points exactly to the commit that was built —
  without the option it would be set to the current HEAD of `main`, which
  could hit the wrong commit when pushes follow each other in quick succession.

## Error handling

- If the build fails, neither tag nor release is created (the release step
  only runs after a successful build).
- Tag collisions are ruled out by the monotonically increasing run number.

## Test / Verification

- PR with the workflow change: the build runs, **no** release is created.
- After merging to `main`: release `v1.0.<n>` appears with the ZIP asset and
  generated release notes; the app in the ZIP reports build number `n`
  (`CFBundleVersion` in the built app's `Info.plist`).
