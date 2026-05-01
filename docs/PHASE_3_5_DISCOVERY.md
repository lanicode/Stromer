# Phase 3.5 - Geräte-Discovery in Stromer

Status: Architektur-Dokumentation. Keine Implementation.

## Quellen

- `docs/VICTRON_PROTOCOL.md`
- `docs/IOS_BLE_SCANNER.md`
- `Packages/StromerScanner/Sources/StromerScanner/Scanner/CoreBluetoothScanner.swift`
- `Packages/StromerScanner/Sources/StromerScanner/Scanner/BLEScanning.swift`
- `Packages/StromerScanner/Sources/StromerScanner/Scanner/ScannerService.swift`
- `Packages/StromerScanner/Sources/StromerScanner/Registry/DeviceRegistry.swift`
- `Stromer/Views/DeviceRegistration/AddDeviceView.swift`
- `Stromer/Views/Root/StromerAppViewModel.swift`
- Python-Referenz `keshavdv/victron-ble`:
  - `victron_ble/devices/__init__.py`
  - `Victron_ProductId_mapping.txt`

## 1. User Story

Der Nutzer soll beim Hinzufügen eines Geräts eine Live-Liste der Victron-Geräte
in der Nähe sehen, ohne vorher Namen oder Gerätetyp erraten zu müssen. Ein Tap
auf ein gefundenes Gerät öffnet den Registrierungsfluss mit vorausgefülltem
Namen, erkanntem Typ und iOS-Peripheral-ID; der Nutzer trägt nur noch den
32-stelligen Advertisement Key aus VictronConnect ein.

Nach erfolgreicher Key-Prüfung erscheint das Gerät sofort in der Hauptliste und
wird künftig wie manuell registrierte Geräte über die normale Scanner- und
Parser-Pipeline aktualisiert.

## 2. UI-Konzept

`AddDeviceView` wird nicht durch einen eigenen Top-Level-Screen ersetzt, sondern
um eine Auswahl zwischen Discovery und manueller Eingabe erweitert.

Empfohlene Struktur:

- Navigation Title: `Gerät hinzufügen`
- Segmented Control:
  - `In der Nähe`
  - `Manuell`
- Default-Tab: `In der Nähe`, wenn Bluetooth erlaubt ist.
- Fallback-Tab: `Manuell`, wenn Bluetooth aus, nicht erlaubt oder auf dem Gerät
  nicht verfügbar ist.

ASCII-Skizze:

```text
Gerät hinzufügen

[ In der Nähe | Manuell ]

Suche läuft...                         (spinner / progress)

SmartShunt 500A/50mV              -61 dBm
SmartShunt                         Zuletzt: gerade eben
Neu                                [Hinzufügen]

SmartSolar MPPT 100/50             -74 dBm
MPPT                               Zuletzt: vor 8 s
Bereits registriert                [Öffnen]

Phoenix Inverter                   -83 dBm
Inverter                           Noch nicht unterstützt
```

Discovery-Liste:

- Primäre Zeile: geschätzter Modellname aus Product ID, sonst Local Name, sonst
  `Victron-Gerät`.
- Sekundäre Zeile: erkannter Typ, Local Name, letzte Sichtung.
- Rechts: RSSI als dBm und ein Status-Badge.
- Unterstützte neue Geräte zeigen `Hinzufügen`.
- Bereits registrierte Geräte zeigen `Bereits registriert` und öffnen die
  Detailansicht oder markieren nur den Eintrag, je nach Navigation-Kontext.
- Geräte mit nicht unterstütztem Record Type bleiben sichtbar, aber der
  Hinzufügen-Button ist deaktiviert und die Zeile erklärt `Noch nicht
  unterstützt`.

Tap auf ein neues unterstütztes Gerät:

1. Öffnet einen Detail-/Key-Schritt innerhalb von `AddDeviceView`.
2. Name wird aus Product-ID-Mapping oder Local Name vorausgefüllt.
3. Typ wird aus Record Type vorausgewählt.
4. Die iOS-Peripheral-ID wird intern übernommen.
5. Der Nutzer trägt den Advertisement Key ein.
6. Beim Speichern wird der Key gegen das zuletzt gesehene Advertisement geprüft,
   wenn dieses noch im Discovery-Cache liegt.

Empty State:

- Während Suche ohne Treffer: `Victron-Geräte werden gesucht...`
- Nach kurzer Wartezeit ohne Treffer: `Keine Victron-Geräte gefunden`
- Sekundärtext: `Stelle sicher, dass Instant Readout in VictronConnect aktiv ist
  und das Gerät in Reichweite ist.`
- Aktion: `Manuell hinzufügen`

Suche läuft:

- Kleine `ProgressView` in der Section-Header-Zeile.
- Keine Vollbild-Ladeansicht, damit erkannte Geräte nicht verschwinden, während
  weitergescannt wird.
- Treffer bleiben sichtbar, solange sie innerhalb eines kurzen TTL-Fensters
  gesehen wurden.

## 3. Datenmodell

`DiscoveredDevice` ist ein flüchtiges UI-/Scanner-Modell. Es wird nicht
persistiert, solange der Nutzer das Gerät nicht registriert.

Skizze:

```swift
public struct DiscoveredDevice: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let peripheralID: UUID
    public let localName: String?
    public let productID: UInt16?
    public let estimatedModelName: String?
    public let recordType: UInt8?
    public let estimatedDeviceType: DiscoveredDeviceType
    public let rssi: Int
    public let lastSeenAt: Date
    public let isRegistered: Bool
}
```

Semantik:

- `id` ist `peripheralID`, also `CBPeripheral.identifier`.
- Es wird keine BLE-MAC-Adresse verwendet, weil iOS sie nicht herausgibt.
- `productID` kommt aus Victron Manufacturer Data Offset 2..3 nach Victron
  Payload-Start.
- `recordType` kommt aus Victron Manufacturer Data Offset 4 nach Victron
  Payload-Start.
- `estimatedModelName` kommt aus `Victron_ProductId_mapping.txt`, wenn bekannt.
- `estimatedDeviceType` kommt aus Record Type plus Product-ID-Overrides aus der
  Python-Referenz.
- `isRegistered` ist nur sicher, wenn die `peripheralID` mit einem registrierten
  Gerät übereinstimmt oder die bestehende Key-basierte Parser-Pipeline das
  Advertisement einem registrierten Gerät zuordnen konnte.

Typvorschlag:

```swift
public enum DiscoveredDeviceType: String, Sendable {
    case solarCharger
    case batteryMonitor
    case inverter
    case dcDcConverter
    case smartLithium
    case lynxSmartBMS
    case multiRS
    case veBus
    case smartBatteryProtect
    case dcEnergyMeter
    case orionXS
    case unknown
}
```

## 4. Scanner-Erweiterung

Der bestehende `CoreBluetoothScanner` gibt bereits alle Victron Instant Readout
Advertisements als `AsyncStream<RawAdvertisement>` weiter, sofern Manufacturer
Data mit Company ID `0x02E1` und Victron Payload Byte 0 `0x10` vorhanden ist.
Unentschlüsselbare Advertisements werden also auf BLE-Ebene bereits nicht
verworfen. Sie werden aktuell erst in `ScannerService.handleAdvertisement`
ignoriert, wenn `DeviceRegistry.match` keinen registrierten Key findet.

Empfohlene Erweiterung:

- Kein zweiter `CBCentralManager`.
- Kein zweiter Scan-Modus.
- Eine gemeinsame Scan-Pipeline bleibt Quelle der Wahrheit.
- `ScannerService` oder ein kleiner `DiscoveryService` baut aus jedem
  `RawAdvertisement` zusätzlich einen `DiscoveredDevice`-Snapshot.
- Live-Daten bleiben unverändert: Nur die bestehende Key-/Parser-Pipeline
  aktualisiert `VictronStore`.
- Discovery-Daten sind flüchtig: In-Memory-Map nach `peripheralID`, sortiert nach
  `lastSeenAt` oder RSSI.

Möglicher Datenfluss:

```text
BLEScanning.advertisements
    |
    +--> ScannerService.handleAdvertisement(...)
    |       -> DeviceRegistry.match(...)
    |       -> VictronParser.parse(...)
    |       -> VictronStore
    |
    +--> DiscoveryStore.update(rawAdvertisement)
            -> parse header only
            -> product name / record type / RSSI / last seen
            -> AddDeviceView "In der Nähe"
```

Warum kein zweiter Scan:

- iOS scannt ohnehin zentral über `CBCentralManager`.
- Ein zweiter Scan würde Akkulast und Zustandskoordination erhöhen.
- Foreground-Duplicates sind bereits aktiviert, sodass RSSI und `lastSeenAt`
  regelmäßig aktualisiert werden können.

Konfliktvermeidung:

- Discovery entschlüsselt keine Payloads ohne Key.
- Discovery schreibt nicht in `VictronStore`.
- Discovery persistiert keine unbekannten Geräte.
- Registrierung schreibt erst nach Nutzeraktion in Keychain und DeviceRegistry.
- Bereits registrierte Geräte werden anhand der Registry markiert, aber nicht
  erneut hinzugefügt.

## 5. Modell-Erkennung aus Header

Victron Manufacturer Data enthält nach dem 2-Byte Company Identifier die
Victron-Payload:

```text
Offset 0: 0x10 Product Advertisement
Offset 1: beobachteter Prefix 0x02
Offset 2..3: Product ID, UInt16 little-endian
Offset 4: Record Type / Device Type
Offset 5..6: Nonce
Offset 7: Encryption Key First Byte
Offset 8..: verschlüsselte Payload
```

Die Python-Referenz liest `model_id = struct.unpack("<H", data[2:4])[0]` und
`mode = struct.unpack("<B", data[4:5])[0]`. Danach wird der Parser über den
Record Type gewählt. Product IDs `0xA3A4` und `0xA3A5` werden explizit auf
`BatterySense` überschrieben.

Record-Type-Mapping aus Python und lokaler Doku:

| Record Type | Typ |
| ---: | --- |
| `0x01` | Solar Charger |
| `0x02` | Battery Monitor |
| `0x03` | Inverter |
| `0x04` | DC/DC Converter |
| `0x05` | Smart Lithium |
| `0x08` | AC Charger |
| `0x09` | Smart BatteryProtect |
| `0x0A` | Lynx Smart BMS |
| `0x0B` | Multi RS |
| `0x0C` | VE.Bus |
| `0x0D` | DC Energy Meter |
| `0x0F` | Orion XS |

Wichtige Product-ID-Gruppen aus `Victron_ProductId_mapping.txt`:

| Product ID(s) | Beispiele | Discovery-Interpretation |
| --- | --- | --- |
| `0xA040..0xA07E` | BlueSolar / SmartSolar Charger MPPT 75/10 bis 250/100 | MPPT / Solar Charger |
| `0xA102..0xA117` | SmartSolar MPPT VE.Can, SmartSolar MPPT RS 450/100 und 450/200 | MPPT / Solar Charger, teils VE.Can/RS |
| `0xA380..0xA383` | BMV-710 Smart, BMV-712 Smart, BMV-710H Smart | Battery Monitor |
| `0xA389..0xA38E` | SmartShunt 500A/50mV bis IP67 2000A/50mV | Battery Monitor / SmartShunt |
| `0xC030..0xC037` | SmartShunt IP65 Varianten, BMV-800 Smart | Battery Monitor / SmartShunt/BMV |
| `0xA190..0xA19F` | SmartSolar/BMV/SmartShunt/Phoenix Bluetooth Interfaces | Bluetooth Interface, Typ aus Record Type prüfen |
| `0xA200..0xA2BC`, `0xA2E1..` | Phoenix Inverter und Smart Phoenix Inverter Varianten | Inverter |
| `0xA3B0..0xA3B3` | Smart BatteryProtect 12/24V und 48V Varianten | Smart BatteryProtect |
| `0xA3C0..0xA3D3` | Orion Smart DC-DC und Buck-Boost Converter | DC/DC Converter |
| `0xA3E5..0xA3E6` | Lynx Smart BMS 500/1000 | Lynx Smart BMS |
| `0xA401..0xA402` | Inverter RS Solar / Inverter RS | Inverter RS |
| `0xA441..0xA444` | Multi RS Solar 48V/6000VA/100A Varianten | Multi RS |

Für Phase 3.5 sollte die UI alle Victron Instant Readout Header anzeigen, aber
nur `0x01` Solar Charger und `0x02` Battery Monitor als direkt unterstützte
Registrierung anbieten, weil `VictronParser` aktuell nur diese Record-Typen
decodiert.

> **OPEN QUESTION**: Welche Product-ID-Liste soll langfristig als kanonische
> Quelle im Repo liegen: ein kopierter Snapshot aus `Victron_ProductId_mapping.txt`
> oder eine manuell kuratierte kleine Tabelle für die UI? Aktueller Plan:
> kuratierte Tabelle für Phase 3.5, später Generator/Update-Prozess, wenn mehr
> Gerätetypen unterstützt werden.
> Zu klären bevor Implementation startet.

> **OPEN QUESTION**: Sollen nicht unterstützte Victron-Geräte sichtbar, aber
> deaktiviert sein, oder komplett ausgefiltert werden? Aktueller Plan: sichtbar
> mit Badge `Noch nicht unterstützt`, weil das dem Nutzer erklärt, dass Stromer
> das Gerät sieht.
> Zu klären bevor Implementation startet.

## 6. Ein-Tap-Workflow

1. Nutzer öffnet `Gerät hinzufügen`.
2. Tab `In der Nähe` startet oder nutzt den bereits laufenden Scanner.
3. Discovery-Liste zeigt Victron-Geräte aus Manufacturer Data `0x02E1` /
   Payload Byte `0x10`.
4. Nutzer tippt auf ein unterstütztes neues Gerät.
5. `AddDeviceView` wechselt in den Key-Schritt:
   - Name vorausgefüllt aus Product-ID-Mapping oder Local Name.
   - Typ vorausgewählt aus Record Type.
   - `CBPeripheral.identifier` intern gespeichert.
   - Product ID, Record Type, Local Name, RSSI und letzte Raw Advertisement
     werden im ViewModel gehalten.
6. Nutzer fügt den 32-Hex-Advertisement-Key aus VictronConnect ein.
7. Beim Speichern:
   - Key syntaktisch prüfen.
   - Wenn letzte Raw Advertisement vorhanden ist, `VictronParser` mit diesem Key
     ausführen.
   - Bei `.wrongKey`: Speichern blockieren und deutschen Fehler anzeigen.
   - Bei `.success`: Device in `DeviceRegistry` registrieren, Key im Keychain
     speichern, `peripheralID`, `localName`, `productID`, `recordType`,
     `lastSeenAt`, `lastRSSI` übernehmen.
   - Hauptliste aktualisieren und Widget/App-Group-Snapshots wie bisher
     schreiben.
8. Nach erfolgreichem Speichern wird die Add-View geschlossen und das Gerät
   erscheint in `DeviceListView`.

UUID/MAC-Vorausfüllung:

- iOS liefert keine BLE-MAC-Adresse.
- Angezeigt werden darf höchstens eine technische `iPhone-Gerätekennung`
  (`CBPeripheral.identifier`) für Debug/Diagnose.
- Die UI sollte nicht `MAC-Adresse` sagen.
- Persistiert wird die `CBPeripheral.identifier` nur für registrierte Geräte.

Wenn das Gerät zwischen Tap und Speichern verschwindet:

- Der zuletzt gesehene Raw-Advertisement-Snapshot kann noch zur Key-Prüfung
  verwendet werden.
- Ist kein Snapshot mehr verfügbar, darf der Nutzer optional manuell speichern,
  aber die App sollte anzeigen: `Key wird beim nächsten Empfang geprüft`.

> **OPEN QUESTION**: Soll die Registrierung ohne erfolgreiche Key-Prüfung gegen
> ein aktuelles Advertisement erlaubt sein? Aktueller Plan: für Discovery-Flow
> möglichst Key-Prüfung verlangen; manueller Flow bleibt als Fallback ohne
> sofortige Empfangsgarantie.
> Zu klären bevor Implementation startet.

## 7. Privacy / Apple Review

Vorhandene Plist-/Capability-Basis:

- `NSBluetoothAlwaysUsageDescription` ist vorhanden.
- `UIBackgroundModes` enthält `bluetooth-central`.
- App und Widget nutzen die App Group `group.com.lanicode.Stromer`.

Empfohlene Textprüfung:

- Das vorhandene Bluetooth-Wording beschreibt Scannen nach Victron
  BLE-Advertisements und passt grundsätzlich weiter.
- Für Discovery kann das Wording ergänzt werden um: `... und um Victron-Geräte
  in der Nähe beim Hinzufügen vorzuschlagen.`

Fremde Geräte:

- Stromer zeigt nicht alle BLE-Geräte.
- Harte Filterregel: Manufacturer Data Company ID `0x02E1` und Victron Payload
  Byte `0x10`.
- Nicht-Victron-Geräte werden nicht in der App sichtbar gemacht.

MAC-Adressen:

- iOS gibt keine BLE-MAC-Adresse an Apps heraus.
- Stromer darf und kann keine MAC-Adresse persistieren.
- Für registrierte Geräte wird `CBPeripheral.identifier` gespeichert, eine
  lokale UUID, die nur auf diesem iPhone als Wiedererkennungshilfe dient.

Aufräumen der Discovery-Liste:

- Discovery-Cache ist In-Memory.
- Beim Verlassen von `AddDeviceView` wird die Liste verworfen.
- Keine Persistenz von unregistrierten Geräten.
- Optional kann der Scanner weiterlaufen, wenn er für Live-Daten ohnehin aktiv
  ist; nur die UI-spezifische Discovery-Map wird geleert.

Apple-Review-Erklärung:

- Die App verbindet sich nicht aktiv mit fremden Geräten.
- Die App liest passiv öffentliche Victron Manufacturer Data und entschlüsselt
  nur Geräte, für die der Nutzer einen Key aus VictronConnect eingibt.
- Widgets und Live Activities scannen nicht, sondern lesen nur App-Group-
  Snapshots.

> **OPEN QUESTION**: Soll die Bluetooth-Usage-Description in Phase 3.5
> angepasst werden, obwohl sie inhaltlich bereits korrekt ist? Aktueller Plan:
> ja, um Discovery ausdrücklich zu erwähnen.
> Zu klären bevor Implementation startet.

## 8. Edge Cases

| Edge Case | Erwartetes Verhalten |
| --- | --- |
| Gerät verschwindet während Discovery | Zeile bleibt bis TTL-Ablauf sichtbar, wird danach ausgegraut oder entfernt. Key-Schritt darf mit letztem Advertisement fortfahren, wenn vorhanden. |
| Gerät sendet mehrfach mit unterschiedlichem RSSI | Ein Eintrag pro `peripheralID`; RSSI und `lastSeenAt` werden aktualisiert, Liste springt nicht aggressiv. |
| Bluetooth ist aus | Discovery-Tab zeigt `Bluetooth ist ausgeschaltet`; Button zu Einstellungen oder Hinweis, manueller Flow bleibt erreichbar. |
| Bluetooth-Permission verweigert | Discovery-Tab zeigt `Bluetooth-Zugriff abgelehnt` und `Einstellungen öffnen`; manueller Flow bleibt erreichbar. |
| Gerät bereits registriert | Badge `Bereits registriert`; kein zweites Hinzufügen. Tap öffnet vorhandene Detailansicht oder zeigt erklärenden Hinweis. |
| Key ist falsch | Parser liefert `.wrongKey`; Registrierung wird blockiert, Feld zeigt Fehler. |
| Product ID unbekannt | Zeile zeigt `Victron-Gerät`; Typ kommt falls möglich aus Record Type. Hinzufügen nur bei unterstütztem Record Type. |
| Record Type nicht unterstützt | Zeile sichtbar, Badge `Noch nicht unterstützt`, Hinzufügen deaktiviert. |
| Mehrere Geräte mit gleichem Local Name | Liste unterscheidet über Modellname, RSSI, letzte Sichtung und interne `peripheralID`; UI zeigt nicht mehrere identische Namen ohne Zusatz. |
| App geht in Hintergrund während AddDeviceView offen ist | Discovery-UI darf einfrieren; letzte Treffer bleiben kurz sichtbar. Keine Refresh-Cadence versprechen. |
| Gerät wechselt `CBPeripheral.identifier` nach Reinstall/iPhone-Wechsel | Discovery zeigt es als neu, bis Key-Validierung es wieder einem registrierten Gerät zuordnen kann. |
| Manufacturer Data zu kurz oder malformed | Advertisement wird still ignoriert; keine UI-Fehlerzeile. |

## 9. OPEN QUESTIONS

> **OPEN QUESTION**: Welche Product-ID-Liste soll langfristig als kanonische
> Quelle im Repo liegen: ein kopierter Snapshot aus `Victron_ProductId_mapping.txt`
> oder eine manuell kuratierte kleine Tabelle für die UI? Aktueller Plan:
> kuratierte Tabelle für Phase 3.5, später Generator/Update-Prozess, wenn mehr
> Gerätetypen unterstützt werden.
> Zu klären bevor Implementation startet.

> **OPEN QUESTION**: Sollen nicht unterstützte Victron-Geräte sichtbar, aber
> deaktiviert sein, oder komplett ausgefiltert werden? Aktueller Plan: sichtbar
> mit Badge `Noch nicht unterstützt`, weil das dem Nutzer erklärt, dass Stromer
> das Gerät sieht.
> Zu klären bevor Implementation startet.

> **OPEN QUESTION**: Soll die Registrierung ohne erfolgreiche Key-Prüfung gegen
> ein aktuelles Advertisement erlaubt sein? Aktueller Plan: für Discovery-Flow
> möglichst Key-Prüfung verlangen; manueller Flow bleibt als Fallback ohne
> sofortige Empfangsgarantie.
> Zu klären bevor Implementation startet.

> **OPEN QUESTION**: Soll die Bluetooth-Usage-Description in Phase 3.5
> angepasst werden, obwohl sie inhaltlich bereits korrekt ist? Aktueller Plan:
> ja, um Discovery ausdrücklich zu erwähnen.
> Zu klären bevor Implementation startet.

> **OPEN QUESTION**: Wie lang soll die Discovery-TTL sein? Aktueller Plan:
> 30 Sekunden im Foreground, danach ausblenden oder als `zuletzt gesehen`
> abdunkeln.
> Zu klären bevor Implementation startet.

## 10. Out of Scope für Phase 3.5

- QR-Code-Scanning für den Advertisement Key.
- Discovery für andere BLE-Hersteller.
- Persistenz von kürzlich gesehenen, aber nicht registrierten Geräten.
- Verbindung zu Victron-Geräten über GATT.
- Schreiben von Victron-Konfiguration.
- Background-Discovery mit garantierter Refresh-Cadence.
- Historische Discovery-Logs.
- Multi-User- oder iCloud-Synchronisierung von registrierten Geräten.
- Support für Payload-Decoding von Inverter, Smart BatteryProtect, Lynx Smart
  BMS, Multi RS, Orion XS oder VE.Bus.
- Automatische Key-Ermittlung ohne VictronConnect.
