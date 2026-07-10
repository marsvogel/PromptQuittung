# Design: Eulen-Silhouette als MenuBar-Icon

**Datum:** 2026-07-10
**Status:** Entwurf

## Ziel

Das MenuBar-Icon zeigt bislang das SF Symbol `bell.badge` — es suggeriert
Benachrichtigungen und hat keinen Bezug zur App. Stattdessen erscheint eine
stilisierte Eule, angelehnt an das App-Icon (türkise Eule mit großen Augen
und Federohren), als monochromes Template-Image.

## Entscheidungen

### Stil: gefüllte Silhouette (Variante A)

Betrachtete Alternativen (als Mockups in echter 18-pt-Größe verglichen):

1. **Gefüllte Silhouette (gewählt):** Tropfenförmiger Körper mit flügelartig
   nach außen schwingenden Federohren, Augen als Negativraum mit Pupillen,
   kein Schnabel. Liest sich bei 18 pt am klarsten und entspricht dem
   soliden Glyph-Stil der macOS-Menüleiste.
2. **Outline/Line-Art:** Konturlinien im SF-Symbols-Stil mit Schnabel —
   luftiger, aber bei 18 pt dichter und unruhiger.
3. **Nur Gesicht:** Brauen, Augenringe, Schnabel ohne Körperform — maximal
   reduziert, aber am wenigsten eindeutig als Eule erkennbar.

### Asset: SVG im Asset-Katalog, Template-Rendering

Neues Image Set `MenuBarIcon` in `PromptQuittung/Assets.xcassets`:

- Eine SVG-Datei mit `viewBox="0 0 18 18"`, schwarze Füllung, Single Scale.
- `Contents.json` mit `"template-rendering-intent": "template"` und
  `"preserves-vector-representation": true`. macOS färbt das Icon damit
  automatisch passend zur hellen/dunklen Menüleiste; die Vektordaten
  skalieren verlustfrei auf Retina.

Geometrie der Silhouette (18×18-Raster):

- Körper: Tropfenform, unten spitz zulaufend (`M9 16.8 C4.6 14.3 2.4 11.4
  2.4 8.1 C2.4 4.5 5.3 1.7 9 1.7 C12.7 1.7 15.6 4.5 15.6 8.1 C15.6 11.4
  13.4 14.3 9 16.8 Z`), Augen als evenodd-Aussparungen (Kreise r 2,8 bei
  x 5,9/12,1, y 8).
- Federohren: zwei nach außen schwingende Flügelformen ab Kopfoberkante
  (links `M6.9 3.3 C5.9 1.6 3.9 0.5 0.8 0.9 C2.0 2.0 3.1 3.4 4.2 5.7
  C5.0 4.7 5.9 3.9 6.9 3.3 Z`, rechts an x = 9 gespiegelt).
- Pupillen: gefüllte Kreise r 1,2, leicht zur Mitte versetzt.

### Code: Ein-Zeilen-Änderung

In `PromptQuittungApp.swift` wird der `MenuBarExtra`-Initialisierer von
`systemImage: "bell.badge"` auf `image: "MenuBarIcon"` umgestellt. Weitere
Codeänderungen gibt es nicht.

## Verifikation

- `xcodebuild … -configuration Release build`: **BUILD SUCCEEDED** —
  bestätigt auch, dass actool das SVG-Asset akzeptiert.
- App starten: Eule erscheint in der Menüleiste, invertiert korrekt
  zwischen heller und dunkler Darstellung, Menü öffnet sich unverändert.
- SwiftLint läuft unverändert in der CI (keine Swift-Änderung außer der
  einen Zeile).
