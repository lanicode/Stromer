import StromerScanner
import SwiftUI
import VictronParser

struct DeviceDetailView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(VictronStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let deviceID: UUID

    @State private var isConfirmingDelete = false
    @State private var isShowingDeviceInfo = false
    @State private var liveActivityNotice: LiveActivityNotice?

    var body: some View {
        if let device = appModel.device(id: deviceID) {
            let reading = store.reading(for: deviceID)
            let freshness = DevicePresentation.freshness(for: device, reading: reading)

            ZStack {
                BoltBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        navBar
                        titleBlock(device: device, reading: reading)

                        if let reading {
                            DetailHeroSlab(
                                primary: DevicePresentation.primaryValue(for: reading, device: device),
                                freshness: freshness,
                                timestamp: reading.timestamp,
                                rssi: reading.rssi,
                                spectrumPercent: spectrumPercent(for: reading),
                                statusText: statusText(for: reading)
                            )
                            .padding(.horizontal, 18)

                            DetailStatGrid(stats: stats(for: reading))
                                .padding(.horizontal, 18)

                            supplementalSections(for: reading)
                        } else {
                            missingReadingContent(device: device)
                                .padding(.horizontal, 18)
                        }

                        actions(reading: reading)
                            .padding(.horizontal, 18)

                        footerMeta(device: device, reading: reading)
                            .padding(.horizontal, 18)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
            .sheet(isPresented: $isShowingDeviceInfo) {
                DeviceInfoSheet(
                    device: device,
                    reading: reading,
                    productIDText: productIDText(reading: reading, device: device),
                    rssiText: rssiText(reading: reading, device: device)
                )
            }
            .sheet(item: $liveActivityNotice) { notice in
                LiveActivityNoticeSheet(notice: notice)
            }
        } else {
            ZStack {
                BoltBackground()
                StromerEmptyStateView(
                    iconSystemName: "questionmark.circle",
                    title: "Gerät nicht gefunden",
                    description: "Dieses Gerät ist nicht mehr registriert."
                )
                .padding(18)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var navBar: some View {
        HStack {
            Button("< ZURÜCK") {
                dismiss()
            }
            .font(.system(size: 12, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(Color.boltTeal)
            .buttonStyle(.plain)

            Spacer()

            BoltSLockup(size: 20)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func titleBlock(device: RegisteredDevice, reading: DeviceReading?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BoltEyebrow("\(DevicePresentation.deviceKindTitle(for: device, reading: reading)) · \(reading?.modelName ?? modelFallback(for: device))")

            Text(device.name)
                .font(.system(size: 30, weight: .heavy))
                .tracking(0)
                .foregroundStyle(Color.boltInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func missingReadingContent(device: RegisteredDevice) -> some View {
        if supportStatus(for: device) == .plannedPhase37 {
            StromerEmptyStateView(
                iconSystemName: "clock.arrow.circlepath",
                title: "Decoding folgt",
                description: "Dieses Gerät ist registriert. Live-Werte erscheinen nach einem späteren Decoder-Update."
            )
        } else {
            StromerEmptyStateView(
                iconSystemName: "wave.3.right",
                title: "Noch keine Live-Daten",
                description: "Sobald Stromer ein passendes Advertisement empfängt, erscheinen hier die Werte.",
                action: .init(label: "Scanner neu starten") {
                    Task {
                        await appModel.restartScanner()
                    }
                }
            )
        }
    }

    private func actions(reading: DeviceReading?) -> some View {
        VStack(spacing: 12) {
            if let reading {
                let isActive = appModel.isLiveActivityActive(for: deviceID)

                BoltPrimary(
                    isActive ? "Live-Anzeige beenden" : "Live-Anzeige starten",
                    showsBolt: !isActive
                ) {
                    Task {
                        if isActive {
                            await appModel.endLiveActivity(for: deviceID)
                        } else {
                            do {
                                try await appModel.startLiveActivity(for: deviceID)
                            } catch {
                                liveActivityNotice = LiveActivityNotice(
                                    title: "Live-Anzeige nicht verfügbar",
                                    message: error.localizedDescription
                                )
                            }
                        }
                    }
                }

                Text("Aktualisiert wird lokal, wenn Stromer im Vordergrund neue Werte empfängt. Im Hintergrund bleibt die letzte Live-Anzeige sichtbar. Letzter Stand: \(DevicePresentation.relativeTime(reading.timestamp)).")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.boltInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                StromerEmptyStateView(
                    iconSystemName: "rectangle.on.rectangle.slash",
                    title: "Noch kein Live-Wert",
                    description: "Die Live-Anzeige kann gestartet werden, sobald ein erstes Advertisement empfangen wurde."
                )
            }

            BoltSecondary("Geräteinfo") {
                isShowingDeviceInfo = true
            }

            Button {
                isConfirmingDelete = true
            } label: {
                Text("GERÄT LÖSCHEN")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.boltBad)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .overlay(Rectangle().stroke(Color.boltBad.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func footerMeta(device: RegisteredDevice, reading: DeviceReading?) -> some View {
        HStack(alignment: .top) {
            Text(reading?.localName ?? device.localName ?? "Local Name unbekannt")
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(shortPeripheralID(device.peripheralID ?? reading?.peripheralID))
                .lineLimit(1)
        }
        .font(.boltMono(10))
        .foregroundStyle(Color.boltInkFaint)
    }

    @ViewBuilder
    private func supplementalSections(for reading: DeviceReading) -> some View {
        switch reading.payload {
        case let .batteryMonitor(payload):
            BoltSection(header: "Batterie Details") {
                VStack(spacing: 0) {
                    BoltDetailRow(title: "Aux-Modus", value: DevicePresentation.auxModeTitle(rawValue: payload.auxModeRaw))
                    if let starter = payload.starterVoltage {
                        BoltDetailRow(title: "Starter", value: "\(DevicePresentation.number(starter, digits: 2)) V")
                    }
                    if let midpoint = payload.midpointVoltage {
                        BoltDetailRow(title: "Mittelpunkt", value: "\(DevicePresentation.number(midpoint, digits: 2)) V")
                    }
                    AlarmDetailRows(rawValue: payload.alarmReasonRaw)
                }
            }
            .padding(.horizontal, 18)
        case let .dcDcConverter(payload):
            BoltSection(header: "Live-Daten") {
                VStack(spacing: 0) {
                    BoltDetailRow(title: "Ladezustand", value: DevicePresentation.chargerStateTitle(payload.chargeStateRaw))
                    BoltDetailRow(
                        title: "Charger Error",
                        value: payload.chargerErrorCode.map { "\($0)" } ?? "Kein Fehler"
                    )
                    BoltDetailRow(
                        title: "Eingangsspannung",
                        value: payload.inputVoltage.map { "\(DevicePresentation.number($0, digits: 2)) V" } ?? "--"
                    )
                    BoltDetailRow(
                        title: "Ausgangsspannung",
                        value: payload.outputVoltage.map { "\(DevicePresentation.number($0, digits: 2)) V" } ?? "--"
                    )
                    BoltDetailRow(
                        title: "Aus-Grund",
                        value: DevicePresentation.dcDcOffReasonTitle(rawValue: payload.offReasonRaw)
                    )
                    if DcDcOffReason(rawValue: payload.offReasonRaw).knownName == nil {
                        BoltDetailRow(title: "Off Reason Raw", value: DevicePresentation.hex(payload.offReasonRaw), isMono: true)
                    }
                }
            }
            .padding(.horizontal, 18)
        case .solarCharger:
            EmptyView()
        }
    }

    private func stats(for reading: DeviceReading) -> [DetailStat] {
        switch reading.payload {
        case let .batteryMonitor(payload):
            return [
                DetailStat("Spannung", payload.batteryVoltage.map { DevicePresentation.number($0, digits: 2) } ?? "--", "V"),
                DetailStat("Strom", payload.batteryCurrent.map { DevicePresentation.number($0, digits: 2) } ?? "--", "A"),
                DetailStat("Verbraucht", payload.consumedAh.map { DevicePresentation.number($0, digits: 1) } ?? "--", "Ah"),
                DetailStat("Restzeit", formatMinutes(payload.timeToGoMinutes), nil),
                DetailStat("Temperatur", payload.temperatureCelsius.map { DevicePresentation.number($0, digits: 1) } ?? "--", "°C"),
                DetailStat("Status", batteryStatus(payload), nil)
            ]
        case let .solarCharger(payload):
            return [
                DetailStat("Bat. Spg", payload.batteryVoltage.map { DevicePresentation.number($0, digits: 2) } ?? "--", "V"),
                DetailStat("Bat. Strom", payload.batteryCurrent.map { DevicePresentation.number($0, digits: 2) } ?? "--", "A"),
                DetailStat("Ertrag", payload.yieldTodayWh.map { DevicePresentation.number($0, digits: 0) } ?? "--", "Wh"),
                DetailStat("Load", payload.loadCurrent.map { DevicePresentation.number($0, digits: 2) } ?? "--", "A"),
                DetailStat("Status", DevicePresentation.chargerStateTitle(payload.deviceStateRaw), nil),
                DetailStat("Modus", "MPPT", nil)
            ]
        case let .dcDcConverter(payload):
            return [
                DetailStat("Eingang", payload.inputVoltage.map { DevicePresentation.number($0, digits: 2) } ?? "--", "V"),
                DetailStat("Ausgang", payload.outputVoltage.map { DevicePresentation.number($0, digits: 2) } ?? "--", "V"),
                DetailStat("Ladezustand", DevicePresentation.chargerStateTitle(payload.chargeStateRaw), nil),
                DetailStat("Charger Error", payload.chargerErrorCode.map { "\($0)" } ?? "Kein Fehler", nil),
                DetailStat("Aus-Grund", DevicePresentation.dcDcOffReasonTitle(rawValue: payload.offReasonRaw), nil),
                DetailStat("Off Raw", DcDcOffReason(rawValue: payload.offReasonRaw).knownName == nil ? DevicePresentation.hex(payload.offReasonRaw) : "--", nil)
            ]
        }
    }

    private func spectrumPercent(for reading: DeviceReading) -> Double? {
        switch reading.payload {
        case let .batteryMonitor(payload):
            return payload.soc
        case let .solarCharger(payload):
            guard let pvPower = payload.pvPower else {
                return nil
            }
            return min(Double(pvPower) / 1000 * 100, 100)
        case .dcDcConverter:
            return nil
        }
    }

    private func statusText(for reading: DeviceReading) -> String? {
        switch reading.payload {
        case let .dcDcConverter(payload):
            return DevicePresentation.chargerStateTitle(payload.chargeStateRaw).uppercased()
        default:
            return nil
        }
    }

    private func batteryStatus(_ payload: BatteryMonitorReading) -> String {
        guard let current = payload.batteryCurrent else {
            return "Neutral"
        }
        if current > 0.05 {
            return "Lädt"
        }
        if current < -0.05 {
            return "Entlädt"
        }
        return "Neutral"
    }

    private func formatMinutes(_ minutes: Int?) -> String {
        guard let minutes else {
            return "--"
        }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return "\(hours)h \(rest)m"
        }
        return "\(rest)m"
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

    private func supportStatus(for device: RegisteredDevice) -> DiscoverySupportStatus {
        if let productID = device.productID, let recordType = device.recordType {
            return VictronProductCatalog.supportStatus(
                productID: productID,
                recordType: recordType
            )
        }

        if let recordType = device.recordType {
            return VictronProductCatalog.supportStatus(
                productID: 0,
                recordType: recordType
            )
        }

        if let productID = device.productID {
            return VictronProductCatalog.lookup(productID: productID)?.supportStatus ?? .supported
        }

        return .supported
    }

    private func modelFallback(for device: RegisteredDevice) -> String {
        if let productID = device.productID,
           let entry = VictronProductCatalog.lookup(productID: productID) {
            return entry.modelName
        }
        return "Noch unbekannt"
    }

    private func shortPeripheralID(_ id: UUID?) -> String {
        guard let id else {
            return "UUID offen"
        }
        let text = id.uuidString
        return "\(text.prefix(4))-...-\(text.suffix(4))"
    }
}

private struct DetailHeroSlab: View {
    let primary: PrimaryReadingValue
    let freshness: DeviceFreshness
    let timestamp: Date
    let rssi: Int
    let spectrumPercent: Double?
    let statusText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 8) {
                Text(primary.value)
                    .font(.system(size: displaySize, weight: .heavy))
                    .tracking(0)
                    .monospacedDigit()
                    .foregroundStyle(Color.boltInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                if let unit = primary.unit, !unit.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(unit)
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(Color.boltTeal)
                        BoltEyebrow(primary.label)
                    }
                    .padding(.bottom, 10)
                } else {
                    BoltEyebrow(primary.label)
                        .padding(.bottom, 13)
                }
            }

            if let spectrumPercent {
                DetailSpectrum(percent: spectrumPercent)
            } else if let statusText {
                Text(statusText)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.boltTealDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(Rectangle().stroke(Color.boltTeal, lineWidth: 1))
            }

            HStack {
                Rectangle()
                    .fill(freshness.boltColor)
                    .frame(width: 6, height: 6)

                Text("LIVE · \(DevicePresentation.relativeTime(timestamp).uppercased())")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.boltInkSoft)

                Spacer()

                Text("RSSI \(rssi) DBM")
                    .font(.boltMono(10))
                    .foregroundStyle(Color.boltInkSoft)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
        .boltCornerNotch(size: 28)
    }

    private var displaySize: CGFloat {
        primary.value.count > 5 ? 78 : 102
    }
}

private struct DetailSpectrum: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.boltHair)
                    .frame(height: 2)

                Rectangle()
                    .fill(Color.boltTeal)
                    .frame(width: fillWidth(total: geo.size.width), height: 2)

                HStack(spacing: 0) {
                    ForEach(0...10, id: \.self) { index in
                        Rectangle()
                            .fill(Color.boltInkSoft)
                            .frame(width: 1, height: index == 0 || index == 5 || index == 10 ? 14 : 9)
                        if index < 10 {
                            Spacer()
                        }
                    }
                }

                BoltGlyph(size: 12)
                    .offset(x: max(0, min(geo.size.width - 12, fillWidth(total: geo.size.width) - 6)), y: -9)
            }
        }
        .frame(height: 20)
    }

    private func fillWidth(total: CGFloat) -> CGFloat {
        total * min(max(percent, 0), 100) / 100
    }
}

private struct DetailStat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let unit: String?

    init(_ label: String, _ value: String, _ unit: String?) {
        self.label = label
        self.value = value
        self.unit = unit
    }
}

private struct DetailStatGrid: View {
    let stats: [DetailStat]
    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                DetailStatCell(stat: stat)
                    .overlay(alignment: .trailing) {
                        if index.isMultiple(of: 2) {
                            Rectangle()
                                .fill(Color.boltHair2)
                                .frame(width: 1)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if index < stats.count - 2 {
                            Rectangle()
                                .fill(Color.boltHair2)
                                .frame(height: 1)
                        }
                    }
            }
        }
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
    }
}

private struct DetailStatCell: View {
    let stat: DetailStat

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            BoltEyebrow(stat.label)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(stat.value)
                    .font(.system(size: 22, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color.boltInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                if let unit = stat.unit {
                    Text(unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.boltInkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

private struct BoltDetailRow: View {
    let title: String
    let value: String
    var isMono = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.boltInk)

            Spacer()

            Text(value)
                .font(isMono ? .boltMono(12) : .system(size: 13, weight: .semibold))
                .foregroundStyle(Color.boltInkSoft)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.boltHair2)
                .frame(height: 1)
        }
    }
}

private struct AlarmDetailRows: View {
    let rawValue: UInt16

    var body: some View {
        let labels = DevicePresentation.alarmLabels(rawValue: rawValue)

        VStack(alignment: .leading, spacing: 10) {
            BoltEyebrow("Alarme")

            if labels.isEmpty {
                Text("Keine Alarme")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Color.boltOk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .overlay(Rectangle().stroke(Color.boltOk.opacity(0.5), lineWidth: 1))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(labels, id: \.self) { label in
                            Text(label.uppercased())
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.8)
                                .foregroundStyle(Color.boltBad)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .overlay(Rectangle().stroke(Color.boltBad.opacity(0.55), lineWidth: 1))
                        }
                    }
                }
            }

            Text(DevicePresentation.hex(rawValue))
                .font(.boltMono(11))
                .foregroundStyle(Color.boltInkSoft)
        }
        .padding(14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.boltHair2)
                .frame(height: 1)
        }
    }
}

private struct DeviceInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let device: RegisteredDevice
    let reading: DeviceReading?
    let productIDText: String
    let rssiText: String

    var body: some View {
        NavigationStack {
            ZStack {
                BoltBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        BoltSection(header: "Gerät") {
                            VStack(spacing: 0) {
                                BoltDetailRow(title: "Name", value: device.name)
                                BoltDetailRow(title: "Modell", value: reading?.modelName ?? "Noch unbekannt")
                                BoltDetailRow(title: "Local Name", value: device.localName ?? "Nicht empfangen")
                                BoltDetailRow(title: "Product ID", value: productIDText, isMono: true)
                                BoltDetailRow(title: "RSSI", value: rssiText, isMono: true)
                                BoltDetailRow(
                                    title: "CBPeripheral UUID",
                                    value: device.peripheralID?.uuidString ?? "Noch nicht gebunden",
                                    isMono: true
                                )
                                BoltDetailRow(title: "Advertisement Key", value: "Im Schlüsselbund")
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Geräteinfo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct LiveActivityNoticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let notice: LiveActivityNotice

    var body: some View {
        NavigationStack {
            ZStack {
                BoltBackground()

                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "rectangle.on.rectangle.slash")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.boltInkSoft)

                    Text(notice.title)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(Color.boltInk)

                    Text(notice.message)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.boltInkSoft)

                    Spacer()

                    BoltPrimary("Fertig") {
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }
}

private struct LiveActivityNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
