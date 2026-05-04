import SwiftUI

struct ForecastView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            BoltBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if appModel.forecastSettings.isForecastEnabled {
                        SolarForecastSection(
                            viewModel: appModel.solarForecastViewModel,
                            requestLocation: {
                                appModel.sunsetService.requestPermission()
                                appModel.sunsetService.requestSingleLocationUpdate()
                            },
                            usesExpandedEmptyState: true
                        )
                        .padding(.horizontal, 18)
                    } else {
                        forecastDisabledState
                            .padding(.horizontal, 18)
                    }

                    footerExplanation
                        .padding(.horizontal, 18)
                }
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .refreshable {
                await appModel.refreshSolarForecastData()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await appModel.refreshSolarForecastData()
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
                BoltEyebrow("Prognose")
                Text("Solar-Vorhersage")
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

    private var forecastDisabledState: some View {
        VStack(alignment: .leading, spacing: 14) {
            BoltGlyph(size: 38)

            BoltEyebrow("Ausgeschaltet", color: .boltTealDeep)

            Text("Solar-Prognose ist deaktiviert.")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Color.boltInk)

            Text("Aktiviere die Prognose in den Einstellungen, um Wetter, Sonnenstand und Gelände am Stellplatz einzubeziehen.")
                .font(.boltBody)
                .foregroundStyle(Color.boltInkSoft)
                .fixedSize(horizontal: false, vertical: true)

            BoltSecondary("Einstellungen öffnen") {
                isShowingSettings = true
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
    }

    private var footerExplanation: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.boltYellow)
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(45))
                .padding(.top, 5)

            Text("Die Prognose kombiniert Open-Meteo-Strahlungsdaten, Gelände am Stellplatz und deine gemessenen Solar-Erträge. Alles bleibt auf diesem iPhone.")
                .font(.system(size: 11).italic())
                .foregroundStyle(Color.boltInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
