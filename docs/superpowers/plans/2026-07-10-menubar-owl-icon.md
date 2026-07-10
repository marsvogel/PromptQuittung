# Eulen-Silhouette als MenuBar-Icon — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das MenuBar-Icon der App durch eine stilisierte Eulen-Silhouette (Template-Image, angelehnt ans App-Icon) ersetzen; bisher zeigt es das irreführende SF Symbol `bell.badge`.

**Architecture:** Ein neues SVG-Image-Set `MenuBarIcon` im bestehenden Asset-Katalog `PromptQuittung/Assets.xcassets` (Template-Rendering, Vektordaten erhalten), dazu die Umstellung des `MenuBarExtra`-Initialisierers in `PromptQuittungApp.swift` von `systemImage:` auf `image:`. Das Projekt nutzt `PBXFileSystemSynchronizedRootGroup` — neue Dateien unter `PromptQuittung/` werden automatisch Teil des Targets, `project.pbxproj` bleibt unberührt.

**Tech Stack:** SwiftUI `MenuBarExtra` (macOS 13+), Xcode-Asset-Katalog mit SVG (Xcode ≥ 12), xcodebuild, SwiftLint.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-10-menubar-owl-icon-design.md` — Geometrie der Eule exakt von dort übernehmen.
- Öffentliches Repo unter Pseudonym: Commits ausschließlich mit der bereits konfigurierten Git-Identität `marsvogel`, keine Klarnamen in Dateien oder Commit-Messages.
- SwiftLint läuft in der CI mit `--strict`; jede Swift-Änderung muss lint-frei sein.
- Commit-Messages auf Deutsch im bestehenden Stil (`feat:`, `docs:`, …).

---

### Task 1: SVG-Asset `MenuBarIcon` im Asset-Katalog

**Files:**
- Create: `PromptQuittung/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.svg`
- Create: `PromptQuittung/Assets.xcassets/MenuBarIcon.imageset/Contents.json`

**Interfaces:**
- Consumes: nichts (erster Task).
- Produces: Asset-Katalog-Eintrag mit dem Namen `MenuBarIcon`, den Task 2 per `MenuBarExtra("PromptQuittung", image: "MenuBarIcon")` referenziert.

- [ ] **Step 1: Imageset-Verzeichnis und SVG anlegen**

Datei `PromptQuittung/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.svg` mit exakt diesem Inhalt (Eulen-Silhouette, Variante A aus der Spec; Füllfarbe ist bei Template-Rendering egal, zählt nur Alpha):

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">
  <path fill-rule="evenodd" fill="#000000" d="M9 16.8 C4.6 14.3 2.4 11.4 2.4 8.1 C2.4 4.5 5.3 1.7 9 1.7 C12.7 1.7 15.6 4.5 15.6 8.1 C15.6 11.4 13.4 14.3 9 16.8 Z M5.9 8 m-2.8 0 a2.8 2.8 0 1 0 5.6 0 a2.8 2.8 0 1 0 -5.6 0 Z M12.1 8 m-2.8 0 a2.8 2.8 0 1 0 5.6 0 a2.8 2.8 0 1 0 -5.6 0 Z"/>
  <path fill="#000000" d="M6.9 3.3 C5.9 1.6 3.9 0.5 0.8 0.9 C2.0 2.0 3.1 3.4 4.2 5.7 C5.0 4.7 5.9 3.9 6.9 3.3 Z"/>
  <path fill="#000000" d="M11.1 3.3 C12.1 1.6 14.1 0.5 17.2 0.9 C16.0 2.0 14.9 3.4 13.8 5.7 C13.0 4.7 12.1 3.9 11.1 3.3 Z"/>
  <circle fill="#000000" cx="6.1" cy="8.1" r="1.2"/>
  <circle fill="#000000" cx="11.9" cy="8.1" r="1.2"/>
</svg>
```

- [ ] **Step 2: Contents.json anlegen**

Datei `PromptQuittung/Assets.xcassets/MenuBarIcon.imageset/Contents.json` mit exakt diesem Inhalt:

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

- [ ] **Step 3: Build ausführen — actool muss das SVG akzeptieren**

Run:
```bash
xcodebuild -project PromptQuittung.xcodeproj \
  -target PromptQuittung \
  -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **` (keine actool-Warnung zu `MenuBarIcon`).

- [ ] **Step 4: Asset im kompilierten Katalog nachweisen**

Run:
```bash
assetutil --info build/Release/PromptQuittung.app/Contents/Resources/Assets.car | grep -A2 '"Name" : "MenuBarIcon"' | head -5
```
Expected: mindestens ein Eintrag mit `"Name" : "MenuBarIcon"` (Vector-Rendition).

- [ ] **Step 5: Commit**

```bash
git add PromptQuittung/Assets.xcassets/MenuBarIcon.imageset
git commit -m "feat: Eulen-Silhouette als Template-Asset MenuBarIcon"
```

---

### Task 2: MenuBarExtra auf das Eulen-Icon umstellen

**Files:**
- Modify: `PromptQuittung/PromptQuittungApp.swift:8`

**Interfaces:**
- Consumes: Asset `MenuBarIcon` aus Task 1.
- Produces: sichtbares Verhalten — Eule statt Glocke in der Menüleiste; keine API, auf der weitere Tasks aufbauen.

- [ ] **Step 1: Initialisierer umstellen**

In `PromptQuittung/PromptQuittungApp.swift`, Zeile 8, alt:

```swift
        MenuBarExtra("PromptQuittung", systemImage: "bell.badge") {
```

neu:

```swift
        MenuBarExtra("PromptQuittung", image: "MenuBarIcon") {
```

- [ ] **Step 2: SwiftLint prüfen**

Run: `swiftlint lint --strict 2>/dev/null | tail -3` (falls `swiftlint` lokal fehlt: Schritt überspringen, die CI prüft ohnehin).
Expected: `Found 0 violations` bzw. Exit 0.

- [ ] **Step 3: Build ausführen**

Run:
```bash
xcodebuild -project PromptQuittung.xcodeproj \
  -target PromptQuittung \
  -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: App starten und Menüleiste visuell prüfen**

Run:
```bash
open build/Release/PromptQuittung.app && sleep 3 && \
screencapture -x -R0,0,2000,40 /tmp/menubar-owl.png
```
(Bildbreite ggf. an die Bildschirmauflösung anpassen.)

Expected im Screenshot: Die Eulen-Silhouette erscheint rechts in der Menüleiste, monochrom in der zur aktuellen Darstellung (hell/dunkel) passenden Farbe, in ähnlicher Größe wie die Nachbar-Icons. Danach App beenden:

```bash
pkill -x PromptQuittung
```

- [ ] **Step 5: Commit**

```bash
git add PromptQuittung/PromptQuittungApp.swift
git commit -m "feat: Eulen-Icon statt bell.badge in der Menüleiste"
```
