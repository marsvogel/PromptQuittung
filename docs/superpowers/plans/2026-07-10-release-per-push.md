# Release on Every Push to main — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every push to `main` automatically creates a GitHub release `v<MARKETING_VERSION>.<run_number>` with the built app as a ZIP; the run number is baked into the app as the build number (CFBundleVersion).

**Architecture:** The only change is `.github/workflows/build.yml`: the tag trigger goes away, `xcodebuild` gets `CURRENT_PROJECT_VERSION` from the run number, the release step now only runs on pushes to `main` and reads the `MARKETING_VERSION` from the project via `xcodebuild -showBuildSettings`.

**Tech Stack:** GitHub Actions (macos-26 runner), `xcodebuild`, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-07-10-release-per-push-design.md`

## Global Constraints

- The repo is public under the pseudonym `marsvogel` — no real names/employers in commits or files.
- Step names in the workflow are in English.
- Tag/release scheme exactly: `v<MARKETING_VERSION>.<run_number>`, e.g. `v1.0.42`.
- `MARKETING_VERSION` is NOT hardcoded but read from the Xcode project.
- Release step only on `github.event_name == 'push' && github.ref == 'refs/heads/main'`.
- `gh release create` always with `--target "$GITHUB_SHA"` (the tag must point to the built commit).

---

### Task 1: Rework the workflow

**Files:**
- Modify: `.github/workflows/build.yml` (entire file, see Step 3)

**Interfaces:**
- Consumes: existing Xcode project `PromptQuittung.xcodeproj` with target `PromptQuittung` and `MARKETING_VERSION = 1.0` in the build settings.
- Produces: a workflow that creates a release `v1.0.<run_number>` on every push to `main`. Task 2 relies on the step name `Create release (main only)` and the asset `PromptQuittung.zip`.

- [ ] **Step 1: Verify the MARKETING_VERSION extraction locally (test first)**

Before the command goes into the workflow, verify locally that it yields exactly `1.0`:

```bash
cd /path/to/PromptQuittung
xcodebuild -project PromptQuittung.xcodeproj \
  -target PromptQuittung -configuration Release -showBuildSettings 2>/dev/null \
  | awk '$1 == "MARKETING_VERSION" {print $3; exit}'
```

Expected: exactly the output `1.0` (one line, nothing else). If the command yields anything else (empty, multiple lines), do NOT continue; instead adjust the `awk` extraction until the output is correct.

- [ ] **Step 2: Verify that CURRENT_PROJECT_VERSION can be overridden via the command line**

```bash
xcodebuild -project PromptQuittung.xcodeproj \
  -target PromptQuittung -configuration Release -showBuildSettings \
  CURRENT_PROJECT_VERSION=42 2>/dev/null \
  | awk '$1 == "CURRENT_PROJECT_VERSION" {print $3; exit}'
```

Expected: `42`. (This proves that the override takes effect in the CI build and the app shows up as build 42.)

- [ ] **Step 3: Replace the workflow file**

`.github/workflows/build.yml` gets exactly this content:

```yaml
name: Build

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v5

      - name: Build (unsigned)
        run: |
          xcodebuild -project PromptQuittung.xcodeproj \
            -target PromptQuittung \
            -configuration Release \
            CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
            CURRENT_PROJECT_VERSION=${{ github.run_number }} \
            build

      - name: Package app as ZIP
        run: ditto -c -k --keepParent build/Release/PromptQuittung.app PromptQuittung.zip

      - name: Upload artifact
        uses: actions/upload-artifact@v5
        with:
          name: PromptQuittung
          path: PromptQuittung.zip

      - name: Create release (main only)
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          MARKETING_VERSION=$(xcodebuild -project PromptQuittung.xcodeproj \
            -target PromptQuittung -configuration Release -showBuildSettings 2>/dev/null \
            | awk '$1 == "MARKETING_VERSION" {print $3; exit}')
          TAG="v${MARKETING_VERSION}.${{ github.run_number }}"
          gh release create "$TAG" PromptQuittung.zip \
            --title "$TAG" \
            --generate-notes \
            --target "$GITHUB_SHA"
```

Changes compared to before: (a) removed the `tags: ["v*"]` trigger, (b) `CURRENT_PROJECT_VERSION=${{ github.run_number }}` in the build, (c) switched the release condition from tag to main push, (d) the tag is built from `MARKETING_VERSION` + run number, (e) added `--target "$GITHUB_SHA"`.

- [ ] **Step 4: Check the YAML syntax**

```bash
ruby -ryaml -e 'YAML.load_file(".github/workflows/build.yml"); puts "OK"'
```

Expected: `OK`. (If `actionlint` is installed, additionally run `actionlint .github/workflows/build.yml` — expected: no output, exit code 0.)

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/build.yml
git commit -m "ci: release on every push to main instead of only on tags"
```

---

### Task 2: Verify on main

**Files:**
- No changes — pure verification of the deployed workflow.

**Interfaces:**
- Consumes: the workflow committed in Task 1; step name `Create release (main only)`, asset `PromptQuittung.zip`.
- Produces: a confirmed release `v1.0.<n>` on GitHub.

- [ ] **Step 1: Push to main**

```bash
git push origin main
```

Expected: push succeeds, the `Build` workflow starts on GitHub.

- [ ] **Step 2: Watch the workflow run**

`gh run watch` needs a run ID, otherwise it prompts interactively:

```bash
sleep 10  # GitHub needs a moment to register the run
RUN_ID=$(gh run list --branch main --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

Expected: the run finishes with `completed success` (exit code 0). If the build fails, fetch the logs with `gh run view "$RUN_ID" --log-failed` and fix the problem before continuing.

Note on the spec verification "a PR build creates no release": this is covered by the `github.event_name == 'push'` condition on the release step — PR runs (`event_name == 'pull_request'`) skip the step by definition. A dedicated test PR is not necessary.

- [ ] **Step 3: Check the release**

```bash
gh release list --limit 3
gh release view --json tagName,assets,targetCommitish
```

Expected: the newest release has a tag of the form `v1.0.<n>` (n = run number), exactly one asset `PromptQuittung.zip`, and `targetCommitish` is the pushed commit SHA.

- [ ] **Step 4: Check the build number in the app**

```bash
cd "$(mktemp -d)"
gh release download --repo marsvogel/PromptQuittung --pattern PromptQuittung.zip
ditto -x -k PromptQuittung.zip .
plutil -p PromptQuittung.app/Contents/Info.plist | grep -E "CFBundleVersion|CFBundleShortVersionString"
```

Expected: `CFBundleShortVersionString => "1.0"` and `CFBundleVersion => "<n>"`, where `<n>` is the run number from the release tag. If the number does not match, the `CURRENT_PROJECT_VERSION` override did not take effect — check the build logs in that case.
