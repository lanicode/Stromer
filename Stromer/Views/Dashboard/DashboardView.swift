import SwiftUI

struct DashboardView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @State private var isShowingSettings = false
    let openDevices: () -> Void

    init(openDevices: @escaping () -> Void = {}) {
        self.openDevices = openDevices
    }

    var body: some View {
        let viewModel = appModel.dashboardViewModel

        ZStack {
            BoltBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if !viewModel.hasDevices {
                        emptyState
                    } else {
                        LiveBalanceSection(
                            solarIn: viewModel.currentSolarIn,
                            loadOut: viewModel.currentLoadOut,
                            net: viewModel.currentNet,
                            connectionStatus: dashboardConnectionStatus,
                            dimsValues: dashboardValuesAreDimmed
                        )
                        .padding(.horizontal, 18)

                        if !viewModel.hasSolarDevice {
                            solarHint
                                .padding(.horizontal, 18)
                        }

                        TodayStatsSection(
                            solarYield: viewModel.todaySolarYield,
                            consumption: viewModel.todayConsumption,
                            socMin: viewModel.todaySocMin,
                            socMax: viewModel.todaySocMax,
                            fullCharges: viewModel.todayFullCharges
                        )
                        .padding(.horizontal, 18)

                        InsightsSection(insights: viewModel.insights)
                            .padding(.horizontal, 18)

                        TrendChartSection(
                            points: viewModel.last7DaysYield,
                            bestDayLabel: viewModel.bestDayLabel,
                            bestDayYield: viewModel.bestDayYield
                        )
                        .padding(.horizontal, 18)

                        BoltSecondary("Geräte öffnen", action: openDevices)
                            .padding(.horizontal, 18)
                    }

                    liveModeDebugControl
                        .padding(.horizontal, 18)
                }
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.refresh()
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                BoltEyebrow("Dashboard")
                Text("Live-Bilanz")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(0)
                    .foregroundStyle(Color.boltInk)
            }

            Spacer()

            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.boltTeal)
                    .frame(width: 34, height: 34)
                    .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Einstellungen")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            BoltGlyph(size: 58, strokeWidth: 2)
                .frame(maxWidth: .infinity)

            BoltEyebrow("Noch keine Bilanz", color: .boltTealDeep)
            Text("Füge ein Gerät hinzu,\num deine Energie zu sehen.")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Color.boltInk)
                .lineSpacing(0)

            Text("Dashboard und Verlauf starten, sobald Stromer erste Victron-Advertisements empfängt.")
                .font(.system(size: 15))
                .foregroundStyle(Color.boltInkSoft)

            BoltPrimary("Zum Geräte-Tab", showsBolt: true, action: openDevices)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
        .padding(.horizontal, 18)
    }

    private var solarHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.boltYellow)
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(45))
                .padding(.top, 5)

            Text("Solar-Daten sind nicht verfügbar. Füge einen MPPT hinzu, um die volle Energie-Bilanz zu sehen.")
                .font(.system(size: 11).italic())
                .foregroundStyle(Color.boltInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
    }

    private var liveModeDebugControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if appModel.isLiveModeActive {
                    appModel.stopLiveMode()
                } else {
                    appModel.startLiveMode()
                }
            } label: {
                Text(appModel.isLiveModeActive ? "Live-Modus stoppen" : "Live-Modus starten")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(appModel.isLiveModeSupported ? Color.boltCream : Color.boltInkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(appModel.isLiveModeActive ? Color.boltInk : Color.boltTeal)
                    .opacity(appModel.isLiveModeSupported ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!appModel.isLiveModeSupported)

            Text(liveModeStatusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.boltInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
    }

    private var liveModeStatusText: String {
        if !appModel.isLiveModeSupported {
            return "PiP nicht unterstützt"
        }

        if let error = appModel.liveModeErrorMessage {
            return "Fehler: \(error)"
        }

        return appModel.isLiveModeActive
            ? "Live-Modus läuft"
            : "PiP-Debug-Modus bereit"
    }

    private var dashboardConnectionStatus: ReceptionStatusObserver.ConnectionStatus {
        let statuses = appModel.registeredDevices.map {
            appModel.receptionStatusObserver.status(for: $0.id)
        }

        if statuses.contains(.live) {
            return .live
        }
        if statuses.contains(.recent) {
            return .recent
        }
        if statuses.contains(.stale) {
            return .stale
        }
        if statuses.contains(.offline) {
            return .offline
        }
        return .waiting
    }

    private var dashboardValuesAreDimmed: Bool {
        let statuses = appModel.registeredDevices.map {
            appModel.receptionStatusObserver.status(for: $0.id)
        }
        guard !statuses.isEmpty else {
            return false
        }
        return statuses.allSatisfy { $0.dimsLiveValue || $0 == .waiting }
    }
}
