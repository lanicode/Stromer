# Phase 3.6 - Onboarding, Polish und App-Store-Reife

Status: Architektur-Dokumentation. Keine Implementation.

Diese Phase macht Stromer von einer funktionierenden technischen App zu einem
produktreifen iOS-Erlebnis: verständlicher erster Start, klare Empty States,
verlässlichere Widget-Aktualisierung, Privacy-Kommunikation, App-Icon und
App-Store-Materialien.

## Quellen

- `docs/PHASE_3_5_DISCOVERY.md`
- `docs/IOS_BLE_SCANNER.md`
- `Stromer/Info.plist`
- `Stromer/Views/Root/StromerAppViewModel.swift`
- `Stromer/Views/DeviceList/DeviceListView.swift`
- `StromerWidget/StromerWidget.swift`
- `Stromer/Views/Root/RootView.swift`
- Apple HIG Onboarding:
  https://developer.apple.com/design/human-interface-guidelines/onboarding
- Apple HIG App Icons:
  https://developer.apple.com/design/human-interface-guidelines/app-icons

Hinweis zum aktuellen Repo-Stand: `StromerWidgetEntry.swift` existiert nicht als
separate Datei; `StromerWidgetEntry` ist aktuell in `StromerWidget.swift`
definiert.

## 1. Übersicht und Sub-Phasen-Aufteilung

Phase 3.6 wird in fünf eigenständig implementierbare Sub-Phasen aufgeteilt. Jede
Sub-Phase soll alleine buildbar, reviewbar und mergbar sein. Spätere Sub-Phasen
dürfen von bereits gemergten Verbesserungen profitieren, dürfen aber keine harte
Voraussetzung darauf haben.

| Phase | Titel | Ziel | Haupt-Diff |
| --- | --- | --- | --- |
| 3.6a | App-Icon | Eigenes Icon-Artwork und vollständige AppIcon-Assets | `Assets.xcassets`, ggf. Render-Skript oder Quelldatei |
| 3.6b | Onboarding | Erststart-Flow mit BLE-Erklärung, Privacy und Key-Hilfe | neue Onboarding-Views, kleiner Root-Wire-up |
| 3.6c | Empty States | Konsistente leere, fehlende und blockierte Zustände | SwiftUI-Views und Textpolitur |
| 3.6d | Widget Refresh | Debounced Widget-Reloads und bessere Stale-Darstellung | App-Wire-up, Widget-Snapshot/View-Anpassungen |
| 3.6e | Store & Privacy | Privacy Policy und App-Store-Texte in DE/EN | neue Markdown-Dokumente, ggf. Plist-Metadaten |

Unabhängigkeitsregeln:

- 3.6a darf nur Assets und projektnahe Asset-Metadaten ändern.
- 3.6b darf ohne finales Icon funktionieren und nur die bestehende App-UI
  ergänzen.
- 3.6c darf bestehende Views verbessern, ohne Onboarding vorauszusetzen.
- 3.6d darf nur auf vorhandene Readings und Snapshots aufbauen.
- 3.6e erzeugt Textartefakte und darf keine Runtime-Logik verändern.

Apple-HIG-Leitplanken:

- Onboarding soll kurz, fokussiert und optional bleiben.
- Permission-Prompts sollen erst nach einer verständlichen Erklärung erscheinen.
- Nutzer sollen später wieder auf die Anleitung zugreifen können.
- App-Icons sollen einfach, eigenständig, zentriert, skalierbar und ohne
  unnötigen Text gestaltet sein.
- SF Symbols dürfen als Inspiration dienen, aber nicht unverändert als
  App-Icon-Asset verwendet werden.

## 2. App-Icon-Konzept (Sub-Phase 3.6a)

Stromer ist eine Victron-BLE-Monitoring-App für Wohnmobile, Boote und
Off-Grid-Setups. Das Icon muss auch in kleinen Größen sofort als
Energie-/Solar-/Batterie-Thema lesbar sein und darf nicht wie ein Victron- oder
Apple-Produkt aussehen.

Design-Anforderungen:

- Eigenes Artwork, nicht nur ein SF Symbol.
- Keine Textmarke im Icon.
- Zentriertes Hauptmotiv mit sicherem Rand.
- Gute Lesbarkeit bei 1024x1024, 180x180, 60x60 und 29x29.
- Default-, Dark- und Tinted-Home-Screen-Modi sollen erkennbar bleiben.
- Keine Nachbildung von Apple-Hardware oder Victron-Branding.
- Ruhige Lanicode-Ästhetik: klar, reduziert, technisch, nicht verspielt.

Konzept A: Sonne und Batterie

```text
+----------------+
|    \  |  /     |
|  --  SUN  --   |
|                |
|    +------+    |
|    |█████ |    |
|    +------+    |
+----------------+
```

Beschreibung:

- Hintergrund: tiefer, aber nicht schwarzer Blaugrün-Verlauf.
- Vordergrund: abstrahierte Sonne als Kreis mit wenigen Strahlen, darunter eine
  reduzierte Batterieform.
- Aussage: Solarenergie lädt Batterie. Sehr direkt, auch klein verständlich.
- Risiko: Batterie-Icon kann generisch wirken; braucht eigene Proportionen und
  keinen Standard-SF-Symbol-Look.

Konzept B: Lightning-Bolt und Camper-Silhouette

```text
+----------------+
|       ⚡        |
|     /----\     |
|    |_____|     |
|    o     o     |
+----------------+
```

Beschreibung:

- Hintergrund: dezenter Petrol- oder Nachtblau-Verlauf.
- Vordergrund: einfacher Blitz über einer stark abstrahierten Camper-Kontur.
- Aussage: mobile Energie im Camper.
- Risiko: Boot-Nutzer fühlen sich weniger direkt angesprochen; Camper-Silhouette
  darf nicht zu detailliert werden.

Konzept C: Solar-Sinus und Ladestand

```text
+----------------+
|  ~~~  ~~~      |
|      /         |
|  ---/---       |
|    /  ███      |
+----------------+
```

Beschreibung:

- Hintergrund: warmes Solar-Gelb zu tiefem Grünblau.
- Vordergrund: stilisierte Sinus-/Stromkurve, die in einen Ladestand-Balken
  übergeht.
- Aussage: Stromfluss, Monitoring und Energie.
- Risiko: Abstrakter als Sonne+Batterie; braucht starke Kontraste für kleine
  Größen.

Empfehlung:

- Für 3.6a Konzept A umsetzen. Es ist am schnellsten verständlich und passt zu
  SmartShunt/MPPT als aktueller Kernfunktion.
- Konzept B als mögliche Alternate-App-Icon-Idee parken, falls später ein
  stärkerer Camper-Fokus gewünscht ist.

Asset-Catalog-Struktur:

```text
Stromer/Assets.xcassets/
  AppIcon.appiconset/
    Contents.json
    Stromer-AppIcon-1024.png
    Stromer-AppIcon-180.png
    Stromer-AppIcon-167.png
    Stromer-AppIcon-152.png
    Stromer-AppIcon-120.png
    Stromer-AppIcon-87.png
    Stromer-AppIcon-80.png
    Stromer-AppIcon-76.png
    Stromer-AppIcon-60.png
    Stromer-AppIcon-58.png
    Stromer-AppIcon-40.png
    Stromer-AppIcon-29.png
```

Benötigte iOS-Größen:

| Usage | Size | Scale | Pixel |
| --- | ---: | ---: | ---: |
| App Store | 1024pt | 1x | 1024x1024 |
| iPhone App | 60pt | 2x / 3x | 120x120 / 180x180 |
| iPad App | 76pt | 1x / 2x | 76x76 / 152x152 |
| iPad Pro App | 83.5pt | 2x | 167x167 |
| Spotlight | 40pt | 2x / 3x | 80x80 / 120x120 |
| Settings | 29pt | 2x / 3x | 58x58 / 87x87 |
| Notification | 20pt | 2x / 3x | 40x40 / 60x60 |

Farben:

- Hintergrund oben: `#0E6B64` oder ähnlich ruhiges Teal.
- Hintergrund unten: `#102C3A` für Tiefe und Dark-Mode-Kompatibilität.
- Solar-Akzent: `#F6C445`.
- Batterie-/Glyph-Fläche: `#F7F8F2`.
- Sekundärgrün: `#7BC86C`.

Render-Strategie:

- Bevorzugt: eigenes SwiftUI- oder CoreGraphics-Render-Skript erzeugt PNGs aus
  einfachen geometrischen Formen.
- Alternative: SVG/PDF-Quelle einchecken und daraus PNGs exportieren.
- Keine unveränderten SF-Symbol-Pfade übernehmen. SF Symbols nur als
  Größen-/Gewichtsreferenz verwenden.
- Vor Merge in 3.6a müssen mindestens 1024x1024, 180x180, 120x120, 60x60 und
  29x29 visuell geprüft werden.

## 3. Onboarding-Konzept (Sub-Phase 3.6b)

Onboarding wird nur beim ersten Start gezeigt und bleibt überspringbar. Es soll
nicht als Marketing-Slider wirken, sondern die wenigen Dinge erklären, ohne die
Stromer schwer verständlich ist: passives BLE, lokale Daten, Advertisement Key
und erster Geräteschritt.

Persistenz:

- Key: `hasCompletedOnboarding`
- Speicher: `UserDefaults.standard` oder App-Group-UserDefaults.
- Empfehlung: App-Group-UserDefaults vermeiden, da Widget/Extension diesen
  Status nicht benötigen.
- Settings ergänzt einen Button `Onboarding erneut anzeigen`, der den Status
  zurücksetzt oder den Onboarding-Flow modal öffnet.

Root-Wire-up:

```text
StromerApp
  -> RootView
      -> wenn !hasCompletedOnboarding: OnboardingFlowView
      -> sonst: NavigationStack(DeviceListView)
```

Der Scanner darf unabhängig vom Onboarding bootstrappen. Der BLE-Prompt soll
aber erst durch Screen 3 bzw. durch aktive Discovery-Nutzung ausgelöst werden,
damit Nutzer die Begründung vorher sehen.

Screen 1: Willkommen

```text
Stromer

Live-Werte für deine Victron-Geräte.
Direkt auf dem iPhone, ohne Cloud.

[Weiter]
[Später einrichten]
```

Komponenten:

- `VStack` mit App-Icon/temporärem Energie-Symbol.
- Titel `Stromer`.
- Tagline: `Victron-Livewerte ohne Cerbo GX`.
- Primärbutton `Weiter`.
- Sekundärbutton `Später einrichten`, setzt `hasCompletedOnboarding = true`.

Animation:

- Sanfter Fade-in des Symbols.
- Kein Vollbildvideo, keine entfernten Assets.

Screen 2: Was ist Stromer?

```text
Was ist Stromer?

- Empfängt Victron Instant Readout per Bluetooth.
- Zeigt SmartShunt/BMV und MPPT-Livewerte direkt an.
- Weitere Familien wie Orion Smart folgen.
- Kein Cerbo GX und keine Cloud nötig.

[Weiter]
```

Komponenten:

- `List` oder `VStack` mit drei bis vier Feature-Zeilen.
- Icons: `dot.radiowaves.left.and.right`, `battery.100`, `sun.max`,
  `icloud.slash`.
- Hinweis auf aktuelle Decoder-Grenze: SmartShunt/BMV und MPPT live,
  geplante Geräte registrierbar für spätere Decoder.

Screen 3: Bluetooth-Erklärung

```text
Bluetooth wird gebraucht

Stromer scannt nach Victron-Advertisements in deiner Nähe.
Es wird keine Verbindung aufgebaut und nichts an Geräte geschrieben.

[Bluetooth aktivieren]
[Überspringen]
```

Komponenten:

- `ContentUnavailableView`-ähnlicher Aufbau mit `bluetooth`.
- Button `Bluetooth aktivieren`.
- Aktion: Scannerstart oder eine kleine BLE-Operation, die den
  `NSBluetoothAlwaysUsageDescription`-Prompt auslöst.
- Nach `allowed`, `denied` oder `restricted` darf der Nutzer weiter. Bei
  `denied` wird erklärt, dass Discovery später über Einstellungen aktiviert
  werden kann.

Animation:

- Kurzer State-Wechsel von `Noch nicht gefragt` zu Ergebnis-Badge.
- Keine blockierende Warteanimation, wenn iOS keinen Prompt zeigt.

Screen 4: Privacy-Zusicherung

```text
Privat by Design

- Passive Victron-BLE-Advertisements.
- Messwerte bleiben lokal auf deinem iPhone.
- Advertisement Keys liegen im iOS-Schlüsselbund.
- Keine Cloud, kein Tracking, keine Analytics.
- Discovery zeigt fremde Victron-Geräte nur als Modell/Typ,
  Messwerte bleiben verschlüsselt.

[Weiter]
```

Komponenten:

- Kurze Privacy-Karten oder einfache Zeilen mit Checkmark-Icons.
- Kein juristischer Volltext im Onboarding.
- Link `Datenschutzhinweise lesen` kann später auf 3.6e-Policy verweisen.

Screen 5: Wie finde ich den Advertisement Key?

```text
Advertisement Key finden

1. VictronConnect öffnen.
2. Gerät auswählen.
3. Zahnrad öffnen.
4. Product Info öffnen.
5. Instant Readout Details anzeigen.
6. 32-stelligen Key kopieren.

[Weiter]
```

Komponenten:

- `TabView` oder `VStack` mit nummerierten Schritten.
- Optional später: kleine lokale Screenshot-Illustrationen.
- Für 3.6b reichen textbasierte Schritte plus Icons, weil echte
  VictronConnect-Screenshots rechtlich und gestalterisch separat geprüft werden
  müssen.

Screen 6: Erstes Gerät hinzufügen

```text
Erstes Gerät hinzufügen

Wir suchen jetzt nach Victron-Geräten in deiner Nähe.
Du kannst dein Gerät auch später manuell hinzufügen.

[Gerät suchen]
[Onboarding abschließen]
```

Komponenten:

- Primärbutton `Gerät suchen`: setzt `hasCompletedOnboarding = true` und öffnet
  `AddDeviceView` mit Discovery-Tab.
- Sekundärbutton `Onboarding abschließen`: schließt ohne Add-Sheet.
- Bei fehlender Bluetooth-Berechtigung: Button `Manuell hinzufügen`.

Navigation und Animation:

- `TabView` mit `.page`-Style oder eigener `NavigationStack` mit Index.
- Empfehlung: horizontaler Slide zwischen Screens, statische Inhalte.
- Fortschrittsanzeige als sechs kleine Punkte oder `ProgressView(value:)`.
- Keine langen Animationen, weil HIG ein kurzes, fokussiertes Onboarding
  empfiehlt.

View-Struktur:

```text
Stromer/Views/Onboarding/
  OnboardingFlowView.swift
  OnboardingPageView.swift
  OnboardingBluetoothPage.swift
  OnboardingKeyGuideView.swift
  OnboardingState.swift
```

ViewModel:

- `@Observable final class OnboardingViewModel`
- UI-State: current page, bluetooth status snapshot, completion.
- Delegiert BLE/Scanner-Aktionen an `StromerAppViewModel`.
- Kein direkter Keychain- oder CoreBluetooth-Zugriff in Views.

## 4. Empty States (Sub-Phase 3.6c)

Alle Empty States sollen `ContentUnavailableView` verwenden, wenn die Struktur
passt. Tonalität: ruhig, hilfreich, ohne Schuldzuweisung.

| Ort | Icon | Titel | Beschreibung | Action |
| --- | --- | --- | --- | --- |
| Hauptliste ohne Geräte | `dot.radiowaves.left.and.right` | Noch keine Victron-Geräte | Füge dein erstes Victron-Gerät hinzu. Stromer kann SmartShunt/BMV und MPPT live anzeigen. | `Gerät hinzufügen` |
| Discovery sucht, noch keine Treffer | `antenna.radiowaves.left.and.right` | Suche läuft | Stromer sucht nach Victron-Geräten mit aktivem Instant Readout. | keine oder `Manuell hinzufügen` nach kurzer Verzögerung |
| Discovery nach 30s ohne Treffer | `magnifyingglass` | Keine Victron-Geräte gefunden | Prüfe, ob Bluetooth aktiv ist, das Gerät in Reichweite ist und Instant Readout in VictronConnect eingeschaltet ist. | `Manuell hinzufügen` |
| Discovery bei Bluetooth aus | `bluetooth.slash` | Bluetooth ist ausgeschaltet | Schalte Bluetooth ein, damit Stromer Geräte in der Nähe finden kann. | `Einstellungen öffnen` oder Systemhinweis |
| Discovery bei verweigerter Permission | `hand.raised` | Bluetooth-Zugriff abgelehnt | Erlaube Bluetooth in den iOS-Einstellungen oder füge das Gerät manuell hinzu. | `Einstellungen öffnen` |
| DeviceDetail ohne Daten | `wave.3.right` | Noch keine Live-Daten | Sobald Stromer ein passendes Advertisement empfängt, erscheinen hier die Werte. | `Scanner neu starten` |
| DeviceDetail für registriertes plannedPhase37-Gerät | `clock.arrow.circlepath` | Decoding folgt | Dieses Gerät ist registriert. Live-Werte erscheinen nach einem späteren Decoder-Update. | keine |
| Live Activity ohne Reading | `rectangle.on.rectangle.slash` | Noch kein Live-Wert | Die Live-Anzeige kann gestartet werden, sobald ein erstes Advertisement empfangen wurde. | keine |
| Settings ohne registrierte Geräte | `gearshape` | Noch nichts eingerichtet | Bluetooth-Status und Scanner-Steuerung sind bereit. Füge ein Gerät hinzu, um Live-Werte zu sehen. | `Gerät hinzufügen` |
| Widget ohne Geräte | `plus.circle` | Gerät hinzufügen | Öffne Stromer und registriere ein Victron-Gerät. | keine, Widgets sind read-only |
| Widget-Gerät gelöscht | `questionmark.circle` | Gerät nicht mehr vorhanden | Wähle in der Widget-Konfiguration ein anderes Gerät. | keine |

Konkrete Verbesserungen gegenüber dem aktuellen Stand:

- Hauptliste nennt zusätzlich Discovery statt nur manuelles Hinzufügen.
- Discovery trennt `Suche läuft` von `wirklich nichts gefunden`.
- Bluetooth-Fehler unterscheiden `aus` von `Berechtigung abgelehnt`.
- DeviceDetail bekommt eine Aktion `Scanner neu starten`, wenn ein Gerät zwar
  registriert, aber ohne Reading ist.
- Settings bekommt einen Onboarding-Button und eine kleine Geräte-Sektion, die
  bei null Geräten nicht leer wirkt.

## 5. Widget-Refresh-Architektur (Sub-Phase 3.6d)

Ziel: Widgets sollen bei aktiver App zeitnah neue Werte anzeigen, ohne Apples
Widget-Refresh-Budget unnötig zu verbrennen. Im Hintergrund bleibt die Anzeige
ehrlich: letzter bekannter Wert plus Alter.

Aktueller Stand:

- `StromerAppViewModel` übergibt an `ScannerService` bereits einen
  `onReadingUpdated`-Hook.
- Dieser Hook ruft aktuell direkt `WidgetCenter.shared.reloadAllTimelines()`.
- Zusätzlich wird beim Persistieren registrierter Geräte ein Widget-Reload
  ausgelöst.

Zielzustand:

- `ScannerService` bleibt WidgetKit-frei und sendet weiter nur
  `onReadingUpdated`.
- App-Layer ersetzt den direkten Reload durch einen `WidgetRefreshCoordinator`.
- Der Coordinator debounced Reloads auf mindestens 30 Sekunden Abstand.
- Bei App-Wechsel in den Background wird ein letzter Reload sofort erlaubt.
- Beim Rückkehr in den Foreground wird ein sofortiger Reload erlaubt.
- Device-Registrierung und Device-Löschung lösen weiterhin sofortige Reloads
  aus, weil Widget-Konfigurationen sonst veraltete Geräte zeigen können.

Empfohlene Struktur:

```text
ScannerService.onReadingUpdated(reading)
    -> WidgetRefreshCoordinator.requestReload(reason: .reading)
        -> wenn letzter Reload >= 30 s: WidgetCenter.reloadAllTimelines()
        -> sonst pending markieren

scenePhase -> .background
    -> WidgetRefreshCoordinator.forceReload(reason: .background)

scenePhase -> .active
    -> WidgetRefreshCoordinator.forceReload(reason: .foreground)
```

Debounce-Regeln:

- Standarddebounce: 30 Sekunden.
- Sofort erlaubt bei:
  - App wird aktiv.
  - App geht in den Hintergrund.
  - Gerät hinzugefügt/gelöscht.
  - Widget-relevante Snapshot-Struktur ändert sich.
- Nicht sofort bei:
  - mehreren BLE-Advertisements in kurzer Folge.
  - reinem RSSI-Rauschen ohne neues Reading.

Stale-Color-Coding im Widget:

| Reading-Alter | Semantik | Farbe |
| ---: | --- | --- |
| `< 2 Min.` | frisch | `.primary` plus grüner Indikator |
| `2-30 Min.` | verzögert | `.secondary` |
| `30 Min. - 6 Std.` | alt | `.orange` |
| `> 6 Std.` | sehr alt | `.red` |

Wichtig: Diese Widget-Farben sind feiner als `DeviceFreshness`, dessen aktuelle
Schwellen für die App-Liste `<120s`, `120-600s`, `600-86400s`, `>86400s`
sind. Für Widgets empfiehlt sich daher eine neue Snapshot-Property statt einer
Änderung an `DeviceFreshness`.

Neue Property im Widget-Snapshot:

```text
StromerWidgetDeviceSnapshot
  lastUpdated: Date?
  relativeLastUpdated: String
  widgetFreshness: WidgetFreshness
```

`WidgetFreshness`:

```text
fresh        < 2 min
delayed      2-30 min
stale        30 min - 6 h
missing      > 6 h oder kein Datum
```

Ort der Color-Logic:

- Alter berechnen in `StromerWidgetSnapshotProvider`, weil dort `nowProvider`
  testbar injiziert ist.
- Farbe mappen in `StromerWidget.swift`, weil `Color` SwiftUI-spezifisch ist.
- Tests im `StromerScanner`-Package prüfen nur `WidgetFreshness`, nicht
  SwiftUI-Farben.

Mockup `systemSmall`:

```text
SmartShunt

86 %
SoC

12.7 V · -2.1 A
● vor 1 Min.
```

Mockup stale:

```text
SmartSolar

320 W
PV-Leistung

14.2 V · 1.3 kWh
● vor 42 Min.   (orange)
```

Mockup missing:

```text
MPPT

-- W
PV-Leistung

Keine neuen Daten
● vor 7 Std.   (rot)
```

Last-Updated-Label:

- Immer sichtbar, auch im kleinen Widget.
- Deutsch kurz: `gerade eben`, `vor X Min.`, `vor X Std.`, `vor X Tagen`.
- Accessory Inline darf aus Platzgründen kürzen: `Stromer: 86% vor 3 Min.`

## 6. Privacy Policy (Sub-Phase 3.6e - Teil 1)

In Phase 3.6e werden zwei neue Dateien angelegt:

- `docs/privacy_policy_de.md`
- `docs/privacy_policy_en.md`

Die folgenden Texte sind Entwürfe für Struktur und Inhalt, nicht die finale
juristische Fassung.

### Entwurf Deutsch

Titel: `Datenschutzerklärung für Stromer`

Stand: `1. Mai 2026`

Verantwortlicher:

- `Lanicode UG i.G.`
- Adresse: `Platzhalter, rechtliche Adresse spaeter ergaenzen`
- Kontakt: `privacy@lanicode.com`

Welche Daten Stromer empfängt:

- BLE-Advertisements von Victron-Geräten in der Nähe.
- Darin enthaltene Header-Daten wie Product ID, Gerätetyp, Local Name, RSSI und
  Zeitstempel.
- Verschlüsselte Messdaten, die nur mit dem vom Nutzer eingegebenen
  Advertisement Key entschlüsselt werden können.

Welche Daten gespeichert werden:

- Registrierte Geräte mit Name, app-interner UUID, optionaler
  `CBPeripheral.identifier`, Local Name, Product ID und Gerätetyp.
- Advertisement Keys im iOS-Schlüsselbund.
- Letzte Messwerte und Zeitstempel im App-Group-Speicher für App, Widget und
  Live Activity.

Welche Daten nicht übertragen werden:

- Keine Cloud-Synchronisierung.
- Keine Analytics.
- Kein Tracking.
- Keine Weitergabe an Dritte.
- Keine Serverkommunikation für Messwerte oder Keys.

Rechtsgrundlage / Zweck:

- Lokale Verarbeitung zur Anzeige von Victron-Livewerten, Widgets und Live
  Activities.
- Nutzer registrieren Geräte aktiv und können sie jederzeit löschen.

Löschung:

- Beim Löschen eines Geräts entfernt Stromer den Key aus dem iOS-Schlüsselbund
  und löscht gespeicherte letzte Messwerte.
- App-Löschung entfernt App-Daten nach iOS-Systemverhalten; `ThisDeviceOnly`-
  Keychain-Items migrieren nicht auf neue Geräte.

DSGVO-Rechte:

- Auskunft
- Berichtigung
- Löschung
- Einschränkung der Verarbeitung
- Widerspruch
- Beschwerde bei einer Datenschutzaufsichtsbehörde

Kontakt:

- `privacy@lanicode.com`

### Draft English

Title: `Privacy Policy for Stromer`

Effective date: `May 1, 2026`

Controller:

- `Lanicode UG i.G.`
- Address: `placeholder, add legal address later`
- Contact: `privacy@lanicode.com`

Data Stromer receives:

- BLE advertisements from nearby Victron devices.
- Header data such as product ID, device type, local name, RSSI, and timestamp.
- Encrypted measurement data that can only be decoded with the advertisement key
  entered by the user.

Data Stromer stores:

- Registered devices with name, app-generated UUID, optional
  `CBPeripheral.identifier`, local name, product ID, and device type.
- Advertisement keys in the iOS Keychain.
- Latest readings and timestamps in the App Group container for the app, widget,
  and Live Activity.

Data Stromer does not transmit:

- No cloud sync.
- No analytics.
- No tracking.
- No sharing with third parties.
- No server transfer of readings or keys.

Purpose:

- Local processing to display Victron live values, widgets, and Live Activities.
- Users actively register devices and can delete them at any time.

Deletion:

- Deleting a device removes its key from the iOS Keychain and removes stored
  latest readings.
- Deleting the app removes app data according to iOS system behavior;
  `ThisDeviceOnly` keychain items do not migrate to other devices.

GDPR rights:

- Access
- Rectification
- Erasure
- Restriction of processing
- Objection
- Complaint with a supervisory authority

Contact:

- `privacy@lanicode.com`

App-Store-Submission:

- Für App Store Connect wird eine öffentlich erreichbare Privacy-Policy-URL
  benötigt.
- URL-Bereitstellung ist Teil von 3.6e oder Phase 3.8, nicht dieser
  Architektur-Task.

## 7. App-Store-Description (Sub-Phase 3.6e - Teil 2)

In Phase 3.6e werden zwei neue Dateien angelegt:

- `docs/app_store_description_de.md`
- `docs/app_store_description_en.md`

Die folgenden Texte sind Entwürfe. Zeichenlimits müssen in 3.6e final geprüft
werden.

### Deutsch

App-Name:

- `Stromer`

Untertitel, max. 30 Zeichen:

- `Victron Live-Monitor`

Promotional Text, max. 170 Zeichen:

- `Live-Werte von SmartShunt und MPPT direkt per Bluetooth - ohne Cloud, ohne Cerbo GX, mit Widget und Live-Anzeige.`

Beschreibung:

```text
Stromer zeigt Live-Werte deiner Victron-Geräte direkt auf dem iPhone.
Ideal für Wohnmobil, Boot und Off-Grid-Setup.

Empfange Victron Instant Readout per Bluetooth und behalte Batterie und Solar
im Blick, ohne dich mit einem Cerbo GX oder einer Cloud verbinden zu müssen.

Funktionen:
- Live-Werte für SmartShunt/BMV und SmartSolar/BlueSolar MPPT
- Geräte-Discovery für Victron Instant Readout
- Sichere lokale Speicherung des Advertisement Keys im iOS-Schlüsselbund
- Homescreen- und Lockscreen-Widgets
- Live Activity und Dynamic Island für aktuelle Werte
- Aktualitätsstatus mit letzter Aktualisierung
- Keine Cloud, kein Tracking, keine Analytics

Weitere Victron-Gerätefamilien wie Orion Smart, Phoenix Inverter,
SmartLithium, Phoenix Smart IP43 Charger und Smart BatteryProtect sind für
spätere Updates vorbereitet.

Hinweis:
Stromer ist kein offizielles Produkt von Victron Energy. Für die Nutzung muss
Instant Readout in VictronConnect aktiviert sein. Den Advertisement Key findest
du in VictronConnect unter Product Info / Instant Readout Details.
```

Keywords, max. 100 Zeichen:

- `victron,smartshunt,mppt,solar,batterie,wohnmobil,boot,offgrid,bluetooth,widget`

Was ist neu:

- `Erste TestFlight-Version mit Victron BLE Discovery, SmartShunt/MPPT-Livewerten, Widget und Live Activity.`

### English

App name:

- `Stromer`

Subtitle, max. 30 characters:

- `Victron Live Monitor`

Promotional Text, max. 170 characters:

- `Monitor SmartShunt and MPPT live values directly over Bluetooth - local, private, and ready for widgets and Live Activities.`

Description:

```text
Stromer shows live values from your Victron devices directly on your iPhone.
Built for camper vans, boats, and off-grid power setups.

Receive Victron Instant Readout over Bluetooth and keep an eye on battery and
solar values without requiring a Cerbo GX or cloud connection.

Features:
- Live values for SmartShunt/BMV and SmartSolar/BlueSolar MPPT
- Device discovery for Victron Instant Readout
- Advertisement keys stored securely in the iOS Keychain
- Home Screen and Lock Screen widgets
- Live Activity and Dynamic Island support
- Freshness status with last-updated timestamp
- No cloud, no tracking, no analytics

Additional Victron device families such as Orion Smart, Phoenix Inverter,
SmartLithium, Phoenix Smart IP43 Charger, and Smart BatteryProtect are prepared
for future updates.

Note:
Stromer is not an official Victron Energy product. Instant Readout must be
enabled in VictronConnect. You can find the advertisement key in VictronConnect
under Product Info / Instant Readout Details.
```

Keywords, max. 100 characters:

- `victron,smartshunt,mppt,solar,battery,camper,boat,offgrid,bluetooth,widget`

What's New:

- `Initial TestFlight version with Victron BLE discovery, SmartShunt/MPPT live values, widgets, and Live Activity.`

## 8. Plist- und Info.plist-Änderungen

Aktueller Stand aus `Stromer/Info.plist`:

- `CFBundleDisplayName = Stromer`
- `NSBluetoothAlwaysUsageDescription` erklärt Victron-Discovery bereits passend.
- `NSSupportsLiveActivities = YES`
- `UIBackgroundModes = bluetooth-central`
- `CFBundleIconName` fehlt aktuell.
- `LSApplicationCategoryType` fehlt aktuell.

Empfohlene Änderungen für 3.6:

| Key | Zielwert | Phase | Begründung |
| --- | --- | --- | --- |
| `NSBluetoothAlwaysUsageDescription` | `Stromer scannt nach Victron-Geräten in der Nähe, um Solardaten und Batterie-Status anzuzeigen und neue Geräte beim Hinzufügen vorzuschlagen.` | prüfen in 3.6b | Bereits konsistent mit Onboarding; nur ändern, wenn Onboarding-Text final anders wird. |
| `CFBundleDisplayName` | `Stromer` | prüfen in 3.6a | Bereits korrekt. |
| `CFBundleIconName` | `AppIcon` | 3.6a | Explizite App-Icon-Zuordnung, falls Xcode-Projekt sie nicht rein über Asset Catalog setzt. |
| `LSApplicationCategoryType` | `public.app-category.utilities` oder `public.app-category.lifestyle` | 3.6e | Kategorie für App Store Connect und System-Metadaten. |

Kategorie-Abwägung:

- `public.app-category.utilities`: passt zu Monitoring, Tool-Charakter und
  wiederholter Nutzung.
- `public.app-category.lifestyle`: passt zu Camper/Boot/Off-Grid-Zielgruppe,
  ist aber weniger präzise für ein technisches Messwerte-Tool.
- Empfehlung: `public.app-category.utilities`, sofern App Store Connect keine
  bessere Produktpositionierung verlangt.

## 9. OPEN QUESTIONS

> **OPEN QUESTION**: Welches App-Icon-Konzept soll final umgesetzt werden?
> Aktueller Plan: Konzept A `Sonne + Batterie` als primäres Icon in 3.6a
> rendern. Zu klären bevor Implementation startet.

> **OPEN QUESTION**: Soll Onboarding bei jedem App-Update erneut erscheinen oder
> nur beim ersten Start? Aktueller Plan: Nur beim ersten Start; später optional
> über Settings erneut anzeigen. Für Breaking Changes kann später ein
> versionierter Onboarding-Key eingeführt werden. Zu klären bevor Implementation
> startet.

> **OPEN QUESTION**: Soll die Lanicode-UG-Adresse in der Privacy Policy schon
> drin sein oder als Platzhalter bleiben? Aktueller Plan: Platzhalter in 3.6e
> nur ersetzen, wenn die rechtlich korrekte Adresse final vorliegt. Zu klären
> bevor App-Store-Submission startet.

> **OPEN QUESTION**: Welche App-Store-Kategorie passt am besten? Aktueller Plan:
> `Utilities`, weil Stromer primär ein Monitoring-Werkzeug ist. `Lifestyle` als
> Alternative prüfen, wenn die Store-Positionierung stärker Camper/Boot betonen
> soll. Zu klären bevor 3.6e finalisiert wird.

> **OPEN QUESTION**: Soll das Onboarding animiert oder statisch sein? Aktueller
> Plan: Statische Seiten mit sanftem Slide/Fade und ohne komplexe Illustrationen,
> damit der Flow schnell und wartbar bleibt. Zu klären bevor 3.6b startet.

> **OPEN QUESTION**: Dürfen VictronConnect-Screenshots im Key-Hilfe-Screen
> verwendet werden? Aktueller Plan: In 3.6b zunächst textbasierte Schritte und
> eigene einfache Illustrationen verwenden; echte Screenshots nur nach Prüfung
> von Rechten und Review-Risiko. Zu klären vor bildbasierter Hilfe.

> **OPEN QUESTION**: Soll der Widget-Reload-Debouncer im App-Target oder im
> `StromerScanner`-Package liegen? Aktueller Plan: App-Target, weil `WidgetKit`
> eine App-/Extension-UI-Abhängigkeit ist und `StromerScanner` testbar und
> WidgetKit-frei bleiben soll. Zu klären vor 3.6d.

## 10. Out of Scope für Phase 3.6

- Multi-Family-Decoder für Orion Smart, Phoenix Inverter, SmartLithium,
  Phoenix Smart IP43 Charger oder Smart BatteryProtect. Das ist Phase 3.7.
- Lokale Historie, Charts und Langzeit-Speicherung. Das ist Phase 4.
- Key-Sharing per QR-Code.
- Import/Export von Geräteprofilen.
- TestFlight-Setup und App-Store-Submission. Das ist Phase 3.8.
- Backend, Cloud-Sync, Analytics oder Crash-Reporting.
- Lokalisierung in andere Sprachen außer Deutsch und Englisch.
- iPadOS-spezifische Layouts.
- watchOS-App.
- Neue BLE-Scanner-Features oder Background-Refresh-Versprechen.
