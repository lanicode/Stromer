# iOS BLE Scanner Architecture

Status: Phase 3.1 architecture documentation only. This document describes the
iOS scanner layer for Victron BLE Instant Readout. It intentionally does not
define UI, CoreBluetooth implementation code, or parser internals.

## Sources Read

- Apple Core Bluetooth background processing:
  https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html
- `CBCentralManager`:
  https://developer.apple.com/documentation/corebluetooth/cbcentralmanager
- `scanForPeripherals(withServices:options:)`:
  https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/scanforperipherals%28withservices%3Aoptions%3A%29
- `CBCentralManagerRestoredStatePeripheralsKey`:
  https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerrestoredstateperipheralskey
- Keychain Services:
  https://developer.apple.com/documentation/security/keychain-services
- Keychain access groups:
  https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
- Keychain accessibility:
  https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly
- Bluetooth usage description:
  https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription
- Local protocol notes: `docs/VICTRON_PROTOCOL.md`

## Goals and Non-Goals

Goals:

- Scan for Victron Instant Readout advertisements.
- Filter by Manufacturer Data company ID `0x02E1` and Victron payload byte
  `0x10`.
- Match advertisements to user-registered devices and their per-device keys.
- Decode data through the offline `VictronParser` package.
- Persist latest readings for app, widget, and Live Activity display.

Non-goals:

- Connecting to Victron devices.
- Discovering GATT services or characteristics.
- Writing to Victron devices.
- Implementing UI in the scanner layer.

## Scan Strategy

`CBCentralManager` is the central object for scanning, discovery, connection,
and peripheral management. The scanner should only start active scanning once
the central manager state is `poweredOn`.

Foreground behavior:

- Use a generic scan because Victron Instant Readout is carried in Manufacturer
  Data, not in a documented service advertisement.
- Pass no Service UUID filter in the foreground scan.
- Filter in `centralManager(_:didDiscover:advertisementData:rssi:)`.
- Accept duplicate discoveries in foreground so repeated advertisements update
  live readings.
- Apply an app-side debounce or "same payload" dedupe if UI churn or battery
  usage becomes excessive.

Background behavior:

- Apple documents that background scans require the `bluetooth-central`
  background mode.
- Apple also documents that background scanning must explicitly scan for one or
  more services by specifying Service UUIDs.
- Victron Instant Readout packets expose the useful data in Manufacturer Data;
  the required protocol sources do not define a Victron Service UUID suitable
  for this filter.
- Consequence: a fully reliable background scan for these packets is not
  guaranteed by CoreBluetooth. The app should treat background reception as
  opportunistic and design stale-data behavior accordingly.

Why no Service UUID filter is possible:

- The parser entry point needs Manufacturer Data with Company ID `0x02E1`.
- The Victron payload begins with record type `0x10`.
- Product ID, record type, nonce, key check byte, and ciphertext are all in
  Manufacturer Data.
- No primary source in the Phase 1 protocol notes identifies a service UUID that
  all relevant Victron Instant Readout devices advertise for this purpose.

Filtering rule in `didDiscover`:

1. Read Manufacturer Data.
2. If CoreBluetooth includes the company bytes, require `E1 02` at offset 0.
3. If company bytes are already stripped by an abstraction, use that payload
   only if the source has preserved the company ID separately.
4. Require Victron payload byte 0 to be `0x10`.
5. Pass raw advertisement bytes and RSSI to the registry/parser layer.

`CBCentralManagerScanOptionAllowDuplicatesKey`:

- Foreground: enable duplicates for live monitoring, then dedupe/throttle in the
  app if needed.
- Background: Apple states this option is ignored; multiple discoveries of the
  same advertising peripheral are coalesced into a single discovery event.
- Background update cadence must therefore not be treated as real-time.

OPEN QUESTION: Apple requires Service UUID filters for background scans, while
Victron Instant Readout exposes only Manufacturer Data in the required sources.
It is not clear from Apple or Victron docs whether any undocumented Service UUID
is present across all target devices. Do not hardcode one without empirical
captures from SmartShunt and MPPT devices.

## Background Behavior

Required app configuration:

- `UIBackgroundModes` includes `bluetooth-central`.
- `NSBluetoothAlwaysUsageDescription` is present and explains why the app scans
  for nearby Victron devices.
- The scanner `CBCentralManager` is initialized with
  `CBCentralManagerOptionRestoreIdentifierKey`.
- The app delegate / lifecycle path preserves the same restoration identifier
  across launches.

State preservation and restoration:

- CoreBluetooth can preserve selected central-manager state after the app is
  terminated by the system.
- For a central manager, Apple says preserved state includes scan services and
  scan options, peripherals being connected or already connected, and subscribed
  characteristics.
- On restoration, recreate the central manager with the same restore identifier.
- Implement `centralManager(_:willRestoreState:)`.
- Read restored peripherals from `CBCentralManagerRestoredStatePeripheralsKey`
  when present.
- For this app, restored peripherals are mostly useful for re-associating
  `CBPeripheral.identifier` values. The Instant Readout design should still
  avoid connecting.

Realistic update frequency:

- In foreground, updates can be frequent enough for live display, limited by
  Victron advertisement cadence and iOS scheduling.
- In background, Apple says duplicate discovery is coalesced.
- Apple also says if all scanning apps are in the background, the scan interval
  increases, so it may take longer to discover an advertising peripheral.
- Apps woken in the background should finish quickly; Apple gives roughly 10
  seconds as the expected window for background work before suspension pressure.
- Product behavior should be documented as "last known value" plus timestamp,
  not "continuous background telemetry".

OPEN QUESTION: Apple does not publish a deterministic background scan interval
or maximum delay for this scenario. Do not promise a fixed background refresh
rate in product copy or tests.

## Device Identity Model

iOS does not expose BLE MAC addresses through CoreBluetooth. The scanner must
not depend on MAC addresses.

Registration:

- User manually creates a device entry.
- Required fields: display name and 32-hex-character Victron advertisement key
  copied from VictronConnect.
- Optional fields after discovery: Product ID, record type, latest local name,
  latest `CBPeripheral.identifier`, and latest RSSI.

First discovery:

- The scanner receives `CBPeripheral.identifier`, advertisement data, local
  name when available, and RSSI.
- The registry tries every registered key whose product/type constraints still
  permit the packet.
- A key is a candidate when its first byte matches the advertisement key-check
  byte.
- The parser confirms the candidate by decrypting and parsing the record.
- On success, store `CBPeripheral.identifier.uuidString` and the latest local
  name on the registered device.

Follow-up discoveries:

- Primary match: `CBPeripheral.identifier` equals a stored identifier.
- Fallback match: Manufacturer Data passes the Victron header checks and exactly
  one registered key validates and parses the packet.
- If multiple registered keys share the same first byte, try parse/decrypt for
  each candidate and accept only an unambiguous parse.
- If no key matches, ignore the packet or expose it as "unclaimed Victron
  device" in a future UI flow.

iPhone change / reinstall:

- `CBPeripheral.identifier` is assigned by the local Apple device and is not a
  portable Victron identity.
- On a new iPhone, restored backup, or reinstall, the UUID may change.
- Because the key is copied from VictronConnect and is per Victron device, the
  app can re-bind the new local UUID after it sees a valid advertisement and
  successfully validates the key.
- If keys use `ThisDeviceOnly` Keychain accessibility, they do not migrate to a
  new iPhone. The user must re-enter keys after device migration.

OPEN QUESTION: Apple documents `CBPeripheral.identifier` as an identifier for a
peer, but does not guarantee that it is stable across all reinstall, backup, or
device-migration cases relevant here. Treat it as a local cache key, not as the
canonical device identity.

## Data Flow Architecture

```text
CBCentralManager
    |
    v didDiscover
ScannerService (filter: 0x02E1, byte 0 = 0x10)
    |
    v rawAdvertisement + RSSI
DeviceRegistry (key lookup per device)
    |
    v key
VictronParser.parse(...)
    |
    v VictronRecord
VictronStore (@Observable, latest reading per device)
    |
    v written to App Group UserDefaults / SwiftData
Widget / Live Activity (read-only)
```

Layer responsibilities:

- `CBCentralManager`: owns CoreBluetooth state and emits discovery callbacks.
- `ScannerService`: starts/stops scan sessions, applies cheap Victron header
  filters, normalizes manufacturer data shape, and forwards RSSI.
- `DeviceRegistry`: owns registered devices, local UUID bindings, and key lookup.
- `VictronParser`: offline parser and decryptor; no CoreBluetooth dependency.
- `VictronStore`: main app observable state, latest readings, stale flags, and
  persistence writes.
- Widget / Live Activity: read-only consumers of app group state; no scanning
  and no direct Bluetooth work.

## Persistence Layers

Keychain:

- Store Victron AES advertisement keys.
- One keychain item per registered device.
- Use `kSecClassGenericPassword`.
- Use a shared access group only if an extension truly needs key access. The
  planned architecture keeps widgets and Live Activities read-only from the
  latest-value store, so they should not normally read keys.

App Group UserDefaults:

- Recommended for Phase 3.2.
- Stores device metadata and latest readings as compact codable snapshots.
- Suitable for widget and Live Activity read-only access.
- Good fit for small state: device name, product ID, record type, latest value,
  latest timestamp, stale flag, latest local name, and latest UUID string.
- Lower operational complexity than SwiftData and easier extension sharing.

SwiftData:

- Consider later if the app stores history, charts, queryable samples, or richer
  relationships.
- Requires more schema and migration planning.
- Widget/extension access needs careful App Group container configuration.

Decision:

- Use Keychain for keys.
- Use App Group UserDefaults for Phase 3.2 metadata and latest readings.
- Revisit SwiftData when we add historical samples or charts that cannot be
  represented cleanly as latest-value snapshots.

## Keychain Strategy

Service identifier:

- `com.lanicode.strom.victron-advertisement-key`
- If the final bundle/app name changes, keep the service identifier stable after
  release to avoid orphaning existing keychain items.

Account:

- Use the registered device's stable app-level ID.
- Initial registration can create an app UUID before discovery.
- After discovery, also store `CBPeripheral.identifier.uuidString` in metadata,
  but do not make the keychain account depend solely on the CoreBluetooth UUID.
- If implementation chooses `account = Device-UUID-String`, define "Device UUID"
  as the app-generated registered-device UUID, not necessarily
  `CBPeripheral.identifier`.

Access group:

- Use an entitlement shared by the app and any extension that must read keys.
- Apple allows keychain items to belong to one access group via
  `kSecAttrAccessGroup`.
- App Groups can participate in keychain sharing on iOS; alternatively use the
  Keychain Sharing capability with a dedicated keychain group.
- Planned value once the app name is fixed:
  `group.com.lanicode.<APP_NAME>.shared`
- All targets that need access must have the matching entitlement, or Security
  calls fail with missing entitlement / item-not-found behavior.

Accessibility:

- Recommended: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Reason: Apple recommends this class for items that background apps need after
  the first unlock; `ThisDeviceOnly` prevents migration of Victron keys to a new
  device.
- Consequence: after iPhone migration or restore to a different device, users
  must re-enter Victron advertisement keys.

OPEN QUESTION: The final target set may not require Widget or Live Activity
extensions to read keys at all. If they remain read-only latest-value consumers,
do not grant them keychain access just for convenience.

## Edge Cases and Failure Modes

Bluetooth off:

- `CBCentralManager` state is not `poweredOn`.
- Stop or avoid scan attempts.
- Store scanner state as unavailable.
- Keep latest values visible with stale timestamps.
- UI should explain that Bluetooth is off, but the scanner layer only reports
  state.

Permission denied:

- CoreBluetooth authorization is denied or restricted.
- Do not scan.
- Keep registered devices and keys.
- Latest readings remain cached and become stale.
- App should provide a settings-oriented recovery path outside the scanner
  layer.

Registered device silent for 24h+:

- Mark the device stale based on `lastSeenAt`.
- Keep last value and timestamp.
- Do not delete keys or metadata automatically.
- Suggested stale levels:
  - `fresh`: seen recently.
  - `delayed`: not seen within expected foreground/background window.
  - `stale`: not seen for 24 hours.
  - `missing`: not seen for multiple days, still user-owned.

Multiple devices advertising simultaneously:

- Expected case: MPPT and SmartShunt both send advertisements.
- No conflict is expected because each packet carries product ID, record type,
  key-check byte, nonce, and encrypted payload.
- Registry matching should be per packet.
- If key-check first bytes collide, parser validation should disambiguate or
  reject ambiguous matches.

VictronConnect running in parallel:

- This app only scans advertisements and does not connect.
- BLE advertisement reception is passive.
- VictronConnect can connect or scan independently.
- iOS may still schedule scan callbacks and radio usage, but there is no
  protocol-level conflict because no GATT session is opened by this app.

Wrong key:

- If the first key byte does not match the advertisement key-check byte, skip
  the key without attempting decryption.
- If first byte matches but parsing fails, treat it as no match for that device.
- Repeated wrong-key events should surface as a device configuration problem,
  not as a scanner crash.

Local name missing:

- Local Name may be absent in advertisements.
- Use Local Name only as display metadata and secondary evidence.
- Never require it for parser correctness.

Clock changes:

- Store both wall-clock timestamp for display and monotonic recency if the
  implementation needs robust stale calculations during app runtime.
- Widgets can use wall-clock `lastSeenAt` for user-visible freshness.

## Open Questions

OPEN QUESTION: Is there a stable Victron Service UUID present in advertisements
for all target SmartShunt/BMV and SmartSolar/BlueSolar MPPT devices? The
required Victron protocol sources only document Manufacturer Data.

OPEN QUESTION: Can a generic foreground scan without Service UUID filter deliver
useful background wakeups on any current iOS versions despite Apple's documented
Service UUID requirement? Treat this as unsupported until measured on real
devices.

OPEN QUESTION: What background discovery latency should we expect for Victron
advertisements in realistic installations? Apple documents coalescing and
increased intervals, but not a fixed cadence.

OPEN QUESTION: Should keychain sharing be granted to Widget/Live Activity
targets, or should only the app target access keys while extensions read
decrypted latest-value snapshots? Prefer the latter unless Phase 3.2 proves a
need.
