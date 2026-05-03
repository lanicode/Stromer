import SwiftUI

struct HistoryView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @State private var isShowingSettings = false
    let openDevices: () -> Void

    init(openDevices: @escaping () -> Void = {}) {
        self.openDevices = openDevices
    }

    var body: some View {
        let viewModel = appModel.historyViewModel
        @Bindable var bindableViewModel = viewModel

        ZStack {
            BoltBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if !viewModel.hasDevices {
                        emptyState
                    } else {
                        historyRangeControl(selection: $bindableViewModel.timeRange)
                            .padding(.horizontal, 18)

                        if viewModel.hasSolarSection {
                            SolarHistorySection(
                                timeRange: viewModel.timeRange,
                                points: viewModel.solarDailyData,
                                totalKwh: viewModel.totalSolarKwh,
                                bestDay: viewModel.bestSolarDay
                            )
                            .padding(.horizontal, 18)
                        }

                        if viewModel.hasBatterySection {
                            BatteryHistorySection(
                                timeRange: viewModel.timeRange,
                                ranges: viewModel.batterySocRange,
                                lowestDay: viewModel.lowestSocDay,
                                fullCharges: viewModel.totalFullCharges
                            )
                            .padding(.horizontal, 18)
                        }

                        if viewModel.hasDcDcSection {
                            DcDcHistorySection(
                                timeRange: viewModel.timeRange,
                                points: viewModel.dcDcChargingData,
                                totalChargingHours: viewModel.totalChargingHours
                            )
                            .padding(.horizontal, 18)
                        }

                        ComparisonSection(
                            weekComparison: viewModel.weekComparison,
                            monthComparison: viewModel.monthComparison
                        )
                        .padding(.horizontal, 18)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: viewModel.timeRange) {
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
                BoltEyebrow("Verlauf")
                Text("Letzte Wochen")
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
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(Color.boltTeal)
                .frame(maxWidth: .infinity)

            BoltEyebrow("Noch kein Verlauf", color: .boltTealDeep)
            Text("Füge ein Gerät hinzu,\num Historie zu sammeln.")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Color.boltInk)
                .lineSpacing(0)

            Text("Der Verlauf zeigt später Solar, Batterie und DC/DC über alle Geräte hinweg.")
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

    private func historyRangeControl(selection: Binding<HistoryOverviewRange>) -> some View {
        HStack(spacing: 0) {
            ForEach(HistoryOverviewRange.allCases) { range in
                Button {
                    selection.wrappedValue = range
                } label: {
                    Text(range.title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(selection.wrappedValue == range ? Color.boltCream : Color.boltInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection.wrappedValue == range ? Color.boltInk : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(Color.boltInk, lineWidth: 1))
    }
}
