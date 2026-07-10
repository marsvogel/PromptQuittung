# Owl Silhouette as Menu Bar Icon — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app's menu bar icon with a stylized owl silhouette (template image, modeled on the app icon); until now it has shown the misleading SF Symbol `bell.badge`.

**Architecture:** A new SVG image set `MenuBarIcon` in the existing asset catalog `PromptQuittung/Assets.xcassets` (template rendering, vector data preserved), plus switching the `MenuBarExtra` initializer in `PromptQuittungApp.swift` from `systemImage:` to `image:`. The project uses `PBXFileSystemSynchronizedRootGroup` — new files under `PromptQuittung/` automatically become part of the target; `project.pbxproj` remains untouched.

**Tech Stack:** SwiftUI `MenuBarExtra` (macOS 13+), Xcode asset catalog with SVG (Xcode ≥ 12), xcodebuild, SwiftLint.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-10-menubar-owl-icon-design.md` — take the owl's geometry exactly from there.
- Public repo under a pseudonym: commit exclusively with the already configured git identity `marsvogel`; no real names in files or commit messages.
- SwiftLint runs in CI with `--strict`; every Swift change must be lint-free.
- Commit messages in English, following the existing style (`feat:`, `docs:`, …).

---

### Task 1: SVG asset `MenuBarIcon` in the asset catalog

**Files:**
- Create: `PromptQuittung/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.svg`
- Create: `PromptQuittung/Assets.xcassets/MenuBarIcon.imageset/Contents.json`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: an asset catalog entry named `MenuBarIcon`, which Task 2 references via `MenuBarExtra("PromptQuittung", image: "MenuBarIcon")`.

- [x] **Step 1: Create the imageset directory and the SVG**

File `PromptQuittung/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.svg` with exactly this content (owl silhouette, variant A from the spec; the fill color does not matter with template rendering, only alpha counts):

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">
  <path fill-rule="evenodd" fill="#000000" d="M9 16.8 C4.6 14.3 2.4 11.4 2.4 8.1 C2.4 4.5 5.3 1.7 9 1.7 C12.7 1.7 15.6 4.5 15.6 8.1 C15.6 11.4 13.4 14.3 9 16.8 Z M5.9 8 m-2.8 0 a2.8 2.8 0 1 0 5.6 0 a2.8 2.8 0 1 0 -5.6 0 Z M12.1 8 m-2.8 0 a2.8 2.8 0 1 0 5.6 0 a2.8 2.8 0 1 0 -5.6 0 Z"/>
  <path fill="#000000" d="M6.9 3.3 C5.9 1.6 3.9 0.5 0.8 0.9 C2.0 2.0 3.1 3.4 4.2 5.7 C5.0 4.7 5.9 3.9 6.9 3.3 Z"/>
  <path fill="#000000" d="M11.1 3.3 C12.1 1.6 14.1 0.5 17.2 0.9 C16.0 2.0 14.9 3.4 13.8 5.7 C13.0 4.7 12.1 3.9 11.1 3.3 Z"/>
  <circle fill="#000000" cx="6.1" cy="8.1" r="1.2"/>
  <circle fill="#000000" cx="11.9" cy="8.1" r="1.2"/>
</svg>
```

- [x] **Step 2: Create Contents.json**

File `PromptQuittung/Assets.xcassets/MenuBarIcon.imageset/Contents.json` with exactly this content:

```json
{
  "images" : [
    {
      "filename" : "MenuBarIcon.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}
```

- [x] **Step 3: Run the build — actool must accept the SVG**

Run:
```bash
xcodebuild -project PromptQuittung.xcodeproj \
  -target PromptQuittung \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **` (no actool warning about `MenuBarIcon`).

- [x] **Step 4: Verify the asset in the compiled catalog**

Run:
```bash
assetutil --info build/Release/PromptQuittung.app/Contents/Resources/Assets.car | grep -A2 '"Name" : "MenuBarIcon"' | head -5
```
Expected: at least one entry with `"Name" : "MenuBarIcon"` (vector rendition).

- [x] **Step 5: Commit**

```bash
git add PromptQuittung/Assets.xcassets/MenuBarIcon.imageset
git commit -m "feat: owl silhouette as MenuBarIcon template asset"
```

---

### Task 2: Switch MenuBarExtra to the owl icon

**Files:**
- Modify: `PromptQuittung/PromptQuittungApp.swift:8`

**Interfaces:**
- Consumes: asset `MenuBarIcon` from Task 1.
- Produces: visible behavior — an owl instead of a bell in the menu bar; no API for further tasks to build on.

- [x] **Step 1: Switch the initializer**

In `PromptQuittung/PromptQuittungApp.swift`, line 8, before:

```swift
        MenuBarExtra("PromptQuittung", systemImage: "bell.badge") {
```

after:

```swift
        MenuBarExtra("PromptQuittung", image: "MenuBarIcon") {
```

- [x] **Step 2: Check SwiftLint**

Run: `swiftlint lint --strict 2>/dev/null | tail -3` (if `swiftlint` is missing locally: skip this step, CI checks it anyway).
Expected: `Found 0 violations` or exit code 0.

- [x] **Step 3: Run the build**

Run:
```bash
xcodebuild -project PromptQuittung.xcodeproj \
  -target PromptQuittung \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [x] **Step 4: Launch the app and visually check the menu bar**

Run:
```bash
open build/Release/PromptQuittung.app && sleep 3 && \
screencapture -x -R0,0,2000,40 /tmp/menubar-owl.png
```
(Adjust the image width to the screen resolution if necessary.)

Expected in the screenshot: the owl silhouette appears on the right side of the menu bar, monochrome in the color matching the current appearance (light/dark), at a size similar to the neighboring icons. Then quit the app:

```bash
pkill -x PromptQuittung
```

- [x] **Step 5: Commit**

```bash
git add PromptQuittung/PromptQuittungApp.swift
git commit -m "feat: owl icon instead of bell.badge in the menu bar"
```
