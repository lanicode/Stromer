# Stromer — Design Handoff (Bolt Direction)

> iOS app for live Victron BLE readings — passive Bluetooth, no cloud, no account.
> Visual direction: **Bolt** — cream paper background, deep teal primary, electric yellow signal color, S-monogram with lightning bolt cutout.

---

## Brand DNA

The S-monogram with a yellow lightning bolt punching through it is the brand signature. It appears on the app icon, in every screen header, on the Live Activity card, and inside the home-screen widget. Geometry is sharp and rectilinear — no soft rounded chrome, no glassmorphism, no gradients on UI surfaces (except the subtle paper background).

### Color tokens

| Token       | Hex        | Role                                                  |
|-------------|------------|-------------------------------------------------------|
| `cream`     | `#F4F1E8`  | App background (top of vertical gradient)             |
| `creamDeep` | `#E8E2D0`  | App background (bottom of vertical gradient)          |
| `paper`     | `#FBF8F0`  | Cards, sections, list rows                            |
| `ink`       | `#0E1817`  | Primary text, dark slabs                              |
| `inkSoft`   | `rgba(14,24,23,0.62)` | Secondary text, eyebrows, muted labels      |
| `inkFaint`  | `rgba(14,24,23,0.35)` | Tertiary text, disabled                     |
| `hair`      | `rgba(14,24,23,0.12)` | 1px borders around cards/sections           |
| `hair2`     | `rgba(14,24,23,0.06)` | Internal dividers within cards              |
| `teal`      | `#0E6B64`  | Primary brand color — buttons, primary text accents   |
| `tealDeep`  | `#0A4F4A`  | Hover/pressed teal, status labels                     |
| `tealSoft`  | `rgba(14,107,100,0.10)` | Subtle teal background fills              |
| `bolt`      | `#F6C445`  | Signal color — live indicators, charging, accents     |
| `boltDeep`  | `#D9A422`  | Border on yellow elements                             |
| `ok`        | `#2F8F45`  | Success / fresh data state                            |
| `warn`      | `#C76A1F`  | Warning / delayed data                                |
| `bad`       | `#B33A2A`  | Error / stale or missing                              |

### Typography

- **Display**: SF Pro Display (or system-ui)
  - Heroes: 96–110pt, weight 800, letter-spacing −5 to −6, tabular-numerals
  - Section titles: 30pt, weight 800, letter-spacing −1
  - Body bold: 14–16pt, weight 700
  - Body: 13–15pt, weight 400–500
- **Mono**: SF Mono (or ui-monospace) — for technical sub-data, voltages/currents, peripheral IDs, hex keys
  - Sub-values: 11–13pt, letter-spacing 0.2–1
- **Eyebrow / label** convention: 10–11pt, weight 700–800, letter-spacing 1.4–2.4, UPPERCASE
- All numeric readouts use `font-variant-numeric: tabular-nums`.

### Geometric vocabulary

- **No border-radius** on cards/buttons/tiles — sharp corners throughout, except iOS-system-imposed (app icon ~22.5%, lock-screen Live Activity has rounded corners by iOS spec).
- **Yellow corner notch**: 22–36px right-angle triangle in `bolt` cut into the top-right of dark slabs and accent surfaces. Signature element.
- **Bolt glyph** (small lightning): SVG polygon `points="18,2 4,20 12,20 8,34 24,14 16,14 20,2"` in 28×36 viewBox. `fill: bolt`, `stroke: teal` (1.2px). Used as a tick on progress bars, in status pills, threading through diagrams.
- **Status dots** are 6–8px squares (not circles), in `teal` / `warn` / `bad`.
- **Diamonds**: 8×8px squares rotated 45° in `bolt` — used as bullet-list markers.

### S-Lockup

The brand mark used in headers, widgets, and the Live Activity. Render at 16–30pt:
SVG, 64×64 viewBox:
<rect x="2" y="2" width="60" height="60" rx="14" fill="#0E6B64" />
<text x="32" y="48" text-anchor="middle"
     font-family="system-ui" font-weight="800" font-size="48"
     fill="#F4F1E8" letter-spacing="-2">S</text>
<polygon points="36,14 24,34 32,34 28,50 42,28 34,28 38,14"
        fill="#F6C445" stroke="#0E6B64" stroke-width="1.2" stroke-linejoin="round" />

The same construction at icon scale (1024×1024) is the App Icon — see Brand · App Icon below.

---

## App Icon

1024×1024 SVG. Cream gradient plate, teal "S" set in bold sans, yellow bolt punched through with teal stroke for separation.
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%"   stop-color="#F4F1E8" />
    <stop offset="100%" stop-color="#E6DFCC" />
  </linearGradient>
</defs>
<rect width="1024" height="1024" fill="url(#bg)" />
<text x="512" y="690" text-anchor="middle"
      font-family="system-ui" font-weight="800" font-size="780"
      fill="#0E6B64" letter-spacing="-30">S</text>
<polygon points="540,260 380,560 500,560 460,780 660,460 540,460 580,260"
         fill="#F6C445" stroke="#0E6B64" stroke-width="14" stroke-linejoin="round" />
````
iOS rounds the corners automatically (corner-radius ≈ 22.5% of icon size).

Component primitives
BoltNavBar
Top navigation bar — 44px min-height, 8/14px padding.

Title: centered, 13pt weight 700, letter-spacing 2, UPPERCASE
Optional S-Lockup (20px) immediately left of title
Leading/trailing slots hold BoltNavBtn (12pt UPPERCASE links in teal)

BoltSection { header, footer, children }
Grouped list section.

Outer margin: 18px horizontal
Header: 10pt UPPERCASE letter-spacing 2, color inkSoft, padding 0 18px 6px
Container: paper background, 1px hair border (no radius)
Footer: 11pt italic inkSoft, padding 8px 22px 0

BoltRowItem
List row inside a section.

Padding: 13×14px, 12px gap
Title: 15pt weight 600, color ink (or bad for destructive)
Subtitle: 11pt mono, letter-spacing 0.2
Trailing: 14pt inkSoft
Bottom border: 1px hair2 (omit on last)

BoltPrimary button

Background teal, text cream
Padding 16×18px, no radius
13pt weight 800, letter-spacing 2, UPPERCASE
Optional bolt glyph icon at 14px before label

BoltSecondary button

Transparent, 1px hair border, text ink
Padding 14×18px, 12pt weight 700, letter-spacing 1.6, UPPERCASE

BoltSpark { values, width, height, color }
Inline polyline sparkline — strokeWidth: 1.5, stroke-linejoin: miter, stroke-linecap: square.
BoltGlyph { size, color, stroke }
The signature lightning bolt (see polygon above). Inline SVG, used for ticks, status indicators, thread-through accents.

Screen specifications
1 · Onboarding (3 pages)
Vertical gradient cream → creamDeep, padding 12px 20px 24px. Top row: S-Lockup (28pt) on the left, page counter "01 / 03" right (10pt mono, letter-spacing 2).
Below: hero illustration (80–164px), then eyebrow (10pt UPPERCASE in tealDeep), then title (44pt weight 800, letter-spacing −2, line-height 0.96, supports \n for line breaks). Optional 15pt body text in inkSoft.
If bullets: each row has a 36px-min mono key (e.g. BLE, 01, 02) in teal, then 14pt body in ink. Rows separated by 1px hair lines.
Footer: progress bar (3 segments × 3px tall, fills with teal) + BoltPrimary + optional BoltSecondary.
Page 1 — Welcome

Hero: large S-monogram block (164×164, full-bleed teal square with white S + yellow bolt)
Eyebrow: "STROMER · IOS"
Title: Live-Werte\nohne Cloud.
Body: "Victron Instant Readout direkt am iPhone. Kein Cerbo, kein Account, kein Tracking."
Buttons: Primary "Loslegen" (with bolt glyph), Secondary "Später einrichten"

Page 2 — Was ist Stromer

Hero: stylized 3-band SVG diagram showing BLE → Live → Lokal flow with a vertical bolt threading through the right edge. Each band has a mono label and a sample value (e.g. "−62 dBm", "12.74 V · 86%", "iPhone").
Eyebrow: "WAS IST STROMER"
Title: Drei Sätze.
Bullets:

BLE — Empfängt Victron Advertisements passiv per Bluetooth.
LIVE — SmartShunt, BMV und MPPT in Echtzeit.
LOKAL — Keine Cloud. Keine Synchronisierung. Keine Analytics.



Page 3 — Privatsphäre

Hero: shield silhouette (geometric hexagon-ish, 120×140) with central bolt and "KEYS" band
Eyebrow: "PRIVATSPHÄRE"
Title: Privat by\nDesign.
Bullets (numbered 01–04):

Passive BLE-Advertisements — Stromer schreibt nie an Geräte.
Messwerte bleiben auf diesem iPhone.
Advertisement Keys liegen im Schlüsselbund.
Kein Tracking. Keine Analytics. Kein Account.




2 · Übersicht (Device List)
Vertical gradient cream → creamDeep. Scrollable.
Header (8/18px padding):

Left: S-Lockup (30pt) + "STROMER" wordmark (11pt weight 700, letter-spacing 3.2)
Right: live indicator pill — bolt glyph + "LIVE" inside a 1px teal box, 4×8px padding

Hero "Gesamtladung":

Eyebrow: "GESAMTLADUNG · 3 GERÄTE"
Big number: average SoC across all SmartShunts, 96pt weight 800, letter-spacing −5, with % in 36pt teal
Right-aligned secondary: total PV watts (26pt weight 800) + "SOLAR JETZT" eyebrow
Below: 2px solid ink horizon line spanning full width with a BoltGlyph (12pt) positioned at the SoC% mark

Geräte section:

Header row: "GERÄTE" (eyebrow left) + "BLE · SCANNER AKTIV" (mono right)
Stack of BoltRow cards, 10px gap, 18px horizontal padding

BoltRow device card (paper bg, 1px hair border, no radius):

Three columns:

Left rail (36px wide): 36×36 icon tile — teal square for SmartShunt (battery icon, cream stroke), bolt square for MPPT (sun icon, ink). Below: 9pt mono label (BMV or MPPT)
Middle: status dot (7×7 square, color by freshness) + device name (16pt weight 700) on top row; voltage/current readout (12pt mono) on second row; sparkline (140×18) at bottom
Right: big readout (32pt weight 800, tabular) — SoC% for Shunt, PV W for MPPT. Below: 9pt UPPERCASE state label (LÄDT with bolt glyph if charging, ENTLÄDT, or charger state for solar)



Add Device button:

18px horizontal margin
Full-width, transparent bg, 1.5px dashed teal border
"+ GERÄT HINZUFÜGEN" — 14pt weight 700, letter-spacing 1, UPPERCASE, color teal

Footer: 10×10 teal diamond + 11pt italic inkSoft — "Passive Bluetooth-Advertisements. Werte bleiben auf diesem iPhone."

3 · Detail (Device Detail)
Vertical gradient. Used for both Battery (SmartShunt/BMV) and Solar (MPPT).
Nav (8/14px): back button (< ZURÜCK in teal) on left, S-Lockup on right.
Title block (14/18px):

Eyebrow: device kind + model (e.g. "BATTERY MONITOR · SMARTSHUNT 500A/50MV")
Title: device name (30pt weight 800, letter-spacing −1)

Hero readout slab — paper background, 1px hair border, 18×20px padding, with yellow corner notch (28px right-angle triangle) in top-right:

Big number: SoC% for Shunt or PV W for Solar — 110pt weight 800, letter-spacing −6, line-height 0.9
Unit: 32pt weight 700 in teal, with eyebrow ("LADESTAND" or "LEISTUNG") below
Below: horizontal "spectrum" — 2px hair line full-width with a teal fill at pct%, 11 vertical tick marks (every 10%, longer at 0/50/100), and a BoltGlyph (12pt) positioned at the current %
Footer row: 6×6 teal square + "LIVE · VOR 1 S" (left) and "RSSI -62 DBM" (right, mono)

Stat grid — 2×3 grid of stats inside a single bordered container (paper bg, 1px hair, internal 1px hair2 dividers, no radius):

Each cell: 14×14px padding
Eyebrow (10pt UPPERCASE letter-spacing 1.4) + value (22pt weight 800, tabular) + small unit (12pt weight 700 inkSoft)
Battery: Spannung (V), Strom (A), Verbraucht (Ah), Restzeit (h/m), Temperatur (°C), Status ("Lädt"/"Entlädt")
Solar: Bat. Spg (V), Bat. Strom (A), Ertrag (Wh), Load (A), Status (charger state), Modus ("MPPT")

Actions (18px padding):

Primary: "⚡ LIVE-ANZEIGE STARTEN" (teal bg, cream text, with bolt glyph icon)
Secondary: "GERÄTEINFO" (transparent, 1px hair border)

Footer meta: 10pt mono, inkFaint, justify-between — local-name on left, peripheral ID on right.

4 · Gerät hinzufügen
4a · Discovery
Vertical gradient. NavBar with "ABBRUCH" leading and S-Lockup + title.
Mode segmented control (4/18 padding): 2-column grid, 1px ink border, ink-filled active cell with cream text. Options: "IN DER NÄHE" / "MANUELL".
Scanning indicator (6/18 padding): pulsing 14×14 teal square + "SCANNT · VICTRON INSTANT READOUT" (10pt UPPERCASE letter-spacing 2 in tealDeep).
Discovery cards: stacked, 8px gap. Each card:

36×36 kind tile (teal for Battery, bolt for Solar, hair2 for Other) with bold SF icon
Middle: model name (14pt weight 700) + meta line (11pt mono — kind · RSSI · age in seconds)
Right: status badge (9pt weight 800 UPPERCASE, padded 4×7px, 1px colored border):

HINZUGEFÜGT (tealDeep) — already registered, dimmed
HINZUFÜGEN (teal) — supported, tappable
DECODING FOLGT (warn) — known but not yet decoded
NICHT UNTERSTÜTZT (inkFaint) — dimmed



Footer: 11pt italic — "Liste wird nicht gespeichert. Einträge werden nach kurzer Zeit ausgegraut und entfernt."
4b · Key Entry
NavBar: "ZURÜCK" / title / "SICHERN".
Section "Gerät" (BoltSection):

Name | "House Battery" (right, weight 700)
Modell | "SmartShunt 500A" (mono inkSoft)
Typ | "Battery Monitor" (mono inkSoft)

Section "Advertisement Key" with footer:

Inside section, 14px padding
Hex key displayed in mono 14pt, letter-spacing 1, with cream bg + 1.5px teal border, broken into two lines of 16 chars
Below: "✦ KEY GÜLTIG" (teal diamond + label) on left, "32/32" mono counter on right
Footer: "Der Key bleibt im iOS-Schlüsselbund. Stromer prüft ihn gegen das zuletzt empfangene Advertisement."

Section "Key in VictronConnect finden":

Numbered instruction list 01–04, each step: mono number (teal, weight 800) + 13pt instruction text
Steps:

VictronConnect öffnen und Gerät auswählen.
Geräteeinstellungen → „Instant Readout".
Advertisement Key anzeigen lassen.
Hex-Key kopieren und hier einfügen.



Bottom (20/18 padding): BoltSecondary "DEMO-KEY EINFÜGEN".

5 · Einstellungen
NavBar: title + S-Lockup, trailing "FERTIG".
Status block (8/18 padding) — full-width card with yellow corner notch:

38×38 antenna icon tile (teal if active, hair if paused)
Middle: "BLUETOOTH SCANNER" eyebrow + "Aktiv · sucht Advertisements" or "Pausiert" (17pt weight 800)
Right: 28×14 toggle (no radius, sliding 10×10 cream knob inside)

Section "Bluetooth":

Berechtigung — "✦ ERLAUBT" (teal diamond + tealDeep label)
Scanner — "SCANNT" / "PAUSIERT" (12pt UPPERCASE letter-spacing 1.4)
Action row: refresh icon + "Scanner stoppen" / "Scanner neu starten" (in teal)
Footer: "Im Hintergrund empfängt iOS Victron-Advertisements opportunistisch. Stromer zeigt deshalb immer den letzten bekannten Wert mit Aktualitätsstatus."

Section "Privatsphäre" — 14×16 padding, list of 4 items, each with an 8×8 yellow rotated-square bullet:

Passive BLE-Scans — Stromer schreibt nie an Geräte.
Lokale Speicherung — Messwerte bleiben auf diesem iPhone.
Schlüsselbund — Advertisement Keys werden im iOS Keychain abgelegt.
Keine Cloud · kein Tracking — Keine Analytics. Kein Account.

Section "App":

Version | 1.0 (3.6) (mono)
Build | 2026.05.02 (mono)
"Onboarding erneut anzeigen" → chevron right
"Open-Source-Lizenzen" → chevron right


6 · Lock Screen Live Activity
Background: dark gradient #1a2129 → #050708. White text.
Above the Live Activity: time block (cream-white) — "Donnerstag, 2. Mai" (14pt weight 600) and the time (92pt weight 200, letter-spacing −3).
Live Activity card — placed at bottom of lock screen with 16/12 padding:

Background: ink, with 1px rgba(246,196,69,0.4) border
Yellow corner notch (22px) top-right
16px padding, 14px gap horizontal layout:

44×44 kind tile (teal for Battery, bolt for Solar) with SF icon
Middle: S-Lockup (16pt) + "STROMER · LIVE" (9pt yellow UPPERCASE)

Device name (14pt weight 700 cream)
Sub-meta (11pt mono with 55% opacity cream)


Right: big readout (38pt weight 800 yellow) + small unit

Bottom: bolt glyph + "VOR 1S" (9pt UPPERCASE 70%-cream)





iOS home-indicator bar at the very bottom.

7 · Home Screen Widgets
Wallpaper background: dark blue gradient. iOS dock with 4 placeholder app tiles at bottom (search pill above grid).
Hero widget (large, 4×2 spec) — cream gradient with yellow corner notch + 22px radius (Apple-required):

S-Lockup + "STROMER" eyebrow
Big SoC number (64pt weight 800)
"GESAMTLADUNG" eyebrow
Horizon line (2px ink) with bolt glyph at SoC%
Three meta columns at bottom: each device's name eyebrow + voltage / power (14pt weight 700)

Two small widgets (2×2) below, side by side, 16px gap:

Solar widget: ink bg, yellow corner notch, "SOLAR" eyebrow in yellow, watts readout (44pt weight 800 cream), "WATT JETZT" eyebrow, sparkline at bottom in yellow
Battery widget: cream bg with hair border, S-Lockup + "HAUS" eyebrow, SoC% (44pt weight 800), "LADESTAND" eyebrow, ink horizon line with bolt glyph

All widgets are 22px corner-radius (iOS widget standard) — this is the only place in the design with rounded corners on app surfaces.

Mock data (use as fixtures)
json{
  "devices": [
    {
      "id": "d1",
      "name": "House Battery",
      "kind": "shunt",
      "model": "SmartShunt 500A/50mV",
      "productID": "0xA389",
      "localName": "SmartShunt HQ23B47PXMQ",
      "rssi": -62,
      "peripheralID": "B7E2-3F4A-...-D9A1",
      "freshness": "fresh",
      "values": { "soc": 86, "voltage": 12.74, "current": -2.1, "consumed": 18.4, "ttg": 1240, "temperature": 22.1 }
    },
    {
      "id": "d2",
      "name": "Roof Solar",
      "kind": "solar",
      "model": "SmartSolar MPPT 100/50",
      "productID": "0xA057",
      "localName": "SmartSolar HQ22A91XR",
      "rssi": -71,
      "peripheralID": "4C1F-9E8B-...-2A33",
      "freshness": "fresh",
      "values": { "pvPower": 312, "batteryVoltage": 13.92, "batteryCurrent": 18.4, "yieldToday": 1342, "loadCurrent": 0.4, "state": "bulk" }
    },
    {
      "id": "d3",
      "name": "Starter Battery",
      "kind": "shunt",
      "model": "BMV-712 Smart",
      "productID": "0xA381",
      "localName": "BMV HQ20Y91MTM",
      "rssi": -84,
      "peripheralID": "A33F-12CC-...-FF02",
      "freshness": "delayed",
      "lastSeenSecondsAgo": 480,
      "values": { "soc": 96, "voltage": 12.91, "current": 0.0, "consumed": 1.2, "ttg": null, "temperature": 19.4 }
    }
  ],
  "discoveryFeed": [
    { "peripheralID": "B7E2", "model": "SmartShunt 500A/50mV",   "kind": "Battery Monitor", "rssi": -62, "status": "registered" },
    { "peripheralID": "4C1F", "model": "SmartSolar MPPT 100/50", "kind": "Solar Charger",   "rssi": -71, "status": "registered" },
    { "peripheralID": "9D81", "model": "SmartSolar MPPT 75/15",  "kind": "Solar Charger",   "rssi": -78, "status": "supported" },
    { "peripheralID": "C234", "model": "Phoenix Inverter 12/500","kind": "Inverter",        "rssi": -83, "status": "planned" },
    { "peripheralID": "EF55", "model": "Lynx Smart BMS",         "kind": "Lynx BMS",        "rssi": -80, "status": "outOfScope" }
  ]
}
Freshness rules

fresh: last advertisement received < 60s ago — show teal status dot, "LIVE" indicator
delayed: 60s – 30min ago — show warn status dot, label "VERZÖGERT"
stale: > 30min — show muted dot, label "ALT"
missing: > 24h — show bad dot, label "FEHLT"

State labels (charger)
off → Aus, bulk → Bulk, absorption → Absorption, float → Float, storage → Lagerung

Implementation notes

Target: iOS 17+, SwiftUI preferred. Live Activity uses ActivityKit; widgets use WidgetKit with App Group + Keychain sharing for the advertisement keys.
BLE: passive scanning only via CoreBluetooth (scanForPeripherals with no connection). Decode Victron Instant Readout records using the registered advertisement key — see Victron's protocol doc for IV/cipher specifics.
Persistence: device list + display preferences in user defaults; advertisement keys exclusively in Keychain (kSecClassGenericPassword, accessible after first unlock); no analytics frameworks, no third-party tracking SDKs.
Background: rely on iOS opportunistic BLE delivery; never claim 100% live freshness — always render lastSeenSecondsAgo and degrade UI through the freshness states above.
Localization: copy is German (de). Keep all string keys lifted into a Localizable.strings file; UPPERCASE labels should be applied at render time via text-transform, not stored uppercased.
