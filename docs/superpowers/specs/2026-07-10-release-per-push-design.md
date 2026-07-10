# Design: Release bei jedem Push auf main

**Datum:** 2026-07-10
**Status:** Entwurf

## Ziel

Bisher entsteht ein GitHub-Release nur, wenn manuell ein Tag (`v*`) gepusht wird.
Künftig soll jeder Push auf `main` automatisch einen eigenen, dauerhaften Release
erzeugen. Als Build-Nummer dient die GitHub-Run-Nummer (`github.run_number`).

## Entscheidungen

1. **Release-Stil:** Eigener Release pro Push auf `main` (keine rollierende
   "Latest"-Variante). Alte Builds bleiben herunterladbar.
2. **Build-Nummer:** `github.run_number`. Einfach und monoton steigend.
   Bewusst akzeptierte Eigenheit: PR-Builds zählen die Nummer mit hoch, es
   entstehen also Lücken in der Release-Nummerierung (z. B. v1.0.42 → v1.0.45).
3. **App-Version:** Die Run-Nummer wird als `CURRENT_PROJECT_VERSION`
   (CFBundleVersion) in die App eingebaut. Die App zeigt dann z. B. "1.0 (42)",
   sodass sich ein Download eindeutig einem Release zuordnen lässt.
4. **Versionsschema:** Tag und Release-Titel sind `v<MARKETING_VERSION>.<run_number>`,
   z. B. `v1.0.42`. Die `MARKETING_VERSION` wird per
   `xcodebuild -showBuildSettings` aus dem Projekt gelesen, nicht hardcodiert.
   Ein späterer Versions-Bump (z. B. auf 1.1) passiert nur im Xcode-Projekt.

## Änderungen an `.github/workflows/build.yml`

- **Trigger:** Der `tags: ["v*"]`-Trigger entfällt — jeder main-Push released
  ohnehin; ein manueller Tag würde einen doppelten Release für denselben Stand
  erzeugen. `pull_request` und `workflow_dispatch` bleiben (bauen ohne Release).
- **Build-Step:** `xcodebuild` erhält zusätzlich
  `CURRENT_PROJECT_VERSION=${{ github.run_number }}`.
- **Release-Step:** Bedingung wird
  `github.event_name == 'push' && github.ref == 'refs/heads/main'`.
  Der Step liest die `MARKETING_VERSION`, setzt daraus den Tag
  `v<MARKETING_VERSION>.<run_number>` und erstellt den Release mit
  `gh release create <tag> PromptQuittung.zip --title <tag> --generate-notes --target "$GITHUB_SHA"`.
  `--target` stellt sicher, dass der Tag exakt auf den gebauten Commit zeigt —
  ohne die Option würde er auf den aktuellen HEAD von `main` gesetzt, was bei
  schnell aufeinanderfolgenden Pushes den falschen Commit treffen könnte.

## Fehlerbehandlung

- Schlägt der Build fehl, entsteht weder Tag noch Release (Release-Step läuft
  nur nach erfolgreichem Build).
- Tag-Kollisionen sind durch die monoton steigende Run-Nummer ausgeschlossen.

## Test / Verifikation

- PR mit der Workflow-Änderung: Build läuft, **kein** Release entsteht.
- Nach Merge auf `main`: Release `v1.0.<n>` erscheint mit ZIP-Asset und
  generierten Release-Notes; die App im ZIP meldet Build-Nummer `n`
  (`CFBundleVersion` in `Info.plist` der gebauten App).
