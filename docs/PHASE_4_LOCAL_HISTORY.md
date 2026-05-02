# Phase 4 - Lokale Historie mit Charts

Status: Architektur-Dokumentation. Keine Implementation.

## Quellen

- `docs/PHASE_3_6_ONBOARDING_POLISH.md`
- `docs/PHASE_3_7_B_DCDC_DECODER.md`
- `Packages/StromerScanner/Sources/StromerScanner/Models/DeviceReading.swift`
- `Packages/StromerScanner/Sources/StromerScanner/Persistence/AppGroupReadingStore.swift`
- `Packages/StromerScanner/Sources/StromerScanner/Scanner/ScannerService.swift`
- `Stromer/Views/DeviceDetail/DeviceDetailView.swift`
- Apple Swift Charts:
  https://developer.apple.com/documentation/charts
- Apple SwiftData:
  https://developer.apple.com/documentation/swiftdata
- Apple `ModelContainer`:
  https://developer.apple.com/documentation/swiftdata/modelcontainer

Hinweis zum aktuellen Repo-Stand: `DeviceReadingPayload.swift` existiert nicht
als separate Datei; `DeviceReadingPayload` ist aktuell in `DeviceReading.swift`
definiert. `DeviceReading` modelliert Battery Monitor, Solar Charger und DC/DC
Converter bereits als `payload`-Enum.

## 1. Uebersicht

Phase 4 ergänzt Stromer um eine lokale Historie aus passiv empfangenen
Victron-BLE-Advertisements. Die App bleibt read-only und passive-only: kein
Reverse-Engineering von VictronConnects History-Protokoll, keine
GATT-Verbindung, keine VRM-/Cloud-Integration und kein Schreiben auf Geräte.

Unterstützte Use-Cases:

- Verlauf der letzten 24 Stunden mit hoher Auflösung pro Gerät.
- 7- und 30-Tage-Ansichten mit verdichteten 5-Minuten-Aggregaten.
- Tages- und Jahresübersichten mit dauerhaft gespeicherten Tageswerten.
- Ehrliche Lückenanzeige, wenn das iPhone nicht in BLE-Reichweite war.
- Nutzung der bereits in Advertisements enthaltenen Tageswerte, z.B.
  `yieldToday` beim MPPT, um Tages-Snapshots auch bei kurzer iPhone-Anwesenheit
  sinnvoll zu aktualisieren.

Explizit nicht unterstützt:

- Rueckwirkendes Laden historischer VictronConnect-Daten.
- Remote-Zugriff auf den Camper oder das Boot.
- History-Sync zwischen iPhones.
- Cloud-Auswertung, Analytics oder Server-Speicherung.

UI-Kommunikation:

- Historie startet ab Installation bzw. ab Phase-4-App-Update.
- Wenn das iPhone nicht in Reichweite ist, entstehen Luecken.
- Aggregierte Tageswerte koennen trotzdem aktualisiert werden, sobald ein
  spaeteres Advertisement einen Tageszaehler wie `yieldToday` enthaelt.

## 2. Datenschicht-Architektur (drei Stufen)

Phase 4 fuehrt drei lokale Datenschichten ein. Jede Schicht ist fuer einen
anderen Zeitbereich optimiert und wird aus den passiv empfangenen Readings
aufgebaut.

| Schicht | Aufbewahrung | Granularitaet | Modell | Verwendung | Lifecycle |
| --- | --- | --- | --- | --- | --- |
| `LiveReading` | Rolling Window letzte 24h | max. 1 Datensatz pro Sekunde und Geraet | Roh-Snapshot eines `DeviceReading` mit extrahierten Chart-Feldern | "Heute"-Chart mit Sekunden-/Minuten-Aufloesung | nach 24h in `MinuteAggregate`, danach Loeschung |
| `MinuteAggregate` | Rolling Window letzte 30 Tage | 5-Minuten-Slots | Min/Max/Avg pro relevantem Feld | "7 Tage" und "30 Tage" mit 5-Min-Aufloesung | nach 30 Tagen in `DailyAggregate`, danach Loeschung |
| `DailyAggregate` | dauerhaft, Default 5+ Jahre bzw. forever | 1 Eintrag pro Tag und Geraet | Tagesstatistiken und Tageszaehler | Jahresuebersicht, Trends, Langzeitwerte | bleibt bis User-Loeschung oder spaeterer Retention-Policy |

### Schicht 1: LiveReading

Zweck:

- Abbild der zuletzt empfangenen Advertisements fuer hochaufgeloeste
  Tagescharts.
- Keine App-Group-Abhaengigkeit; Charts laufen im App-Target.
- Eintrag maximal einmal pro Sekunde pro Geraet, damit BLE-Advertisement-Spitzen
  die Datenbank nicht fluten.

Felder:

- `deviceID`
- `timestamp`
- `familyKind`: `"battery"`, `"solar"` oder `"dcdc"`
- technische Metadaten: `rssi`, `productID`, `recordType`
- Battery: `voltage`, `current`, `soc`, `consumed`, `temperature`, `timeToGo`
- Solar: `pvPower`, `batteryVoltage`, `batteryCurrent`, `yieldToday`,
  `loadCurrent`, `chargerStateRaw`
- DC/DC: `inputVoltage`, `outputVoltage`, `dcDcChargeStateRaw`,
  `offReasonRaw`

### Schicht 2: MinuteAggregate

Zweck:

- Verdichtete Daten fuer 7- bis 30-Tage-Charts.
- 5-Minuten-Slots reduzieren Datenmenge und Chart-Rendering-Kosten deutlich.
- Pro Slot werden nur Felder geschrieben, die fuer die Geraetefamilie relevant
  sind.

Battery-Felder:

- `voltageMin`, `voltageMax`, `voltageAvg`
- `currentMin`, `currentMax`, `currentAvg`
- `socMin`, `socMax`, `socAvg`
- `consumedMin`, `consumedMax`

Solar-Felder:

- `pvPowerMin`, `pvPowerMax`, `pvPowerAvg`
- `batteryVoltageMin`, `batteryVoltageMax`, `batteryVoltageAvg`
- `batteryCurrentMin`, `batteryCurrentMax`, `batteryCurrentAvg`
- `yieldTodayMax`

DC/DC-Felder:

- `inputVoltageMin`, `inputVoltageMax`, `inputVoltageAvg`
- `outputVoltageMin`, `outputVoltageMax`, `outputVoltageAvg`
- `activeMinutes` oder `chargingMinutes` pro Slot

### Schicht 3: DailyAggregate

Zweck:

- Dauerhafte Tagesuebersicht.
- Kleine Datenmenge, geeignet fuer Jahresansichten und spaetere Export-Features.
- Pro Tag und Geraet genau ein Eintrag.

Solar-Tageswerte:

- `yieldTodayMax`
- `peakPvPower`
- `sunHours` oder `activeSolarMinutes`

Battery-Tageswerte:

- `socMin`, `socMax`, `socAvg`
- `voltageMin`, `voltageMax`
- `deepDischargesCount`
- `fullChargesCount`

DC/DC-Tageswerte:

- `inputVoltageMin`, `inputVoltageMax`, `inputVoltageAvg`
- `outputVoltageMin`, `outputVoltageMax`, `outputVoltageAvg`
- `totalChargingMinutes`
- `offReasonLastRaw` optional fuer Diagnose

## 3. Schreib-Strategie

Der zukuenftige Schreib-Trigger sitzt im bestehenden
`ScannerService.onReadingUpdated`-Hook. Dieser Hook wird aktuell nach
erfolgreichem Parser-Match und erfolgreichem `VictronStore.update(...)`
aufgerufen. Phase 4 sollte dort einen neuen History-Service anbinden, ohne den
Latest-Reading-Store fuer Widget und Live Activity zu ersetzen.

Schreibpfad:

```text
BLE Advertisement
  -> ScannerService.handleAdvertisement(...)
  -> DeviceRegistry.match(...)
  -> VictronStore.update(...)
  -> onReadingUpdated(reading)
  -> HistoryWriter.record(reading)
```

Regeln pro Reading:

- Debouncer prueft pro `deviceID`, ob seit dem letzten `LiveReading` mindestens
  1 Sekunde vergangen ist.
- Wenn ja, wird ein `LiveReading` mit extrahierten Chart-Feldern geschrieben.
- Wenn nein, wird kein `LiveReading` geschrieben; Daily-Aggregate-Deltas duerfen
  trotzdem aktualisiert werden, falls der Reading-Wert einen hoeheren
  Tageszaehler enthaelt.
- Wenn `yieldToday`, `consumedAh`, `soc`, `pvPower` oder Spannungen vorhanden
  sind, wird der aktuelle `DailyAggregate` per Upsert aktualisiert.

Daily-Upsert waehrend des Tages:

- Solar: `yieldTodayMax = max(existing, reading.yieldTodayWh)`.
- Solar: `peakPvPower = max(existing, reading.pvPower)`.
- Battery: Min/Max fuer SoC und Spannung laufend aktualisieren.
- Battery: `deepDischargesCount` und `fullChargesCount` nur ueber
  Schwellenuebergaenge zaehlen, nicht bei jedem Reading neu.
- DC/DC: Min/Max fuer Ein-/Ausgangsspannung laufend aktualisieren.
- DC/DC: `totalChargingMinutes` nur aus Zeitabstaenden ableiten, wenn der
  vorherige Reading-Abstand klein genug ist, z.B. unterhalb der Luecken-
  Schwelle.

Bei Tag-Wechsel oder erstem Reading des Tages:

- Vorherigen Tag finalisieren, falls noch offene Live-/Minute-Daten vorhanden
  sind.
- Neuen Tagesdatensatz per Upsert starten.
- Tageszaehler wie `yieldToday` koennen nach Victron-Geraetelokalzeit
  zurueckgesetzt sein; die App muss diesen Reset erkennen und nicht als
  negativen Ertrag interpretieren.

## 4. Aggregation-Strategie

### LiveReading -> MinuteAggregate

Trigger:

- Beim App-Start bzw. `scenePhase == .active`.
- Nach einer kleinen Verzoegerung, damit die UI zuerst reagieren kann.
- Optional alle paar Stunden, solange die App im Vordergrund aktiv ist.

Algorithmus:

1. Lade alle `LiveReading`-Eintraege aelter als 24 Stunden.
2. Gruppiere nach `deviceID`, `familyKind` und 5-Minuten-`slotStart`.
3. Berechne Min/Max/Avg pro relevantem Feld.
4. Schreibe oder aktualisiere `MinuteAggregate` per Upsert.
5. Loesche aggregierte `LiveReading`-Eintraege, sobald der Upsert erfolgreich
   gespeichert ist.

### MinuteAggregate -> DailyAggregate

Trigger:

- Beim App-Start bzw. `scenePhase == .active`.
- Beim ersten Reading eines neuen Tages.
- Optional beim Wechsel in den Hintergrund als kurzer Best-Effort-Lauf.

Algorithmus:

1. Lade alle `MinuteAggregate`-Eintraege aelter als 30 Tage.
2. Gruppiere nach `deviceID`, `familyKind` und lokalem Kalendertag.
3. Berechne Tagesstatistiken.
4. Update existierende `DailyAggregate`-Eintraege oder erstelle neue.
5. Loesche aggregierte `MinuteAggregate`-Eintraege erst nach erfolgreichem
   Speichern.

Hintergrund-Aggregation:

- Keine `BGAppRefreshTask`-Abhaengigkeit in Phase 4.
- Keine impliziten Versprechen ueber Aktualitaet, wenn die App nicht aktiv ist.
- Aggregation laeuft opportunistisch in App-Lifecycle-Hooks, passend zum
  passive-only-Manifesto.

## 5. Storage-Schaetzung

Worst-Case pro Geraet bei kontinuierlichem Empfang:

| Schicht | Rechnung | Groesse |
| --- | --- | ---: |
| `LiveReading` | 86.400 Datensaetze x ca. 50 Byte | ca. 4 MB pro Tag |
| `MinuteAggregate` | 8.640 Slots x ca. 100 Byte | ca. 860 KB pro 30 Tage |
| `DailyAggregate` | 365 Eintraege x ca. 200 Byte | ca. 70 KB pro Jahr |

Realistische Einschaetzung:

- BLE-Advertisements kommen nicht perfekt sekundenstabil an.
- Das iPhone ist nicht immer in Reichweite.
- SwiftData/Core-Data-Overhead, Indizes und SQLite-Seiten erhoehen die
  rechnerischen Rohwerte.
- Fuer 3 Geraete ueber 1 Jahr sind realistisch ca. 10-50 MB zu erwarten.
- Selbst mit 5 Jahren Daily-Daten bleibt die Langzeitschicht klein.

Retention-Vorschlag:

- `LiveReading`: strikt 24h.
- `MinuteAggregate`: strikt 30 Tage.
- `DailyAggregate`: Default forever; spaeter optional "Historie loeschen" in
  Settings.

## 6. SwiftData oder Core Data?

### SwiftData (iOS 17+)

Pro:

- Passt zum Minimum-Target iOS 17.
- Swift-native `@Model`-Syntax und weniger Boilerplate.
- `ModelContainer` verwaltet Schema, persistenten Store und automatische
  Migrationen.
- `ModelConfiguration` kann bei Bedarf einen App-Group-Store konfigurieren.
- Gute SwiftUI-Integration, z.B. ueber `.modelContainer(...)` und `@Query`.

Contra:

- Juenger als Core Data, mit mehr iOS-17-Risiken.
- Migration-Story ist vorhanden, aber weniger lange bewaehrt.
- Performance bei groesseren historischen Daten sollte frueh mit echten Daten
  validiert werden.

### Core Data

Pro:

- Etabliert und robust.
- Sehr gute Kontrolle ueber Indizes, Batch-Operationen und Migrationen.
- Bewaehrt fuer groessere Zeitreihen in SQLite.

Contra:

- Mehr Boilerplate.
- Aelteres API, weniger passend zur bestehenden SwiftUI-/iOS-17-Richtung.
- Mehr manuelle Modell- und Context-Verwaltung.

Empfehlung:

- SwiftData fuer Phase 4, weil Stromer iOS 17+ ist, die Datenmengen klein
  bleiben und das Schema konservativ gehalten werden kann.
- Kritische Punkte frueh testen: Insert-Frequenz, 24h-Queries, Aggregation von
  mehreren zehntausend `LiveReading`-Eintraegen.
- Falls SwiftData bei echten Hardware-Daten sichtbar hakelt, bleibt Core Data
  als Rueckfalloption fuer 4a.

> **OPEN QUESTION**: SwiftData oder Core Data final? Aktueller Plan:
> SwiftData mit konservativem flachem Schema, Indizes auf `deviceID` und
> Zeitfeldern, und fruehem Performance-Test in 4a. Zu klaeren bevor
> Implementation startet.

## 7. Datenmodell-Sketches

Diese Sketches sind Dokumentation, keine Implementation. Die Namen und Felder
sollen die beabsichtigte Persistenz-Struktur greifbar machen.

### LiveReading

```swift
@Model
final class LiveReading {
    var deviceID: UUID
    var timestamp: Date
    var familyKind: String // "battery" | "solar" | "dcdc"
    var productID: Int?
    var recordType: Int
    var rssi: Int?

    // Battery fields
    var voltage: Double?
    var current: Double?
    var soc: Double?
    var consumed: Double?
    var temperature: Double?
    var timeToGo: Int?

    // Solar fields
    var pvPower: Double?
    var batteryVoltage: Double?
    var batteryCurrent: Double?
    var yieldToday: Double?
    var loadCurrent: Double?
    var chargerStateRaw: Int?

    // DC/DC fields
    var inputVoltage: Double?
    var outputVoltage: Double?
    var dcDcChargeStateRaw: Int?
    var offReasonRaw: UInt32?

    init(...) { ... }
}
```

### MinuteAggregate

```swift
@Model
final class MinuteAggregate {
    var deviceID: UUID
    var slotStart: Date
    var familyKind: String

    // Battery
    var voltageMin: Double?
    var voltageMax: Double?
    var voltageAvg: Double?
    var currentMin: Double?
    var currentMax: Double?
    var currentAvg: Double?
    var socMin: Double?
    var socMax: Double?
    var socAvg: Double?
    var consumedMin: Double?
    var consumedMax: Double?

    // Solar
    var pvPowerMin: Double?
    var pvPowerMax: Double?
    var pvPowerAvg: Double?
    var batteryVoltageMin: Double?
    var batteryVoltageMax: Double?
    var batteryVoltageAvg: Double?
    var batteryCurrentMin: Double?
    var batteryCurrentMax: Double?
    var batteryCurrentAvg: Double?
    var yieldTodayMax: Double?

    // DC/DC
    var inputVoltageMin: Double?
    var inputVoltageMax: Double?
    var inputVoltageAvg: Double?
    var outputVoltageMin: Double?
    var outputVoltageMax: Double?
    var outputVoltageAvg: Double?
    var activeMinutes: Double?

    init(...) { ... }
}
```

### DailyAggregate

```swift
@Model
final class DailyAggregate {
    var deviceID: UUID
    var dayStart: Date
    var familyKind: String

    // Shared
    var firstSeenAt: Date?
    var lastSeenAt: Date?
    var sampleCount: Int
    var gapCount: Int

    // Solar
    var yieldTodayMax: Double?
    var peakPvPower: Double?
    var sunHours: Double?

    // Battery
    var socMin: Double?
    var socMax: Double?
    var socAvg: Double?
    var voltageMin: Double?
    var voltageMax: Double?
    var deepDischargesCount: Int?
    var fullChargesCount: Int?

    // DC/DC
    var inputVoltageMin: Double?
    var inputVoltageMax: Double?
    var inputVoltageAvg: Double?
    var outputVoltageMin: Double?
    var outputVoltageMax: Double?
    var outputVoltageAvg: Double?
    var totalChargingMinutes: Double?
    var offReasonLastRaw: UInt32?

    init(...) { ... }
}
```

Modellierungsentscheidung, Vorschlag:

- Persistierte History-Modelle sollten flach bleiben, obwohl die Runtime
  `DeviceReadingPayload` als Enum nutzt.
- Grund: Charts und Aggregationen brauchen direkte numeric columns,
  Zeitbereichsqueries und Indizes. Ein Codable-Payload-Blob waere fuer Charts
  und SQLite-Prädikate unpraktisch.
- Die fachliche Trennung bleibt ueber `familyKind` und klare Feldgruppen
  erhalten.

> **OPEN QUESTION**: Datenmodell flach oder polymorphisch? Aktueller Plan:
> flache optionale Spalten fuer SwiftData-Modelle, weil Aggregation und Charts
> direkte Queries brauchen; Runtime-Modelle behalten weiterhin das
> `DeviceReadingPayload`-Enum. Zu klaeren bevor Implementation startet.

## 8. UI-Layer: Chart-Views

Charts werden in `DeviceDetailView` integriert, wahrscheinlich unterhalb des
aktuellen Hero-Readouts und der Stat-Grid-Sektion. Der bestehende Live-Bereich
bleibt erhalten; Charts sind ein additiver Verlaufsteil.

Swift-Charts-Leitplanken:

- `Chart` als SwiftUI-Container.
- `LineMark` fuer Spannungs-/SoC-Verlaeufe.
- `BarMark` fuer Solarertrag und PV-Leistung.
- `RuleMark` oder `RectangleMark` fuer Luecken-/Zeitbereichsmarker.
- Achsen, Skalen und Legenden bewusst reduzieren, damit es im Bolt-Design ruhig
  bleibt.
- Farben: `boltTeal` fuer Hauptlinien, `boltYellow` fuer Energie/Produktion,
  `boltWarn`/`boltBad` fuer Luecken oder kritische Werte.

Tab-Struktur im Detail:

```text
DeviceDetailView
  Live
  Heute
  7 Tage
  30 Tage
  Jahr
```

Alternative:

- Wenn der Live-Screen nicht ueberladen werden soll, bleibt `DeviceDetailView`
  oben unveraendert und bekommt darunter einen segmentierten Chart-Bereich mit
  `Heute`, `7 Tage`, `30 Tage`, `Jahr`.

### Tab "Heute"

Quelle:

- Primaer `LiveReading` der letzten 24h.
- Bei zu vielen Punkten kann die View clientseitig fuer die Anzeige auf
  Minuten-Samples reduzieren.

Battery:

- SoC-Linie.
- Voltage-Linie optional zweite Achse oder separater Mini-Chart.
- Current als zusaetzliche Flaeche nur wenn lesbar.

Solar:

- PV-Power als Bar- oder Area-Chart.
- `yieldToday` als kleine Summenanzeige oberhalb des Charts.

DC/DC:

- `outputVoltage`-Linie.
- Fallback `inputVoltage`, wenn output nil.
- Charge-State-Wechsel optional als Marker.

### Tab "7 Tage"

Quelle:

- `MinuteAggregate`, ggf. fuer Tageswerte ergaenzt durch aktuelle
  `DailyAggregate`-Upserts.

Battery:

- SoC-Min/Max-Range plus Avg-Linie pro Tag oder pro 5-Min-Slot.

Solar:

- Tages-Yield-Saeulen aus `yieldTodayMax`.
- Optional Peak-PV-Marker.

DC/DC:

- OutputVoltage-Min/Max-Range plus Avg-Linie.

### Tab "30 Tage"

Quelle:

- `MinuteAggregate` fuer die letzten 30 Tage.
- Bei Performance-Problemen ab 14 Tagen bereits `DailyAggregate` verwenden.

Darstellung:

- Wie 7 Tage, aber staerker aggregiert.
- Achsenbeschriftung tageweise statt stundenweise.

### Tab "Jahr"

Quelle:

- Nur `DailyAggregate`.

Solar:

- kWh-Wochen-Saeulen oder Monats-Saeulen.
- Heatmap als spaetere Option, nicht Pflicht in 4c.

Battery:

- SoC-Min/Max-Trends.
- Durchschnittlicher SoC pro Woche oder Monat.

DC/DC:

- OutputVoltage-Min/Max.
- `totalChargingMinutes` als einfache Balken.

## 9. Luecken-Visualisierung

Luecken entstehen, wenn das iPhone keine Advertisements empfangen hat. Das ist
kein Fehler, sondern Teil des passive-only-Modells.

Darstellung:

- In Liniencharts: Linie zwischen Segmenten unterbrechen, wenn der Abstand der
  Punkte groesser als die Luecken-Schwelle ist.
- Optional: transparente Zone oder gestrichelte Verbindung zwischen Segmenten.
- Footer-Hinweis unter dem Chart:
  `"Luecke vom 15. Maerz bis 18. Maerz - iPhone war nicht in Reichweite."`
- Bei mehreren kurzen Luecken: komprimierte Anzeige, z.B. `"3 Luecken heute"`.

Vorgeschlagene Default-Schwellen:

- Heute/Live-Ansicht: Luecke ab `> 5 Minuten` ohne Reading.
- 7-/30-Tage-Ansicht: Luecke ab `> 30 Minuten` ohne Reading.
- Daily-Ansicht: Tag als unvollstaendig markieren, wenn weniger als 30 Minuten
  Gesamtanwesenheit oder kein Tageszaehler-Update vorhanden ist.

Begruendung:

- 5 Minuten ist fuer Live-Verlaeufe sichtbar genug, ohne kurze BLE-Aussetzer als
  harte Luecke zu dramatisieren.
- 30 Minuten passt besser zu aggregierten Ansichten.
- Tageswerte wie MPPT `yieldToday` koennen trotzdem plausibel sein, auch wenn
  die Live-Kurve Luecken hat.

> **OPEN QUESTION**: Wie definieren wir "Luecke" final? Aktueller Plan:
> `> 5 Minuten` in Live-/Heute-Charts und `> 30 Minuten` in aggregierten
> Charts; Daily-Aggregates bekommen zusaetzlich `gapCount` und
> `observedMinutes`. Zu klaeren bevor Implementation startet.

## 10. Migration fuer bestehende User

Phase 4 ist additiv:

- `AppGroupReadingStore` bleibt unveraendert fuer Widget und Live Activity.
- Registrierte Geraete bleiben unveraendert.
- Bestehende Latest-Readings werden nicht in eine rueckwirkende Historie
  umgedeutet.
- Die History-Datenbank wird beim App-Start initialisiert.
- Ab dem ersten empfangenen Reading nach dem Update beginnt die Historie.

UI-Kommunikation:

```text
Historie ab heute
Stromer sammelt Verlaeufe ab dem Zeitpunkt dieses Updates. Aeltere
VictronConnect-Historie wird nicht importiert.
```

Wenn bereits ein Latest-Reading existiert:

- Es darf als Startpunkt angezeigt werden, aber nicht als vollwertige
  historische Zeitreihe.
- Charts starten leer oder mit einem einzelnen Punkt und erklaerendem Empty
  State.

## 11. App Group Sharing

Aktueller Stand:

- Widget und Live Activity lesen weiterhin nur Latest-Reading-Snapshots aus dem
  App-Group-Store.
- Charts laufen im App-Target.
- Phase-4-Historie muss deshalb nicht app-group-shared sein.

Empfehlung fuer Phase 4:

- SwiftData-Store im App-eigenen Container.
- Keine Widget-Queries gegen die History-Datenbank.
- App Group weiterhin nur fuer kompakte Widget-Snapshots verwenden.

Vorbereitung fuer spaeter:

- `HistoryStore` als Protokoll oder klar gekapselter Service.
- Store-URL zentral konfigurieren, damit eine spaetere Migration in den
  App-Group-Container moeglich bleibt.
- Keine direkte SwiftData-Nutzung tief in Views verteilen.

> **OPEN QUESTION**: App Group jetzt schon vorbereiten oder erst bei 4.5?
> Aktueller Plan: Store im App-Container, aber `HistoryStore` so kapseln, dass
> eine spaetere App-Group-Migration fuer Chart-Widgets moeglich bleibt. Zu
> klaeren bevor Implementation startet.

## 12. Performance-Erwaegungen

Schreibpfad:

- Maximal ein `LiveReading` pro Sekunde und Geraet.
- Upserts fuer `DailyAggregate` duerfen nicht die UI blockieren.
- History-Schreiben sollte in einem dedizierten Service laufen, nicht direkt in
  SwiftUI-Views.

SwiftData/Storage:

- Indizes bzw. Fetch-Praedikate muessen auf `deviceID` + `timestamp`,
  `deviceID` + `slotStart` und `deviceID` + `dayStart` optimiert werden.
- Aggregation muss batch-orientiert sein.
- Grosse Fetches fuer Charts sollten begrenzt und sortiert sein.
- Bei App-Start keine vollstaendige Jahres-Historie laden.

Chart-Rendering:

- "Heute" darf nicht 86.400 Punkte auf einmal rendern.
- Fuer Liniencharts nur sichtbare bzw. voraggregierte Punkte an Swift Charts
  geben.
- 7-/30-Tage-Ansichten nutzen Aggregates.
- Jahresansicht nutzt ausschliesslich Daily-Aggregates.

Speichergrenzen:

- Bei > 500 MB History-Store sollte die App warnen oder Cleanup anbieten.
- Live- und Minute-Schichten haben harte Retention und sollten automatisch klein
  bleiben.
- Daily-Schicht kann in Settings spaeter loeschbar gemacht werden.

> **OPEN QUESTION**: Was passiert wenn die DB > 500 MB erreicht? Aktueller
> Plan: automatische harte Retention fuer Live/Minute, Warnung plus
> "Historie loeschen" fuer Daily-Daten; kein stilles Loeschen dauerhafter
> Tageshistorie ohne User-Aktion. Zu klaeren bevor Implementation startet.

## 13. Aufwand-Schaetzung pro Sub-Phase

Empfohlene Aufteilung:

| Phase | Titel | Inhalt | Ergebnis |
| --- | --- | --- | --- |
| 4a | Persistenz-Schicht | SwiftData-Models, `HistoryStore`, Schreib-Hook, 1s-Debouncer | Daten sammeln beginnt |
| 4b | Aggregation | Live -> Minute, Minute -> Daily, Retention, Tageswechsel | Langzeitdaten werden verdichtet |
| 4c | Chart-Views | Detail-Charts fuer Battery, Solar, DC/DC mit Swift Charts | User sieht Historie |
| 4d | Luecken & Polish | Lueckenanzeige, Empty States, Performance-Feinschliff | ehrliche, stabile UI |

Empfohlene Reihenfolge:

1. 4a und 4b zuerst umsetzen und mergen.
2. 1-2 Wochen echte Hardware-Daten sammeln.
3. Danach 4c und 4d anhand realer Datenkurven bauen.

Alternative:

- Alles in einem grossen Task umsetzen.
- Vorteil: schneller sichtbares Ergebnis.
- Nachteil: Charts werden mit synthetischen Daten gebaut und muessen spaeter
  wahrscheinlich nachjustiert werden.

> **OPEN QUESTION**: Soll Phase 4 in Sub-Phasen 4a-d aufgeteilt werden oder in
> einem grossen Task umgesetzt werden? Aktueller Plan: 4a+4b zuerst, echte
> Daten sammeln, danach 4c+4d. Zu klaeren bevor Implementation startet.

## 14. OPEN QUESTIONS

> **OPEN QUESTION**: SwiftData oder Core Data final? Aktueller Plan:
> SwiftData mit konservativem flachem Schema, Indizes auf `deviceID` und
> Zeitfeldern, und fruehem Performance-Test in 4a. Zu klaeren bevor
> Implementation startet.

> **OPEN QUESTION**: Datenmodell flach oder polymorphisch? Aktueller Plan:
> flache optionale Spalten fuer SwiftData-Modelle, weil Aggregation und Charts
> direkte Queries brauchen; Runtime-Modelle behalten weiterhin das
> `DeviceReadingPayload`-Enum. Zu klaeren bevor Implementation startet.

> **OPEN QUESTION**: Wie definieren wir "Luecke" final? Aktueller Plan:
> `> 5 Minuten` in Live-/Heute-Charts und `> 30 Minuten` in aggregierten
> Charts; Daily-Aggregates bekommen zusaetzlich `gapCount` und
> `observedMinutes`. Zu klaeren bevor Implementation startet.

> **OPEN QUESTION**: App Group jetzt schon vorbereiten oder erst bei 4.5?
> Aktueller Plan: Store im App-Container, aber `HistoryStore` so kapseln, dass
> eine spaetere App-Group-Migration fuer Chart-Widgets moeglich bleibt. Zu
> klaeren bevor Implementation startet.

> **OPEN QUESTION**: Aggregation-Trigger: scenePhase, Timer oder erstes Reading?
> Aktueller Plan: Kombination aus `scenePhase == .active`, erstem Reading des
> Tages und kurzem Best-Effort-Lauf beim Background-Wechsel; kein
> Background-Refresh-Task. Zu klaeren bevor Implementation startet.

> **OPEN QUESTION**: Was passiert wenn die DB > 500 MB erreicht? Aktueller
> Plan: automatische harte Retention fuer Live/Minute, Warnung plus
> "Historie loeschen" fuer Daily-Daten; kein stilles Loeschen dauerhafter
> Tageshistorie ohne User-Aktion. Zu klaeren bevor Implementation startet.

> **OPEN QUESTION**: Soll Phase 4 in Sub-Phasen 4a-d aufgeteilt werden oder in
> einem grossen Task umgesetzt werden? Aktueller Plan: 4a+4b zuerst, echte
> Daten sammeln, danach 4c+4d. Zu klaeren bevor Implementation startet.

## 15. Out of Scope fuer Phase 4

- Chart-Widget, moegliche Phase 4.5.
- CSV-/JSON-Export, moegliche Phase 4.6.
- Cross-Device-Vergleiche.
- iCloud-Sync der Historie zwischen iPhones.
- Trend-Insights wie "Diese Woche +12%".
- Forecast- oder Vorhersage-Features.
- VRM-Integration.
- Reverse-Engineering von Victron-History-GATT.
- Schreiben auf Victron-Geraete.
- Cloud-Backend, Analytics oder Tracking.
- Import alter VictronConnect-Historie.
