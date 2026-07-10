# Design: Owl Silhouette as Menu Bar Icon

**Date:** 2026-07-10
**Status:** Implemented

## Goal

Until now the menu bar icon has shown the SF Symbol `bell.badge` — it suggests
notifications and has no connection to the app. Instead, a stylized owl,
modeled on the app icon (turquoise owl with big eyes and ear tufts), appears
as a monochrome template image.

## Decisions

### Style: filled silhouette (variant A)

Alternatives considered (compared as mockups at the actual 18 pt size):

1. **Filled silhouette (chosen):** Teardrop-shaped body with ear tufts
   sweeping outward like wings, eyes as negative space with pupils,
   no beak. Reads most clearly at 18 pt and matches the solid glyph
   style of the macOS menu bar.
2. **Outline/line art:** Contour lines in the SF Symbols style with a beak —
   airier, but denser and busier at 18 pt.
3. **Face only:** Brows, eye rings, beak without a body shape — maximally
   reduced, but least clearly recognizable as an owl.

### Asset: SVG in the asset catalog, template rendering

New image set `MenuBarIcon` in `PromptQuittung/Assets.xcassets`:

- One SVG file with `viewBox="0 0 18 18"`, black fill, Single Scale.
- `Contents.json` with `"template-rendering-intent": "template"` and
  `"preserves-vector-representation": true`. macOS thus tints the icon
  automatically to match the light/dark menu bar; the vector data
  scales losslessly on Retina.

Geometry of the silhouette (18×18 grid):

- Body: teardrop shape, tapering to a point at the bottom (`M9 16.8 C4.6 14.3 2.4 11.4
  2.4 8.1 C2.4 4.5 5.3 1.7 9 1.7 C12.7 1.7 15.6 4.5 15.6 8.1 C15.6 11.4
  13.4 14.3 9 16.8 Z`), eyes as evenodd cutouts (circles r 2.8 at
  x 5.9/12.1, y 8).
- Ear tufts: two wing shapes sweeping outward from the top of the head
  (left `M6.9 3.3 C5.9 1.6 3.9 0.5 0.8 0.9 C2.0 2.0 3.1 3.4 4.2 5.7
  C5.0 4.7 5.9 3.9 6.9 3.3 Z`, right mirrored at x = 9).
- Pupils: filled circles r 1.2, offset slightly toward the center.

### Code: one-line change

In `PromptQuittungApp.swift` the `MenuBarExtra` initializer is switched from
`systemImage: "bell.badge"` to `image: "MenuBarIcon"`. There are no other
code changes.

## Verification

- `xcodebuild … -configuration Release build`: **BUILD SUCCEEDED** —
  also confirms that actool accepts the SVG asset.
- Launch the app: the owl appears in the menu bar, inverts correctly
  between light and dark appearance, the menu opens unchanged.
- SwiftLint runs unchanged in CI (no Swift change other than the
  single line).
