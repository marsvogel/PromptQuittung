# Design: SwiftLint in der Build-Pipeline

**Datum:** 2026-07-10
**Status:** Umgesetzt

## Ziel

Jeder Push und Pull Request wird automatisch auf SwiftLint-Verstöße geprüft. Ein
Verstoß lässt den Workflow fehlschlagen und verhindert damit auch das Release,
das bei jedem Push auf `main` erstellt wird.

## Entscheidungen

### Lint als Step im bestehenden Build-Job

Betrachtete Alternativen:

1. **Step im Build-Job, vor dem Build (gewählt):** Ein Runner, einfachste
   Struktur. Da das Release im selben Job hängt, verhindert ein Lint-Fehler
   automatisch das Release — ohne `needs:`-Verkabelung.
2. **Separater Lint-Job:** Läuft parallel und gibt bei PRs etwas schnelleres
   Feedback, bräuchte aber `needs: lint` am Build-Job (sonst entstünde ein
   Release trotz Lint-Fehler) und einen zweiten macOS-Runner-Start. Für ein
   Projekt dieser Größe kein Gewinn.

### Installation auf dem Runner

`command -v swiftlint >/dev/null || brew install swiftlint` — die
GitHub-macOS-Images bringen SwiftLint meist mit; falls das `macos-26`-Image es
nicht (mehr) enthält, greift der Homebrew-Fallback.

### Strikter Modus

`swiftlint lint --strict` behandelt Warnings als Fehler. Der Bestand wurde auf
null Verstöße gebracht, damit bleibt der Standard dauerhaft sauber. Der
Reporter `github-actions-logging` erzeugt Annotations direkt im PR-Diff.

### Konfiguration `.swiftlint.yml`

- `included: [PromptQuittung]` — nur die App-Quellen; `build/` und sonstige
  generierte Pfade werden nie gescannt.
- `identifier_name.excluded: [SQLITE_TRANSIENT]` — der Name spiegelt bewusst
  die C-Makro-Konvention aus `sqlite3.h`; Umbenennung würde die 1:1-Zuordnung
  zur C-API verschleiern.
- Sonst gelten die SwiftLint-Standardregeln unverändert.

### Bestandsverstöße: Code angepasst statt Regeln abgeschaltet

37 Verstöße (23 Errors, 14 Warnings) wurden im Code behoben — rein mechanisch,
ohne Verhaltensänderung:

- Kurzbezeichner ausgeschrieben (`c` → `container`, `e` → `event`,
  `db` → `database`, `n` → `count`, `s` → `string`, …).
- `else`/`else if` auf die Zeile der schließenden Klammer gezogen
  (`statement_position`), dabei die kompakten Decoder in
  `CursorUsageModels.swift` mehrzeilig ausformuliert — die
  Decode-Reihenfolge der Branches bleibt identisch.
- Überlange Zeilen (> 120 Zeichen) umgebrochen bzw. Log-Interpolationen in
  lokale Konstanten gezogen (privacy-Annotationen unverändert).
- Trailing Comma im Request-Body-Literal entfernt.

## Verifikation

- `swiftlint lint --strict` (portable SwiftLint 0.65.0): 0 Verstöße, Exit 0.
- `xcodebuild … -configuration Release build` mit den CI-Flags:
  **BUILD SUCCEEDED**.
