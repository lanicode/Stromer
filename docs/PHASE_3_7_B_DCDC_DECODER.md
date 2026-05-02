# Phase 3.7b - DC/DC Converter Decoder

Status: Architektur-Dokumentation. Keine Implementation.

## Quellen

- `docs/VICTRON_PROTOCOL.md`
- `docs/PHASE_3_5_DISCOVERY.md`, Section 5
- `Packages/VictronParser/Sources/VictronParser/Devices/SolarChargerRecord.swift`
- `Packages/VictronParser/Sources/VictronParser/Devices/BatteryMonitorRecord.swift`
- `Packages/VictronParser/Sources/VictronParser/VictronParser.swift`
- `Packages/VictronParser/Sources/VictronParser/Models/ChargerState.swift`
- `Packages/StromerScanner/Sources/StromerScanner/Models/DeviceReading.swift`
- `Packages/StromerScanner/Sources/StromerScanner/Models/DeviceReadingPresentation.swift`
- `Packages/StromerScanner/Sources/StromerScanner/Persistence/WidgetSnapshotProvider.swift`
- `Stromer/Views/DeviceDetail/DeviceDetailView.swift`
- Python-Referenz `keshavdv/victron-ble`:
  - `victron_ble/devices/dcdc_converter.py`
  - `victron_ble/devices/base.py`
  - `tests/test_dcdc_converter.py`

## 1. Uebersicht

Phase 3.7b ergänzt den ersten Decoder für Victron DC/DC Converter
Advertisements mit Record Type `0x04`. Primäres Hardware-Ziel ist der beim User
vorhandene Orion Smart 12V/12V-30A Buck-Boost Converter, Product ID `0xA3D0`.

Betroffene Gerätefamilie:

- Orion Smart DC-DC Converter, Product IDs `0xA3C0...0xA3CF`
- Orion Smart Buck-Boost Converter, Product IDs `0xA3D0...0xA3D3`
- Weitere Record-Type-`0x04`-Geräte, sofern sie das gleiche Instant-Readout-
  Layout verwenden

Nach der Implementation sollen DC/DC-Geräte in Discovery und Registrierung nicht
mehr als `plannedPhase37`, sondern als `supported` behandelt werden. Bereits
registrierte Orion-Geräte sollen ohne erneute Registrierung live decodiert
werden, sobald ein passendes Advertisement mit bekanntem Key empfangen wird.

## 2. Bit-Layout aus Python-Reference

Die Python-Referenz verwendet für `DcDcConverter.parse_decrypted` denselben
LSB-first `BitReader` wie Solar Charger und Battery Monitor. Der Parser liest
fünf Felder byte-aligned aus dem entschlüsselten Payload.

| Field | Plaintext bits | PDF bits | Raw type | Scale/unit | NA value | Beschreibung |
| --- | ---: | ---: | --- | --- | --- | --- |
| `device_state` / `charge_state` | 0..7 | 32..39 | `uint8` | Operation/charge state enum | `0xFF` | Lade-/Betriebszustand, Python `OperationMode` |
| `charger_error` | 8..15 | 40..47 | `uint8` | Victron charger error code | `0xFF` | Fehlercode, Python `ChargerError` |
| `input_voltage` | 16..31 | 48..63 | `uint16` | raw / 100 V | `0xFFFF` | Eingangsspannung |
| `output_voltage` | 32..47 | 64..79 | `int16` | raw / 100 V | raw/signed `0x7FFF` | Ausgangsspannung |
| `off_reason` | 48..79 | 80..111 | `uint32` | raw Victron off reason | none documented | Grund, warum der Ausgang/Lader aus ist |
| unused / reserved | 80..127 | 112..159 | bits | ignore | - | Python-Testvektor enthält 16 Byte decrypted payload; nur die ersten 80 Bits werden gelesen |

Python-Testvektoren:

| Scope | Hex | Erwartung |
| --- | --- | --- |
| End-to-End Advertisement | `1000c0a304121d64ca8d442b90bbdf6a8cba` mit Key `64ba49f1a8562e45197a8e1fe50d7658` | Product ID `0xA3C0`, state `off`, error `no_error`, input `13.15 V`, output `nil`, off reason `engine_shutdown` |
| Decrypted Payload | `00002305ff7f80000000cbdd494cc5d1` | Gleiche Feldwerte wie oben |

Byte-/Bit-Aufschlüsselung des decrypted Testpayloads:

| Bytes | Field | Raw | Decoded |
| --- | --- | ---: | --- |
| `00` | `device_state` | `0` | `off` |
| `00` | `charger_error` | `0` | `no_error` |
| `23 05` | `input_voltage` | `0x0523` = 1315 | `13.15 V` |
| `ff 7f` | `output_voltage` | `0x7FFF` | `nil` |
| `80 00 00 00` | `off_reason` | `0x00000080` | `engine_shutdown` |

Implementation-Hinweise:

- `input_voltage` ist laut Python unsigned, nicht signed.
- `output_voltage` ist signed `int16`; Sentinel vor oder nach Signed-Conversion
  ergibt für `0x7FFF` denselben Wert, aber der Swift-Decoder sollte den raw
  `UInt16` vor der Conversion prüfen, analog zu den bestehenden Sentinel-
  Checks.
- `off_reason` hat in Python keinen NA-Sentinel und wird immer gelesen.
- Python hat keinen Testvektor für Product ID `0xA3D0`; der vorhandene
  End-to-End-Test ist `0xA3C0`. Für `0xA3D0` muss in Phase 3.7b zusätzlich ein
  Hardware-Dump oder ein synthetischer Header-Test ergänzt werden.

## 3. Charge-State-Enum

DC/DC verwendet in der Python-Referenz `OperationMode`, dieselbe Werteliste wie
bei anderen Victron-Ladezuständen. Stromer hat dafür bereits
`ChargerState`/`DevicePresentation.chargerStateTitle`.

| Raw | Python `OperationMode` | Deutscher UI-Titel, Vorschlag |
| ---: | --- | --- |
| `0` | `OFF` | Aus |
| `1` | `LOW_POWER` | Niedrige Leistung |
| `2` | `FAULT` | Fehler |
| `3` | `BULK` | Bulk |
| `4` | `ABSORPTION` | Absorption |
| `5` | `FLOAT` | Float |
| `6` | `STORAGE` | Lagerung |
| `7` | `EQUALIZE_MANUAL` | Ausgleich manuell |
| `9` | `INVERTING` | Invertierend |
| `11` | `POWER_SUPPLY` | Netzteilmodus |
| `245` | `STARTING_UP` | Startet |
| `246` | `REPEATED_ABSORPTION` | Wiederholte Absorption |
| `247` | `RECONDITION` | Rekonditionierung |
| `248` | `BATTERY_SAFE` | Battery Safe |
| `249` | `ACTIVE` | Aktiv |
| `252` | `EXTERNAL_CONTROL` | Externe Steuerung |
| `255` | `NOT_AVAILABLE` | Nicht verfügbar / Swift `nil` |

Architekturentscheidung:

- Für Phase 3.7b kein zweites Charge-State-Enum anlegen.
- `DcDcConverterRecord.chargeState` soll denselben RawRepresentable-Typ nutzen
  wie Solar Charger (`ChargerState?`), sofern die Namen im VictronParser nicht
  vorher allgemeiner in `OperationMode` umbenannt werden.
- Unbekannte Werte müssen als Raw Value erhalten bleiben. Kein Crash bei neuen
  Victron-Zuständen.

## 4. Off-Reason-Enum oder Bitfield

Python modelliert `OffReason` als `Enum`, die Werte sehen aber teilweise wie
Bitflags und teilweise wie vorkombinierte Zustände aus.

| Raw | Python `OffReason` | Bedeutung, UI-Vorschlag |
| ---: | --- | --- |
| `0x00000000` | `NO_REASON` | Kein Grund |
| `0x00000001` | `NO_INPUT_POWER` | Keine Eingangsspannung |
| `0x00000002` | `SWITCHED_OFF_SWITCH` | Per Schalter ausgeschaltet |
| `0x00000004` | `SWITCHED_OFF_REGISTER` | Per Register ausgeschaltet |
| `0x00000008` | `REMOTE_INPUT` | Remote-Eingang aus |
| `0x00000010` | `PROTECTION_ACTIVE` | Schutz aktiv |
| `0x00000014` | `LOAD_OUTPUT_DISABLED` | Lastausgang deaktiviert |
| `0x00000020` | `PAY_AS_YOU_GO_OUT_OF_CREDIT` | Pay-as-you-go Guthaben leer |
| `0x00000040` | `BMS` | BMS hat abgeschaltet |
| `0x00000080` | `ENGINE_SHUTDOWN` | Motorabschaltung erkannt |
| `0x00000081` | `ENGINE_SHUTDOWN_AND_INPUT_VOLTAGE_LOCKOUT` | Motorabschaltung und Eingangsspannungs-Sperre |
| `0x00000100` | `ANALYSING_INPUT_VOLTAGE` | Eingangsspannung wird analysiert |

Architekturentscheidung:

- Swift soll `offReason` als raw-preserving Value Type modellieren, nicht als
  strikt exhaustives Enum. Vorschlag: `DcDcOffReason: RawRepresentable,
  Equatable, Hashable, Sendable, Codable` mit `rawValue: UInt32`,
  bekannten statischen Konstanten und `knownName`.
- UI zeigt erst einen bekannten Titel, sonst `Unbekannt (0x...)`.
- Für Flags kann später eine Convenience-Schicht ergänzt werden. Phase 3.7b
  muss aber zuerst Raw-Werte verlustfrei persistieren. Die genaue fachliche
  Semantik bleibt als OPEN QUESTION in Section 10 markiert.

## 5. Datenmodell-Erweiterung

Der Task erwähnt als Option eine flache Erweiterung von `DeviceReading` mit
weiteren Optional-Feldern. Die aktuelle Codebasis hat diesen Schritt bereits
vermieden: `DeviceReading` enthält `payload: DeviceReadingPayload`, und die
familienbezogenen Felder liegen in `SolarChargerReading` bzw.
`BatteryMonitorReading`.

Option A: flache Erweiterung

- Pro: sehr einfache direkte Zugriffe in Views.
- Contra: `DeviceReading` würde mit jeder Victron-Familie breiter und
  unklarer; Widget, Detailansicht und Persistence müssten viele fachfremde
  optionale Felder kennen.

Option B: strukturiertes Payload-Enum

- Pro: passt zum aktuellen Code, trennt Familien sauber, bleibt Codable und
  testbar.
- Contra: Jede Presentation-Schicht muss einen neuen `switch`-Case ergänzen.

Architekturentscheidung:

- Phase 3.7b erweitert das bestehende Enum:
  - `DeviceReadingKind.dcDcConverter`
  - `DcDcConverterReading`
  - `DeviceReadingPayload.dcDcConverter(DcDcConverterReading)`
- Kein flacher Umbau von `DeviceReading`.

Benötigte Felder in `DcDcConverterReading`:

| Field | Type | Quelle |
| --- | --- | --- |
| `chargeStateRaw` | `UInt8?` | `DcDcConverterRecord.chargeState?.rawValue` |
| `chargerErrorCode` | `UInt8?` | `charger_error`, nil bei `0xFF` |
| `inputVoltage` | `Double?` | raw / 100 V |
| `outputVoltage` | `Double?` | raw / 100 V |
| `offReasonRaw` | `UInt32` | raw `off_reason` |

Benötigte Parser-Erweiterungen:

- `DeviceType.dcDcConverter = 0x04`
- `VictronRecord.dcDcConverter(DcDcConverterRecord)`
- `DcDcConverterRecord.parse(productID:decrypted:)`
- Product-ID-Mapping im VictronParser für `0xA3C0...0xA3D3`, mindestens aber
  `0xA3D0`

## 6. Presentation Layer

`DeviceDetailView` soll DC/DC wie eine eigene Gerätefamilie rendern. Primärer
Wert ist die Ausgangsspannung, weil der Orion als DC/DC-Lader im Alltag die
Versorgung der Zielbatterie beschreibt. Wenn `outputVoltage` nicht verfügbar
ist, fällt die Anzeige auf `inputVoltage` zurück.

Detail-Mockup:

```text
+------------------------------------------------+
| Orion Smart 12V/12V-30A Buck-Boost Converter  |
| DC/DC Converter                               |
|                                                |
| 14.20 V                                       |
| Frisch  Letzte Aktualisierung: gerade eben     |
+------------------------------------------------+

Live-Daten
  Ladezustand              Bulk
  Charger Error            Kein Fehler
  Eingangsspannung         13.15 V
  Ausgangsspannung         14.20 V
  Aus-Grund                Kein Grund
  Off Reason Raw           0x00000000
```

Falls das Gerät gerade aus ist:

```text
Live-Daten
  Ladezustand              Aus
  Eingangsspannung         13.15 V
  Ausgangsspannung         -
  Aus-Grund                Motorabschaltung erkannt
```

UI-Integration:

- `DevicePresentation.summary` ergänzt Case `.dcDcConverter`.
- `DevicePresentation.icon(forRecordType:)` liefert für `0x04` z.B.
  `arrow.left.arrow.right.circle.fill` oder `bolt.horizontal.circle.fill`.
- `DevicePresentation.title(forRecordType:)` liefert `Orion Smart`.
- `DeviceDetailView.liveDataSection` ergänzt `dcDcRows`.
- `DeviceDetailView.supportStatus(for:)` zeigt für DC/DC nach der
  Implementation nicht mehr `Decoding folgt`, weil Record Type `0x04` dann
  supported ist.

Empfohlene Hauptwert-Priorität:

1. `outputVoltage` als `V`
2. `inputVoltage` als `V`
3. `chargeState` als Text, falls keine Spannung verfügbar ist
4. `--`, wenn nichts verwertbar ist

## 7. Widget und Live Activity

Widgets werden über `WidgetSnapshotProvider` aus `DeviceReadingPresentation`
gefüttert. Deshalb sollte DC/DC dort zentral als Summary ergänzt werden, statt
Widget-spezifische Sonderlogik einzubauen.

Widget-Summary für Orion:

- Hauptwert: `outputVoltage` in Volt
- Sekundär: `Eingang 13.15 V • Bulk`
- Wenn `outputVoltage == nil`: Hauptwert `inputVoltage`, Sekundär
  `Ausgang nicht verfügbar • <Off Reason>`
- Icon: gleiches Symbol wie in DeviceDetail
- Device-Titel: `Orion Smart`

Live Activity:

- `StromerActivityAttributes.ContentState` ist aktuell generisch genug:
  `value`, `unit`, `secondary`, `lastUpdated`, `freshness`.
- Keine ActivityKit-Modelländerung nötig, solange `DevicePresentation.summary`
  DC/DC korrekt liefert.

## 8. Persistenz und Migration

`DeviceReadingPayload` ist `Codable`. Eine neue Enum-Case ist für neu
geschriebene Snapshots unproblematisch, kann aber alte App-Versionen beim Lesen
neuer Snapshots nicht kompatibel machen. Das ist für App-Store-Updates in eine
Richtung akzeptabel.

Implementation-Plan:

- Neue App-Version kann alte Readings lesen, weil bestehende Cases unverändert
  bleiben.
- Neue DC/DC-Readings werden erst geschrieben, wenn die neue Version läuft.
- Falls ein DC/DC-Reading nicht dekodiert werden kann, soll der Parser
  `.malformed` oder `.unsupportedDevice` liefern, aber bestehende gespeicherte
  Daten nicht löschen.

## 9. Testplan fuer Phase 3.7b Implementation

VictronParser:

- End-to-End-Test aus Python:
  - Advertisement `1000c0a304121d64ca8d442b90bbdf6a8cba`
  - Key `64ba49f1a8562e45197a8e1fe50d7658`
  - Erwartung: Product ID `0xA3C0`, Record Type `0x04`, state `off`, error `0`,
    input `13.15 V`, output `nil`, off reason `0x00000080`
- Decrypted-Payload-Test:
  - `00002305ff7f80000000cbdd494cc5d1`
- Sentinel-Tests:
  - `device_state = 0xFF` -> nil
  - `charger_error = 0xFF` -> nil
  - `input_voltage = 0xFFFF` -> nil
  - `output_voltage = 0x7FFF` -> nil
- Signed-Test:
  - `output_voltage` mit negativem `int16` korrekt dekodieren, auch wenn das in
    realen DC/DC-Daten selten sein sollte.
- Unknown-value-Tests:
  - unbekannter `charge_state` bleibt raw erhalten
  - unbekannter `off_reason` bleibt raw erhalten

StromerScanner:

- `DeviceReading(device:record:rssi:timestamp:now:)` baut
  `.dcDcConverter`-Payload.
- `DeviceReadingPresentation.summary` liefert Orion-Hauptwert und Secondary.
- `WidgetSnapshotProvider` erzeugt aus einem DC/DC-Reading ein Widget-Snapshot
  ohne Spezialcode.
- Catalog-Support-Status für Record Type `0x04` wechselt in dieser Phase von
  `plannedPhase37` zu `supported`.

App/UI:

- `DeviceDetailView` zeigt DC/DC-Felder vollständig.
- Ein bereits registrierter Orion zeigt nach erstem erfolgreichen Reading nicht
  mehr `Decoding folgt`.
- Live Activity kann mit DC/DC-Reading gestartet werden und zeigt Volt als
  Hauptwert.

Hardware-Test:

- Orion Smart 12V/12V-30A Buck-Boost (`0xA3D0`) mit echtem Advertisement Key
  registrieren.
- App im Vordergrund lassen und Werte gegen VictronConnect vergleichen:
  Eingangsspannung, Ausgangsspannung, Ladezustand, Off Reason.
- Gerät/Motorzustand wechseln, falls möglich, um mindestens `off` und einen
  aktiven Ladezustand zu sehen.

## 10. OPEN QUESTIONS

> **OPEN QUESTION**: Gibt es für Product ID `0xA3D0` einen echten
> End-to-End-Testvektor mit Advertisement und Key? Aktueller Plan: Python-
> Vektor `0xA3C0` als Parser-Regression portieren und zusätzlich einen
> Hardware-Dump des vorhandenen `0xA3D0`-Geräts für einen späteren Test
> erfassen. Zu klären bevor Implementation final gemerged wird.

> **OPEN QUESTION**: Ist `off_reason` fachlich ein echtes Bitfield oder eine
> Enum mit einzelnen und vorkombinierten Werten? Aktueller Plan:
> raw-preserving `DcDcOffReason` mit bekannten Konstanten, UI zeigt bekannten
> Einzeltitel oder Raw-Hex. Zu klären bevor eine Multi-Badge-UI für mehrere
> gleichzeitige Off-Reasons gebaut wird.

> **OPEN QUESTION**: Soll der User-facing Hauptwert im Widget bei aktivem
> DC/DC-Laden immer `outputVoltage` sein, oder ist für bestimmte Orion-
> Installationen `inputVoltage` wichtiger? Aktueller Plan: `outputVoltage`
> priorisieren, weil sie die versorgte Zielseite beschreibt; Fallback auf
> `inputVoltage`, wenn Ausgang nicht verfügbar ist. Zu klären im Hardware-Test.

> **OPEN QUESTION**: Soll `ChargerState` im VictronParser zu `OperationMode`
> umbenannt werden, weil DC/DC und Solar Charger denselben Python-/VE.Direct-
> Wertebereich nutzen? Aktueller Plan: keine Umbenennung in Phase 3.7b, um den
> Patch klein zu halten; DC/DC nutzt den bestehenden Typ. Zu klären vor
> breiterer Phase 3.7-Familienarbeit.

## 11. Out of Scope

- Kein Decoder für Phoenix Inverter (`0x03`) in dieser Phase.
- Kein Decoder für SmartLithium, AC Charger oder Smart BatteryProtect.
- Keine Decoder für Out-of-Scope-Familien wie Lynx BMS, VE.Bus, Multi RS,
  Inverter RS, VE.Direct DC Energy Meter oder Orion XS.
- Keine Änderung am BLE-Scanner, an iOS-Background-Scanning oder Discovery-TTL.
- Keine neue Historie/Charts.
- Keine neue Device-Registrierungs-UI.
- Keine QR-Code-Erfassung des Advertisement Keys.
- Keine neuen Widget-Familien oder Live-Activity-Layouts.
