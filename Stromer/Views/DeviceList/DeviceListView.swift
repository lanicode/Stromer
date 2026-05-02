import StromerScanner
import SwiftUI

struct DeviceListView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(VictronStore.self) private var store
    @State private var isShowingAddDevice = false
    @State private var isShowingSettings = false
    @State private var refreshFeedback = false

    var body: some View {
        ZStack {
            BoltBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if appModel.registeredDevices.isEmpty {
                        EmptyDeviceListView {
                            isShowingAddDevice = true
                        }
                    } else {
                        if let hero = aggregateHero {
                            DeviceListHeroView(hero: hero)
                                .padding(.horizontal, 18)
                        }

                        devicesSection

                        addDeviceButton

                        footer
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .refreshable {
                await appModel.restartScanner()
                refreshFeedback.toggle()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: UUID.self) { deviceID in
            DeviceDetailView(deviceID: deviceID)
        }
        .sheet(isPresented: $isShowingAddDevice) {
            NavigationStack {
                AddDeviceView()
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: refreshFeedback)
    }

    private var header: some View {
        HStack(spacing: 10) {
            BoltSLockup(size: 30)

            Text("STROMER")
                .font(.system(size: 11, weight: .bold))
                .tracking(3.2)
                .foregroundStyle(Color.boltInk)

            Spacer()

            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.boltTeal)
                    .frame(width: 30, height: 30)
                    .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Einstellungen")

            if hasFreshDevice {
                HStack(spacing: 6) {
                    BoltGlyph(size: 11)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.4)
                }
                .foregroundStyle(Color.boltTeal)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(Rectangle().stroke(Color.boltTeal, lineWidth: 1))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                BoltEyebrow("Geräte")

                Spacer()

                Text(scannerStatusText)
                    .font(.boltMono(11))
                    .tracking(0.4)
                    .foregroundStyle(Color.boltInkSoft)
            }
            .padding(.horizontal, 18)

            VStack(spacing: 10) {
                ForEach(appModel.registeredDevices) { device in
                    NavigationLink(value: device.id) {
                        DeviceRowView(
                            device: device,
                            reading: store.reading(for: device.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var addDeviceButton: some View {
        Button {
            isShowingAddDevice = true
        } label: {
            Text("+ GERÄT HINZUFÜGEN")
                .font(.system(size: 14, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.boltTeal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    DashedBorder(color: .boltTeal, lineWidth: 1.5, dash: [6, 5])
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.boltTeal)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .padding(.top, 4)

            Text("Passive Bluetooth-Advertisements. Werte bleiben auf diesem iPhone.")
                .font(.system(size: 11).italic())
                .foregroundStyle(Color.boltInkSoft)
        }
        .padding(.horizontal, 24)
    }

    private var hasFreshDevice: Bool {
        appModel.registeredDevices.contains { device in
            DevicePresentation.freshness(
                for: device,
                reading: store.reading(for: device.id)
            ) == .fresh
        }
    }

    private var scannerStatusText: String {
        switch appModel.scannerState {
        case .scanning:
            return "BLE · SCANNER AKTIV"
        case .idle:
            return "BLE · SCANNER PAUSIERT"
        case .off:
            return "BLE · AUS"
        case .unauthorized:
            return "BLE · NICHT ERLAUBT"
        case .unsupported:
            return "BLE · NICHT VERFÜGBAR"
        case .resetting:
            return "BLE · STARTET NEU"
        case .failed:
            return "BLE · FEHLER"
        case .unknown:
            return "BLE · UNBEKANNT"
        }
    }

    private var aggregateHero: DeviceListHero? {
        let batteryDevices = appModel.registeredDevices.filter { $0.recordType == 0x02 }
        guard !batteryDevices.isEmpty else {
            return nil
        }

        let socValues = batteryDevices.compactMap { device -> Double? in
            guard case let .batteryMonitor(payload) = store.reading(for: device.id)?.payload else {
                return nil
            }
            return payload.soc
        }
        let averageSoc = socValues.isEmpty
            ? nil
            : socValues.reduce(0, +) / Double(socValues.count)

        let totalPV = appModel.registeredDevices.reduce(0) { partialResult, device in
            guard case let .solarCharger(payload) = store.reading(for: device.id)?.payload,
                  let pvPower = payload.pvPower else {
                return partialResult
            }
            return partialResult + pvPower
        }

        return DeviceListHero(
            deviceCount: appModel.registeredDevices.count,
            averageSoc: averageSoc,
            totalPVWatts: totalPV > 0 ? totalPV : nil
        )
    }
}

private struct DeviceListHero {
    let deviceCount: Int
    let averageSoc: Double?
    let totalPVWatts: Int?
}

private struct DeviceListHeroView: View {
    let hero: DeviceListHero

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BoltEyebrow("Gesamtladung · \(hero.deviceCount) Geräte")

            HStack(alignment: .bottom) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(socText)
                        .font(.system(size: 86, weight: .heavy))
                        .monospacedDigit()
                        .tracking(0)
                        .foregroundStyle(Color.boltInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("%")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(Color.boltTeal)
                }

                Spacer(minLength: 12)

                if let totalPVWatts = hero.totalPVWatts {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(totalPVWatts)")
                            .font(.system(size: 26, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Color.boltInk)
                        BoltEyebrow("Solar jetzt")
                    }
                }
            }

            HorizonLine(percent: hero.averageSoc ?? 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
    }

    private var socText: String {
        guard let averageSoc = hero.averageSoc else {
            return "--"
        }
        return DevicePresentation.number(averageSoc, digits: 0)
    }
}

private struct HorizonLine: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.boltInk)
                    .frame(height: 2)

                BoltGlyph(size: 12)
                    .offset(x: markerX(width: geo.size.width), y: -8)
            }
        }
        .frame(height: 18)
    }

    private func markerX(width: CGFloat) -> CGFloat {
        let clamped = min(max(percent, 0), 100) / 100
        return max(0, min(width - 12, width * clamped - 6))
    }
}

private struct DashedBorder: View {
    let color: Color
    let lineWidth: CGFloat
    let dash: [CGFloat]

    var body: some View {
        Rectangle()
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, dash: dash)
            )
    }
}
