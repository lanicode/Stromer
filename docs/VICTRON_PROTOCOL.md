# Victron BLE Instant Readout Protocol

Status: Phase 1 documentation only. This document describes the Victron BLE
Instant Readout advertisements needed by the iOS app. It is based on the
official Victron "Extra manufacturer Data" PDF, the Victron Community protocol
thread, and the Python reference implementation `keshavdv/victron-ble`.

## Sources Read

- Official Victron spec PDF: https://github.com/keshavdv/victron-ble/blob/main/extra-manufacturer-data-2022-12-14.pdf
- Victron Community reference thread: https://community.victronenergy.com/questions/187303/victron-bluetooth-advertising-protocol.html
- Python reference implementation, commit `c721522bee77fdf3b2cf304d5b9afc46e39bffe4`: https://github.com/keshavdv/victron-ble
  - `victron_ble/devices/__init__.py`
  - `victron_ble/devices/base.py`
  - `victron_ble/devices/battery_monitor.py`
  - `victron_ble/devices/solar_charger.py`
  - `victron_ble/scanner.py`
  - `Victron_ProductId_mapping.txt`
- Apple Core Bluetooth background processing: https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html
- Apple Core Bluetooth peer identifier documentation: https://developer.apple.com/documentation/corebluetooth/cbpeer/identifier
- Apple Core Bluetooth scanning documentation: https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/scanforperipherals%28withservices%3Aoptions%3A%29

## Terminology and Offsets

There are two useful byte coordinate systems:

- **Full BLE Manufacturer Specific Data**: the `AD type 0xFF` value, including
  the 2-byte Bluetooth Company Identifier.
- **Victron manufacturer payload**: bytes after the Company Identifier. Bleak
  exposes this as `advertisement.manufacturer_data[0x02E1]`. CoreBluetooth
  commonly exposes the full manufacturer data as `Data`, so iOS parsing should
  first validate and skip the two Company Identifier bytes.

All integer fields in the advertisement header are little-endian unless noted
otherwise. Payload bit fields are packed LSB-first, matching the Python
`BitReader`: bit offset 0 is the least significant bit of plaintext byte 0.

## Advertisement Header Layout

### Full BLE Manufacturer Specific Data

| Offset | Size | Meaning | Endian / value |
| --- | ---: | --- | --- |
| 0 | 2 | Bluetooth Company Identifier | `0x02E1`, little-endian on the wire as `E1 02` |
| 2.. | variable | Victron manufacturer payload | Starts with Product Advertisement record `0x10` |

If an API has already stripped the company identifier, parse the Victron
manufacturer payload from offset 0 instead.

### Victron Manufacturer Payload

Offsets below exclude the 2-byte Company Identifier.

| Offset | Size | Meaning | Endian / value |
| --- | ---: | --- | --- |
| 0 | 1 | Manufacturer Data Record Type | `0x10` = Product Advertisement / Instant Readout |
| 1 | 1 | Product Advertisement variant byte | Variable; observed as `0x02` for SmartShunt/MPPT, but not a validation field |
| 2 | 2 | Product ID / model ID | `uint16` little-endian, mapped via `Victron_ProductId_mapping.txt` |
| 4 | 1 | Extra record type / device type | `0x01` Solar Charger, `0x02` Battery Monitor, etc. |
| 5 | 2 | Nonce / Data Counter / AES IV seed | `uint16` little-endian |
| 7 | 1 | Encryption Key First Byte | Must match byte 0 of the 16-byte advertisement key |
| 8..end | variable | Encrypted payload | AES-CTR ciphertext, up to 16 plaintext bytes by current layouts |

Examples from the Python tests:

| Raw Victron payload prefix | Decoded Product ID | Model |
| --- | ---: | --- |
| `10 02 57 A0 01 ...` | `0xA057` | SmartSolar Charger MPPT 100/50 |
| `10 02 89 A3 02 ...` | `0xA389` | SmartShunt 500A/50mV |
| `10 xx D0 A3 04 ...` | `0xA3D0` | Orion Smart 12V/12V-30A DC/DC Converter; byte 1 may differ from `0x02` |

OPEN QUESTION: The required sources do not define the semantic name of Victron
manufacturer payload byte 1. The Python reference scanner validates only
payload byte 0 (`0x10`) and `detect_device_type` reads Product ID from bytes
2..3 plus record type from byte 4, so iOS must not require byte 1 to be
`0x02`. Treat byte 1 as a variable Product Advertisement variant byte until a
primary source names it.

## Device Type Detection

The Python reference filters advertisements by:

- Company Identifier `0x02E1`
- Victron manufacturer payload byte 0 = `0x10`

It then detects the parser from Victron manufacturer payload byte 4:

| Record type | Device class |
| ---: | --- |
| `0x00` | Test record |
| `0x01` | Solar Charger |
| `0x02` | Battery Monitor |
| `0x03` | Inverter |
| `0x04` | DC/DC converter |
| `0x05` | SmartLithium |
| `0x06` | Inverter RS |
| `0x07` | GX-Device, layout TBD in PDF |
| `0x08` | AC Charger, layout TBD in PDF |
| `0x09` | Smart Battery Protect |
| `0x0A` | Lynx Smart BMS |
| `0x0B` | Multi RS |
| `0x0C` | VE.Bus |
| `0x0D` | DC Energy Meter |
| `0x0E..0xFF` | Reserved / future extensions |

Python also overrides Product IDs `0xA3A4` and `0xA3A5` to the Battery Sense
parser, regardless of record type.

Product names come from `Victron_ProductId_mapping.txt` / `MODEL_ID_MAPPING`.
Unknown IDs should remain parseable and display as unknown rather than failing
the whole advertisement.

## Decryption Flow

1. Read the Victron manufacturer payload and verify byte 0 is `0x10`.
2. Read Product ID from bytes 2..3, record type from byte 4, nonce from bytes
   5..6, and key-check byte from byte 7.
3. Load the device-specific advertisement key from VictronConnect. It is a
   16-byte AES key, normally represented as 32 hex characters.
4. Validate that advertisement key byte 0 equals the key-check byte at offset 7.
   If it does not match, the key is for a different device or an old pairing
   state; do not attempt to decode the payload.
5. Decrypt bytes 8..end with AES-128-CTR.
6. Build the AES-CTR initial counter block with the nonce bytes in the lower
   bytes exactly as transmitted: `nonce[0], nonce[1], 0x00 ... 0x00`.
7. The Python reference uses PyCryptodome `Counter.new(128,
   initial_value=nonce, little_endian=True)`.

AES-CTR is a stream mode: the transmitted ciphertext length does not need to be
a multiple of 16 bytes. The Python reference pads ciphertext before decrypting
because of the library call shape, but the meaningful payload is still only the
record bytes required by the bit layout. Current observed/test lengths are 12
encrypted bytes for Solar Charger and 15 encrypted bytes for Battery Monitor;
the official layouts reserve up to 16 plaintext bytes.

OPEN QUESTION: The PDF says the AES-CTR counter field is an MSB counter that
starts at 0, while the Python reference and community example show the 2-byte
nonce placed at the beginning of the 16-byte counter block and configure the
counter little-endian. For app compatibility, follow the Python/community
layout unless Victron publishes a clearer Swift-oriented counter-block example.

## Payload Bit Packing

The decrypted payload is not a sequence of byte-aligned structs. It is a
LSB-first bit stream:

- Read field 1 from the least significant bits of byte 0.
- Multi-byte aligned fields therefore behave like little-endian integers.
- Non-byte-aligned fields, such as Battery Monitor current, continue at the
  next bit offset without padding.
- Signed fields are two's-complement with the field's own bit width.
- Sentinel / NA values must be checked against the raw field value where the
  sentinel is all ones for a signed non-byte-width field.

The official PDF gives payload field offsets starting at bit 32 because bits
0..31 are the extra-record header: record type, nonce, and key-check byte. The
tables below include plaintext offsets after decryption and the corresponding
PDF offsets.

## Solar Charger Payload, Record Type `0x01`

Applies to SmartSolar / BlueSolar MPPT records parsed by
`victron_ble/devices/solar_charger.py`.

| Field | Plaintext bits | PDF bits | Raw type | Scale / unit | NA value | Python output |
| --- | ---: | ---: | --- | --- | --- | --- |
| `device_state` | 0..7 | 32..39 | `uint8` | Operation state enum | `0xFF` | `charge_state` or `None` |
| `charger_error` | 8..15 | 40..47 | `uint8` | Charger error enum/code | `0xFF` | `charger_error` or `None` |
| `battery_voltage` | 16..31 | 48..63 | `int16` | raw / 100 V | `0x7FFF` | volts or `None` |
| `battery_current` | 32..47 | 64..79 | `int16` | raw / 10 A | `0x7FFF` | amps or `None` |
| `yield_today` | 48..63 | 80..95 | `uint16` | raw * 0.01 kWh | `0xFFFF` | Wh as `raw * 10`, or `None` |
| `pv_power` | 64..79 | 96..111 | `uint16` | raw W | `0xFFFF` | watts or `None` |
| `load_current` | 80..88 | 112..120 | `uint9` | raw / 10 A | `0x1FF` | amps or `None` |
| unused | 89..127 | 121..159 | bits | Set/unused | - | ignore |

Known `device_state` values in the Python reference:

| Value | Meaning |
| ---: | --- |
| 0 | off |
| 1 | low power |
| 2 | fault |
| 3 | bulk |
| 4 | absorption |
| 5 | float |
| 6 | storage |
| 7 | equalize manual |
| 9 | inverting |
| 11 | power supply |
| 245 | starting up |
| 246 | repeated absorption |
| 247 | recondition |
| 248 | battery safe |
| 249 | active |
| 252 | external control |
| 255 | not available |

`charger_error` is a raw Victron charger error code. The Python enum contains
known values including `0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `11`,
`14`, `17`, `18`, `20`, `21`, `22`, `23`, `24`, `26`, `27`, `28`, `29`,
`33`, `34`, `35`, `38`, `39`, `40`, `41`, `42`, `43`, `50`, `51`, `52`,
`53`, `54`, `55`, `56`, `57`, `58`, `65`, `66`, `67`, `68`, `69`, `70`,
`71`, `80`..`87`, `114`, `116`, `117`, `119`, `121`, `200`, `201`, `202`,
`203`, `205`, `212`, and `215`. Unknown non-`0xFF` values should be preserved
as raw codes instead of crashing the app.

## Battery Monitor Payload, Record Type `0x02`

Applies to SmartShunt / BMV records parsed by
`victron_ble/devices/battery_monitor.py`.

| Field | Plaintext bits | PDF bits | Raw type | Scale / unit | NA value | Python output |
| --- | ---: | ---: | --- | --- | --- | --- |
| `time_to_go` | 0..15 | 32..47 | `uint16` | raw minutes | `0xFFFF` | `remaining_mins` or `None` |
| `battery_voltage` | 16..31 | 48..63 | `int16` | raw / 100 V | `0x7FFF` | volts or `None` |
| `alarm_reason` | 32..47 | 64..79 | `uint16` | alarm flags/code | none | `AlarmReason` |
| `aux_value` | 48..63 | 80..95 | `uint16` raw | depends on `aux_mode` | none specified | starter/midpoint/temp value |
| `aux_mode` | 64..65 | 96..97 | `uint2` | mode enum | `0x3` = none | `AuxMode` |
| `battery_current` | 66..87 | 98..119 | `int22` | raw / 1000 A | raw `0x3FFFFF` | amps or `None` |
| `consumed_ah` | 88..107 | 120..139 | `uint20` | `-raw / 10` Ah | `0xFFFFF` | Ah or `None` |
| `soc` | 108..117 | 140..149 | `uint10` | raw / 10 % | `0x3FF` | percent or `None` |
| unused | 118..127 | 150..159 | bits | Set/unused | - | ignore |

`aux_mode` values:

| Value | Python enum | Meaning | `aux_value` interpretation |
| ---: | --- | --- | --- |
| 0 | `STARTER_VOLTAGE` | Aux / starter voltage | signed `int16`, raw / 100 V |
| 1 | `MIDPOINT_VOLTAGE` | Midpoint voltage | unsigned `uint16`, raw / 100 V |
| 2 | `TEMPERATURE` | Battery temperature | unsigned `uint16`, raw / 100 K, then Celsius = K - 273.15 |
| 3 | `DISABLED` | No aux input | ignore `aux_value` |

Known `alarm_reason` values in the Python reference:

| Value | Meaning |
| ---: | --- |
| 0 | no alarm |
| 1 | low voltage |
| 2 | high voltage |
| 4 | low SOC |
| 8 | low starter voltage |
| 16 | high starter voltage |
| 32 | low temperature |
| 64 | high temperature |
| 128 | midpoint deviation |
| 256 | overload |
| 512 | DC ripple |
| 1024 | low AC output voltage |
| 2048 | high AC output voltage |
| 4096 | short circuit |
| 8192 | BMS lockout |

OPEN QUESTION: `alarm_reason` looks like a bit field because the values are
powers of two and the PDF allows the full `0x0000..0xFFFF` range. The Python
reference models it as an enum, which only accepts exact listed values and not
combinations. A Swift parser should probably preserve raw flags and expose a
typed convenience layer, but this needs review against real packets.

OPEN QUESTION: The PDF marks Battery Monitor `battery_current` NA as raw
`0x3FFFFF`. The Python parser converts the 22-bit value to signed first and
then compares it with `0x3FFFFF`, which would not detect the all-ones NA value.
Use the official raw sentinel unless Python test vectors prove that behavior is
intentionally different.

OPEN QUESTION: The PDF does not define an explicit NA sentinel for
`aux_value`; mode `0x3` means no aux input. Treat `aux_value` as meaningful only
when `aux_mode` is 0, 1, or 2.

## iOS-Specific Constraints

- iOS does not expose the BLE MAC address through CoreBluetooth. Apple exposes
  `CBPeripheral.identifier`, a UUID assigned by the local system. It is suitable
  for matching a known peripheral on the same iOS device, but it is not a
  cross-device Victron identity.
- The user should enter the Victron advertisement key and a human name manually.
  During scanning, bind the observed `CBPeripheral.identifier` and Local Name to
  that configured device after the advertisement passes the Victron header and
  key-first-byte checks.
- The stable protocol identity in the advertisement is Product ID plus record
  type; it is not unique per physical device. The key itself is per device, but
  only byte 0 is visible before decryption.
- Foreground scanning can parse Manufacturer Data by looking for Company ID
  `0x02E1` and Victron payload byte 0 `0x10`.
- Background scanning requires the `bluetooth-central` background mode. Apple
  also requires background scans to specify one or more Service UUID filters.
  Victron Instant Readout data is carried in Manufacturer Data and the required
  sources do not define a Service UUID suitable for filtering these packets.
- Because no useful Victron Service UUID filter is available, background
  behavior must be treated as constrained/opportunistic. Use CoreBluetooth
  State Preservation and Restoration with a restoration identifier, cache the
  last decoded values, and design UI surfaces such as widgets around stale-data
  handling.
- In the background, iOS ignores duplicate-discovery scanning behavior and
  coalesces multiple discoveries of the same peripheral. If all scanning apps
  are in the background, scan intervals increase and updates can be delayed.
- Multiple apps can listen for BLE advertisements because receiving
  advertisements is passive. iOS may still schedule and coalesce delivery.
- VictronConnect can run in parallel with this app. Our app should only scan and
  never connect for Instant Readout, so it does not take over the device
  connection. Parse by Manufacturer Data contents, not by assumptions about the
  connectable advertising event type.

## Implementation Guardrails for Phase 2

- Do not parse advertisements whose Company Identifier is not `0x02E1`.
- Do not parse Victron manufacturer payloads whose byte 0 is not `0x10`.
- Accept variable ciphertext lengths. Do not require exactly 16 transmitted
  encrypted bytes.
- Check field availability by length before reading future extension fields.
  The PDF says record layouts are not changed, but may be extended.
- Preserve unknown Product IDs, unknown enum values, and raw alarm/error flags.
- Check raw sentinel values before signed conversion where the sentinel is an
  all-ones non-byte-width signed field.
