import StromerScanner
import SwiftUI

struct DeviceDetailView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(VictronStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let deviceID: UUID

    @State private var isConfirmingDelete = false

    var body: some View {
        if let device = appModel.device(id: deviceID) {
            let reading = store.reading(for: deviceID)
            let primary = DevicePresentation.primaryValue(for: reading, device: device)
            let freshness = DevicePresentation.freshness(for: device, reading: reading)

            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(
                            DevicePresentation.deviceKindTitle(for: device, reading: reading),
                            systemImage: DevicePresentation.systemImage(for: device, reading: reading)
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(primary.value)
                                .font(.system(size: 44, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                            if let unit = primary.unit {
                                Text(unit)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            FreshnessBadge(freshness: freshness)
                            Text("Letzte Aktualisierung: \(DevicePresentation.relativeTime(reading?.timestamp ?? device.lastSeenAt))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                liveDataSection(reading: reading)

                Section("Gerät") {
                    LabeledContent("Name", value: device.name)
                    LabeledContent("Modell", value: reading?.modelName ?? "Noch unbekannt")
                    LabeledContent("Local Name", value: device.localName ?? "Nicht empfangen")
                    LabeledContent("Product ID", value: productIDText(reading: reading, device: device))
                    LabeledContent("RSSI", value: rssiText(reading: reading, device: device))
                    LabeledContent("CBPeripheral UUID", value: device.peripheralID?.uuidString ?? "Noch nicht gebunden")
                }

                Section {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Gerät löschen", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Gerät löschen?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Gerät löschen", role: .destructive) {
                    appModel.deleteDevice(id: deviceID)
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Der gespeicherte Advertisement Key wird aus dem Keychain entfernt.")
            }
        } else {
            ContentUnavailableView(
                "Gerät nicht gefunden",
                systemImage: "questionmark.circle",
                description: Text("Dieses Gerät ist nicht mehr registriert.")
            )
        }
    }

    @ViewBuilder
    private func liveDataSection(reading: DeviceReading?) -> some View {
        Section("Live-Daten") {
            if let reading {
                switch reading.payload {
                case let .batteryMonitor(payload):
                    batteryRows(payload)
                case let .solarCharger(payload):
                    solarRows(payload)
                }
            } else {
                ContentUnavailableView(
                    "Noch keine Live-Daten",
                    systemImage: "wave.3.right",
                    description: Text("Sobald ein passendes Advertisement empfangen wird, erscheinen hier die Werte.")
                )
            }
        }
    }

    @ViewBuilder
    private func batteryRows(_ payload: BatteryMonitorReading) -> some View {
        ValueRow(
            label: "SoC",
            value: payload.soc.map { DevicePresentation.number($0, digits: 1) } ?? "—",
            unit: "%",
            systemImage: "gauge.with.dots.needle.67percent"
        )
        ValueRow(
            label: "Spannung",
            value: payload.batteryVoltage.map { DevicePresentation.number($0, digits: 2) } ?? "—",
            unit: "V",
            systemImage: "bolt"
        )
        ValueRow(
            label: "Strom",
            value: payload.batteryCurrent.map { DevicePresentation.number($0, digits: 2) } ?? "—",
            unit: "A",
            systemImage: "alternatingcurrent"
        )
        ValueRow(
            label: "Verbraucht",
            value: payload.consumedAh.map { DevicePresentation.number($0, digits: 1) } ?? "—",
            unit: "Ah",
            systemImage: "minus.circle"
        )
        ValueRow(
            label: "Restzeit",
            value: payload.timeToGoMinutes.map { "\($0)" } ?? "—",
            unit: "Min.",
            systemImage: "clock"
        )
        LabeledContent("Aux-Modus", value: DevicePresentation.auxModeTitle(rawValue: payload.auxModeRaw))
        auxRows(payload)
        alarmBadges(rawValue: payload.alarmReasonRaw)
    }

    @ViewBuilder
    private func auxRows(_ payload: BatteryMonitorReading) -> some View {
        if let voltage = payload.starterVoltage {
            ValueRow(
                label: "Starter",
                value: DevicePresentation.number(voltage, digits: 2),
                unit: "V",
                systemImage: "battery.100"
            )
        }
        if let voltage = payload.midpointVoltage {
            ValueRow(
                label: "Mittelpunkt",
                value: DevicePresentation.number(voltage, digits: 2),
                unit: "V",
                systemImage: "point.3.connected.trianglepath.dotted"
            )
        }
        if let temperature = payload.temperatureCelsius {
            ValueRow(
                label: "Temperatur",
                value: DevicePresentation.number(temperature, digits: 1),
                unit: "°C",
                systemImage: "thermometer.medium"
            )
        }
    }

    @ViewBuilder
    private func alarmBadges(rawValue: UInt16) -> some View {
        let labels = DevicePresentation.alarmLabels(rawValue: rawValue)

        VStack(alignment: .leading, spacing: 8) {
            Text("Alarme")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if labels.isEmpty {
                Text("Keine Alarme")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .foregroundStyle(.green)
                    .background(Capsule().fill(Color.green.opacity(0.14)))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(labels, id: \.self) { label in
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .foregroundStyle(.red)
                                .background(Capsule().fill(Color.red.opacity(0.14)))
                        }
                    }
                }
            }

            Text(DevicePresentation.hex(rawValue))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func solarRows(_ payload: SolarChargerReading) -> some View {
        LabeledContent("Ladezustand", value: DevicePresentation.chargerStateTitle(payload.deviceStateRaw))
        LabeledContent(
            "Charger Error",
            value: payload.chargerErrorCode.map { "\($0)" } ?? "Nicht verfügbar"
        )
        ValueRow(
            label: "Batteriespannung",
            value: payload.batteryVoltage.map { DevicePresentation.number($0, digits: 2) } ?? "—",
            unit: "V",
            systemImage: "bolt"
        )
        ValueRow(
            label: "Batteriestrom",
            value: payload.batteryCurrent.map { DevicePresentation.number($0, digits: 2) } ?? "—",
            unit: "A",
            systemImage: "alternatingcurrent"
        )
        ValueRow(
            label: "Ertrag heute",
            value: payload.yieldTodayWh.map { DevicePresentation.number($0, digits: 0) } ?? "—",
            unit: "Wh",
            systemImage: "chart.bar"
        )
        ValueRow(
            label: "PV-Leistung",
            value: payload.pvPower.map { "\($0)" } ?? "—",
            unit: "W",
            systemImage: "sun.max"
        )
        ValueRow(
            label: "Load-Strom",
            value: payload.loadCurrent.map { DevicePresentation.number($0, digits: 2) } ?? "—",
            unit: "A",
            systemImage: "powerplug"
        )
    }

    private func productIDText(reading: DeviceReading?, device: RegisteredDevice) -> String {
        let productID = reading?.productID ?? device.productID
        guard let productID else {
            return "Noch unbekannt"
        }
        return DevicePresentation.hex(productID)
    }

    private func rssiText(reading: DeviceReading?, device: RegisteredDevice) -> String {
        let rssi = reading?.rssi ?? device.lastRSSI
        guard let rssi else {
            return "Noch nicht empfangen"
        }
        return "\(rssi) dBm"
    }
}
