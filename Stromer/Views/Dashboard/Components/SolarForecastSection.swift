import Charts
import SwiftUI

struct SolarForecastSection: View {
    let viewModel: SolarForecastViewModel
    let requestLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BoltSection(header: "Prognose") {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.loading {
                        loadingState
                    } else if let estimate = viewModel.todayEstimate {
                        estimateSummary(estimate)
                        weekChart
                    } else {
                        emptyState
                    }
                }
                .padding(16)
            }

            if let profile = viewModel.horizonProfile {
                horizonSection(profile)
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.boltTeal)
            Text("Berechne Solar-Vorhersage und lokalen Horizont.")
                .font(.boltBody)
                .foregroundStyle(Color.boltInkSoft)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
    }

    private func estimateSummary(_ estimate: YieldEstimate) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    BoltEyebrow("Heute erwartet", color: .boltTealDeep)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(whValue(estimate.expectedWh))
                            .font(.system(size: 40, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Color.boltYellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(whUnit(estimate.expectedWh))
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.boltInkSoft)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(confidenceText(estimate))
                        .font(.boltMono(11))
                        .foregroundStyle(Color.boltInkSoft)
                    Text("\(DevicePresentation.number(estimate.sourceRadiationMJ, digits: 1)) MJ/m²")
                        .font(.boltMono(11))
                        .foregroundStyle(Color.boltInkSoft)
                }
            }

            Rectangle()
                .fill(Color.boltHair2)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                forecastFact(
                    title: "Topographie-Verlust",
                    value: "\(Int(estimate.horizonLossPercent.rounded())) %"
                )

                if viewModel.efficiencyFactor == nil {
                    forecastHint("Vorhersage benötigt mind. 5 Tage Solar-Daten. Bis dahin zeigt Stromer Strahlung und Topographie ohne personalisierten Ertrag.")
                }

                if let text = horizonDifferenceText {
                    forecastHint(text)
                }
            }
        }
    }

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            BoltEyebrow("Nächste 7 Tage", color: .boltInkSoft)

            let points = viewModel.weekEstimates.filter { $0.expectedWh != nil }
            if points.isEmpty {
                Text("Sobald genügend Solar-Historie vorliegt, erscheint hier die erwartete Tagesausbeute.")
                    .font(.boltBody)
                    .foregroundStyle(Color.boltInkSoft)
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
                    .multilineTextAlignment(.center)
            } else {
                Chart {
                    ForEach(points) { estimate in
                        BarMark(
                            x: .value("Tag", estimate.date),
                            y: .value("Wh", estimate.expectedWh ?? 0)
                        )
                        .foregroundStyle(isBestDay(estimate) ? Color.boltYellowDeep : Color.boltYellow)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisGridLine().foregroundStyle(Color.boltHair2)
                        AxisTick().foregroundStyle(Color.boltHair)
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.boltMono(10))
                            .foregroundStyle(Color.boltInkSoft)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                        AxisGridLine().foregroundStyle(Color.boltHair2)
                        AxisTick().foregroundStyle(Color.boltHair)
                        AxisValueLabel()
                            .font(.boltMono(10))
                            .foregroundStyle(Color.boltInkSoft)
                    }
                }
                .frame(height: 130)

                if let best = points.max(by: { ($0.expectedWh ?? 0) < ($1.expectedWh ?? 0) }),
                   let expectedWh = best.expectedWh {
                    Text("Bester Tag: \(best.date.formatted(.dateTime.weekday(.abbreviated))) (\(DevicePresentation.number(expectedWh, digits: 0)) Wh)")
                        .font(.system(size: 11).italic())
                        .foregroundStyle(Color.boltInkSoft)
                }
            }
        }
    }

    private func horizonSection(_ profile: ElevationService.HorizonProfile) -> some View {
        BoltSection(header: "Lokaler Horizont") {
            VStack(alignment: .leading, spacing: 12) {
                if let times = viewModel.localHorizonTimes {
                    horizonRow(
                        title: "Astro-Sonnenuntergang",
                        value: formattedTime(times.astronomicalSunset)
                    )
                    horizonRow(
                        title: "Lokal sichtbar bis",
                        value: formattedTime(times.localSunset)
                    )

                    if let minutes = times.sunsetDifferenceMinutes, minutes > 0 {
                        forecastHint("Die Sonne verschwindet lokal etwa \(minutes) Min früher hinter dem Horizont.")
                    }
                }

                HorizonPanoramaView(
                    profile: profile,
                    sunAzimuth: nil,
                    sunAltitude: nil
                )
                .frame(height: 150)
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            BoltGlyph(size: 34)

            Text(emptyTitle)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.boltInk)
                .multilineTextAlignment(.center)

            Text(emptyDescription)
                .font(.boltBody)
                .foregroundStyle(Color.boltInkSoft)
                .multilineTextAlignment(.center)

            if viewModel.lastError == "Standort nicht verfügbar." {
                BoltSecondary("Standort erlauben", action: requestLocation)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    private var emptyTitle: String {
        if viewModel.lastError == "Kein Solar-Regler registriert." {
            return "Kein MPPT registriert."
        }
        if viewModel.lastError == "Standort nicht verfügbar." {
            return "Standort fehlt."
        }
        return "Daten werden gesammelt."
    }

    private var emptyDescription: String {
        if let lastError = viewModel.lastError {
            switch lastError {
            case "Kein Solar-Regler registriert.":
                return "Füge einen Solar-Regler hinzu, um Solar-Ertrag vorherzusagen."
            case "Standort nicht verfügbar.":
                return "Stromer nutzt den Standort nur für Sonnenstand und lokalen Horizont."
            default:
                return lastError
            }
        }
        return "Vorhersage benötigt mind. 5 Tage Solar-Daten."
    }

    private var horizonDifferenceText: String? {
        guard let minutes = viewModel.localHorizonTimes?.sunsetDifferenceMinutes,
              minutes > 0 else {
            return nil
        }

        return "Berge oder Hügel reduzieren das sichtbare Abendlicht um etwa \(minutes) Min."
    }

    private func forecastFact(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.boltInk)
            Spacer()
            Text(value)
                .font(.boltMono(12))
                .fontWeight(.bold)
                .foregroundStyle(Color.boltInk)
        }
    }

    private func forecastHint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(Color.boltYellow)
                .frame(width: 7, height: 7)
                .rotationEffect(.degrees(45))
                .padding(.top, 5)

            Text(text)
                .font(.system(size: 11).italic())
                .foregroundStyle(Color.boltInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func horizonRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.boltInk)
            Spacer()
            Text(value)
                .font(.boltMono(12))
                .foregroundStyle(Color.boltInkSoft)
        }
    }

    private func isBestDay(_ estimate: YieldEstimate) -> Bool {
        let maxValue = viewModel.weekEstimates.compactMap(\.expectedWh).max()
        return estimate.expectedWh == maxValue
    }

    private func confidenceText(_ estimate: YieldEstimate) -> String {
        guard estimate.confidence > 0 else {
            return "Konfidenz offen"
        }
        return "Konfidenz \(Int((estimate.confidence * 100).rounded())) %"
    }

    private func whValue(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }
        if value >= 1_000 {
            return DevicePresentation.number(value / 1_000, digits: 2)
        }
        return DevicePresentation.number(value, digits: 0)
    }

    private func whUnit(_ value: Double?) -> String {
        guard let value, value >= 1_000 else {
            return "Wh"
        }
        return "kWh"
    }

    private func formattedTime(_ date: Date?) -> String {
        guard let date else {
            return "--"
        }
        return date.formatted(.dateTime.hour().minute())
    }
}
