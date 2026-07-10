# Release bei jedem Push auf main — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Jeder Push auf `main` erzeugt automatisch einen GitHub-Release `v<MARKETING_VERSION>.<run_number>` mit der gebauten App als ZIP; die Run-Nummer wird als Build-Nummer (CFBundleVersion) in die App eingebaut.

**Architecture:** Einzige Änderung ist `.github/workflows/build.yml`: Tag-Trigger entfällt, `xcodebuild` bekommt `CURRENT_PROJECT_VERSION` aus der Run-Nummer, der Release-Step läuft nur noch bei Push auf `main` und liest die `MARKETING_VERSION` per `xcodebuild -showBuildSettings` aus dem Projekt.

**Tech Stack:** GitHub Actions (macos-26 Runner), `xcodebuild`, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-07-10-release-per-push-design.md`

## Global Constraints

- Repo ist öffentlich unter Pseudonym `marsvogel` — keine Klarnamen/Arbeitgeber in Commits oder Dateien.
- Step-Namen im Workflow sind deutsch (bestehender Stil).
- Tag-/Release-Schema exakt: `v<MARKETING_VERSION>.<run_number>`, z. B. `v1.0.42`.
- `MARKETING_VERSION` wird NICHT hardcodiert, sondern aus dem Xcode-Projekt gelesen.
- Release-Step nur bei `github.event_name == 'push' && github.ref == 'refs/heads/main'`.
- `gh release create` immer mit `--target "$GITHUB_SHA"` (Tag muss auf den gebauten Commit zeigen).

---

### Task 1: Workflow umbauen

**Files:**
- Modify: `.github/workflows/build.yml` (komplette Datei, siehe Step 3)

**Interfaces:**
- Consumes: bestehendes Xcode-Projekt `PromptQuittung.xcodeproj` mit Target `PromptQuittung` und `MARKETING_VERSION = 1.0` in den Build-Settings.
- Produces: Workflow, der bei Push auf `main` einen Release `v1.0.<run_number>` erstellt. Task 2 verlässt sich auf den Step-Namen `Release erstellen (nur auf main)` und das Asset `PromptQuittung.zip`.

- [ ] **Step 1: Extraktion der MARKETING_VERSION lokal verifizieren (Test zuerst)**

Bevor der Befehl in den Workflow wandert, lokal prüfen, dass er genau `1.0` liefert:

```bash
cd /path/to/PromptQuittung
xcodebuild -project PromptQuittung.xcodeproj \
  -target PromptQuittung -configuration Release -showBuildSettings 2>/dev/null \
  | awk '$1 == "MARKETING_VERSION" {print $3; exit}'
```

Erwartet: exakt die Ausgabe `1.0` (eine Zeile, nichts weiter). Liefert der Befehl etwas anderes (leer, mehrere Zeilen), NICHT fortfahren, sondern die `awk`-Extraktion anpassen, bis die Ausgabe stimmt.

- [ ] **Step 2: Verifizieren, dass CURRENT_PROJECT_VERSION per Kommandozeile überschreibbar ist**

```bash
xcodebuild -project PromptQuittung.xcodeproj \
  -target PromptQuittung -configuration Release -showBuildSettings \
  CURRENT_PROJECT_VERSION=42 2>/dev/null \
  | awk '$1 == "CURRENT_PROJECT_VERSION" {print $3; exit}'
```

Erwartet: `42`. (Damit ist belegt, dass der Override im CI-Build greift und die App als Build 42 erscheint.)

- [ ] **Step 3: Workflow-Datei ersetzen**

`.github/workflows/build.yml` bekommt exakt diesen Inhalt:

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

      - name: Build (unsigniert)
        run: |
          xcodebuild -project PromptQuittung.xcodeproj \
            -target PromptQuittung \
            -configuration Release \
            CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
            CURRENT_PROJECT_VERSION=${{ github.run_number }} \
            build

      - name: App als ZIP verpacken
        run: ditto -c -k --keepParent build/Release/PromptQuittung.app PromptQuittung.zip

      - name: Artefakt hochladen
        uses: actions/upload-artifact@v5
        with:
          name: PromptQuittung
          path: PromptQuittung.zip

      - name: Release erstellen (nur auf main)
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

Änderungen gegenüber vorher: (a) `tags: ["v*"]`-Trigger entfernt, (b) `CURRENT_PROJECT_VERSION=${{ github.run_number }}` im Build, (c) Release-Bedingung von Tag auf main-Push umgestellt, (d) Tag wird aus `MARKETING_VERSION` + Run-Nummer gebaut, (e) `--target "$GITHUB_SHA"` ergänzt.

- [ ] **Step 4: YAML-Syntax prüfen**

```bash
ruby -ryaml -e 'YAML.load_file(".github/workflows/build.yml"); puts "OK"'
```

Erwartet: `OK`. (Falls `actionlint` installiert ist, zusätzlich `actionlint .github/workflows/build.yml` laufen lassen — erwartet: keine Ausgabe, Exit-Code 0.)

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/build.yml
git commit -m "ci: Release bei jedem Push auf main statt nur bei Tags"
```

---

### Task 2: Auf main verifizieren

**Files:**
- Keine Änderungen — reine Verifikation des deployten Workflows.

**Interfaces:**
- Consumes: den in Task 1 committeten Workflow; Step-Name `Release erstellen (nur auf main)`, Asset `PromptQuittung.zip`.
- Produces: bestätigten Release `v1.0.<n>` auf GitHub.

- [ ] **Step 1: Push auf main**

```bash
git push origin main
```

Erwartet: Push erfolgreich, Workflow `Build` startet auf GitHub.

- [ ] **Step 2: Workflow-Lauf beobachten**

`gh run watch` braucht eine Run-ID, sonst fragt es interaktiv nach:

```bash
sleep 10  # GitHub braucht einen Moment, um den Lauf anzulegen
RUN_ID=$(gh run list --branch main --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

Erwartet: Lauf endet mit `completed success` (Exit-Code 0). Schlägt der Build fehl, Logs mit `gh run view "$RUN_ID" --log-failed` holen und das Problem beheben, bevor es weitergeht.

Hinweis zur Spec-Verifikation „PR-Build erzeugt keinen Release": Das ist durch die Bedingung `github.event_name == 'push'` am Release-Step abgedeckt — PR-Läufe (`event_name == 'pull_request'`) überspringen den Step per Definition. Ein eigener Test-PR ist nicht nötig.

- [ ] **Step 3: Release prüfen**

```bash
gh release list --limit 3
gh release view --json tagName,assets,targetCommitish
```

Erwartet: Neuester Release hat einen Tag der Form `v1.0.<n>` (n = Run-Nummer), genau ein Asset `PromptQuittung.zip`, und `targetCommitish` ist der gepushte Commit-SHA.

- [ ] **Step 4: Build-Nummer in der App prüfen**

```bash
cd "$(mktemp -d)"
gh release download --repo marsvogel/PromptQuittung --pattern PromptQuittung.zip
ditto -x -k PromptQuittung.zip .
plutil -p PromptQuittung.app/Contents/Info.plist | grep -E "CFBundleVersion|CFBundleShortVersionString"
```

Erwartet: `CFBundleShortVersionString => "1.0"` und `CFBundleVersion => "<n>"`, wobei `<n>` die Run-Nummer aus dem Release-Tag ist. Stimmt die Nummer nicht überein, hat der `CURRENT_PROJECT_VERSION`-Override nicht gegriffen — dann Build-Logs prüfen.
