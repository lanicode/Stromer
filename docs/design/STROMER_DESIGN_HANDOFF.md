# Stromer Design Handoff: Bolt

## Direction

Stromer nutzt ab Phase D die visuelle Richtung **Bolt**: ein ruhiges, technisches Off-Grid-Interface mit cream paper background, deep teal primary, electric yellow signal color und einem S-Monogramm mit Lightning-Bolt-Cutout.

Die UI bleibt klar und direkt. Keine Glassmorphism-Surfaces, keine dekorativen Orbs, keine starken Gradienten auf Karten oder Controls. Der einzige Gradient ist ein subtiler Paper-Background.

## Prinzipien

- **Paper first**: Grundflaechen wirken warm, ruhig und lesbar.
- **Deep teal as action color**: Primaere Aktionen und Brand-Marks verwenden tiefes Teal.
- **Electric yellow as signal**: Gelb ist Akzent, Marker und Bolt-Symbol, nicht Flaechenfarbe fuer ganze Screens.
- **Sharp, structured corners**: UI-Surfaces verwenden klare Rechtecke und dezente Radien. Keine pillige Marketing-Optik.
- **Technical but friendly**: Messwerte duerfen monospaced und praezise sein, Begleittexte bleiben kurz und menschlich.

## Color Tokens

| Token | Hex | Verwendung |
| --- | --- | --- |
| `boltCream` | `#F4F1E8` | App-Hintergrund |
| `boltCreamDeep` | `#E8E2D0` | Hintergrundverlauf unten |
| `boltPaper` | `#FBF8F0` | Sections und Controls |
| `boltInk` | `#0E1817` | Primaerer Text |
| `boltInkSoft` | `boltInk 62%` | Sekundaerer Text |
| `boltInkFaint` | `boltInk 35%` | Hilfsinfos |
| `boltHair` | `boltInk 12%` | Borders |
| `boltHair2` | `boltInk 6%` | Row Separators |
| `boltTeal` | `#0E6B64` | Brand, primary action |
| `boltTealDeep` | `#0A4F4A` | Dark brand emphasis |
| `boltTealSoft` | `boltTeal 10%` | Soft brand surface |
| `boltYellow` | `#F6C445` | Bolt signal |
| `boltYellowDeep` | `#D9A422` | Pressed/strong yellow |
| `boltOk` | `#2F8F45` | Fresh/OK |
| `boltWarn` | `#C76A1F` | Delayed/warning |
| `boltBad` | `#B33A2A` | Missing/error/destructive |

## Typography

- **Display**: heavy system font for hero numbers and large titles.
- **Section title**: heavy 30 pt for top-level section headings.
- **Body bold**: 15 pt bold for labels and row titles.
- **Body**: 14 pt regular for supporting copy.
- **Mono**: monospaced for technical sub-data, voltages, IDs and raw values.
- **Eyebrow**: small uppercase labels with wide tracking.

## Brand Mark

The base mark is a teal rounded-square **S** lockup with a yellow lightning bolt overlay. It is a brand primitive for headers, onboarding and later empty states. The bolt glyph is drawn as a custom polygon, not an SF Symbol.

## Component Primitives

Phase D.1 provides only reusable primitives. Existing screens remain unchanged until later phases.

- `BoltGlyph`: custom lightning polygon.
- `BoltSLockup`: teal S monogram with bolt overlay.
- `BoltSection`: paper section with hairline border and optional eyebrow/footer.
- `BoltRowItem`: dense row primitive for settings/detail lists.
- `BoltPrimary` and `BoltSecondary`: uppercase action buttons.
- `BoltSpark`: simple Canvas sparkline.
- `BoltCornerNotch`: yellow top-right triangle accent.
- `BoltBackground`: subtle cream-to-deep-cream paper gradient.

## Non-Goals In D.1

- No redesign of current app screens.
- No widget or Live Activity changes.
- No app icon update.
- No dark mode token variants.
- No asset catalog changes.
