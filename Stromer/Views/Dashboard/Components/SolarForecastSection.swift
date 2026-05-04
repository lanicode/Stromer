import Charts
import SwiftUI

struct SolarForecastSection: View {
    let viewModel: SolarForecastViewModel
    let requestLocation: () -> Void
    var usesExpandedEmptyState = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BoltSection(header: "Prognose") {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.loading {
                        loadingState
                    } else if let estimate = viewModel.todayEstimate,
                              estimate.expectedWh != nil {
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
            Text("Berechne Solar-Vorhersage und Sonnenblick am Stellplatz.")
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
                forecastHint(energyLossText(for: estimate))

                if viewModel.efficiencyFactor == nil {
                    forecastHint("Vorhersage benötigt mind. 5 Tage Solar-Daten. Bis dahin zeigt Stromer Strahlung und Gelände-Einfluss ohne personalisierten Ertrag.")
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

    @ViewBuilder
    private func horizonSection(_ profile: ElevationService.HorizonProfile) -> some View {
        if let times = viewModel.localHorizonTimes,
           hasOpenSunView(times) {
            openSunViewPill
        } else {
            BoltSection(header: "Heute am Stellplatz") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        BoltEyebrow("Wann wird's wirklich dunkel", color: .boltTealDeep)

                        if let times = viewModel.localHorizonTimes {
                            if let localSunset = times.localSunset {
                                sunTimeLine(title: "Sonne bis", date: localSunset)
                            }

                            if let sunsetText = sunsetDifferenceLine(times, profile: profile) {
                                Text(sunsetText)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.boltInk)
                            }

                            if let sunriseText = sunriseDifferenceLine(times, profile: profile) {
                                Text(sunriseText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.boltInkSoft)
                            }
                        } else {
                            Text("Stromer berechnet gerade, wie lange dein Stellplatz direkte Sonne hat.")
                                .font(.boltBody)
                                .foregroundStyle(Color.boltInkSoft)
                        }
                    }

                    if let estimate = viewModel.todayEstimate,
                       estimate.horizonLossPercent > 0 {
                        forecastHint(energyLossText(for: estimate))
                    }

                    HorizonPanoramaView(
                        profile: profile,
                        sunAzimuth: nil,
                        sunAltitude: nil
                    )
                    .frame(height: 150)

                    if shouldShowParkingTip {
                        parkingTip(profile)
                    } else if (viewModel.todayEstimate?.horizonLossPercent ?? 0) < 5 {
                        forecastHint("Dein Stellplatz hat freien Blick zur Sonne.")
                    }
                }
                .padding(16)
            }
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

            if usesExpandedEmptyState,
               viewModel.lastError == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aktuell: \(min(viewModel.solarHistorySampleDays, 5)) von 5 Tagen erfasst.")
                        .font(.boltMono(12))
                        .foregroundStyle(Color.boltInk)

                    if let date = forecastAvailableDate {
                        Text("Voraussichtlich verfügbar: \(date.formatted(.dateTime.day().month(.wide)))")
                            .font(.boltMono(12))
                            .foregroundStyle(Color.boltInkSoft)
                    }

                    if let horizonText = horizonDifferenceText ?? sunsetText {
                        Rectangle()
                            .fill(Color.boltHair2)
                            .frame(height: 1)
                            .padding(.vertical, 2)

                        Text("Trotzdem schon abrufbar:")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.boltInk)

                        forecastHint(horizonText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            }

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
                return "Stromer nutzt den Standort nur für Sonnenstand und Gelände am Stellplatz."
            default:
                return lastError
            }
        }
        return "Vorhersage benötigt mind. 5 Tage Solar-Daten."
    }

    private var forecastAvailableDate: Date? {
        let remaining = max(0, 5 - viewModel.solarHistorySampleDays)
        guard remaining > 0 else {
            return nil
        }
        return Calendar.current.date(byAdding: .day, value: remaining, to: Date())
    }

    private var sunsetText: String? {
        guard let sunset = viewModel.localHorizonTimes?.localSunset ??
            viewModel.localHorizonTimes?.astronomicalSunset else {
            return nil
        }
        return "Sonne bis \(formattedTime(sunset))."
    }

    private var horizonDifferenceText: String? {
        guard let minutes = viewModel.localHorizonTimes?.sunsetDifferenceMinutes,
              minutes > 2 else {
            return nil
        }

        if let profile = viewModel.horizonProfile {
            return "\(profile.dominantObstacleType) im \(profile.dominantDirection) nehmen dir abends etwa \(minutes) Min Sonne."
        }
        return "Berge oder Hügel nehmen dir abends etwa \(minutes) Min Sonne."
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

    private var openSunViewPill: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.boltTeal)
                .frame(width: 7, height: 7)

            Text("Dein Standort hat freien Sonnenblick.")
                .font(.system(size: 12, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(Color.boltTealDeep)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
    }

    private func sunTimeLine(title: String, date: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("☀️")
                .font(.system(size: 18))
            Text("\(title) \(formattedTime(date))")
                .font(.system(size: 24, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Color.boltInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func sunsetDifferenceLine(
        _ times: LocalHorizonTimes,
        profile: ElevationService.HorizonProfile
    ) -> String? {
        guard let minutes = times.sunsetDifferenceMinutes,
              minutes > 2 else {
            return nil
        }
        return "\(minutes) Min früher als offiziell (\(obstacleDescription(profile)))"
    }

    private func sunriseDifferenceLine(
        _ times: LocalHorizonTimes,
        profile: ElevationService.HorizonProfile
    ) -> String? {
        guard let minutes = times.sunriseDifferenceMinutes,
              minutes > 2 else {
            return nil
        }
        return "Morgens \(minutes) Min später als offiziell (\(obstacleDescription(profile)))"
    }

    private func hasOpenSunView(_ times: LocalHorizonTimes) -> Bool {
        abs(times.sunsetDifferenceMinutes ?? 0) < 2 &&
            abs(times.sunriseDifferenceMinutes ?? 0) < 2
    }

    private func obstacleDescription(_ profile: ElevationService.HorizonProfile) -> String {
        let direction = profile.dominantDirection
        guard !direction.isEmpty else {
            return profile.dominantObstacleType
        }
        return "\(profile.dominantObstacleType) im \(direction)"
    }

    private func energyLossText(for estimate: YieldEstimate) -> String {
        let loss = Int(estimate.horizonLossPercent.rounded())
        guard loss > 0 else {
            return "Dein Stellplatz hat freien Blick zur Sonne."
        }

        let obstacle = viewModel.horizonProfile?.dominantObstacleType ?? "Gelände"
        return "Du verlierst etwa \(loss) % Sonnenenergie durch \(obstacle)."
    }

    private var shouldShowParkingTip: Bool {
        (viewModel.todayEstimate?.horizonLossPercent ?? 0) > 10
    }

    private func parkingTip(_ profile: ElevationService.HorizonProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Tipp")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.boltInk)

            Text(parkingTipText(profile))
                .font(.boltBody)
                .foregroundStyle(Color.boltInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.boltYellow.opacity(0.14))
        .overlay(Rectangle().stroke(Color.boltYellowDeep.opacity(0.65), lineWidth: 1))
    }

    private func parkingTipText(_ profile: ElevationService.HorizonProfile) -> String {
        if let minutes = viewModel.localHorizonTimes?.sunsetDifferenceMinutes,
           minutes > 2 {
            return "Wenn du dich auf eine Stelle mit freierem Blick nach \(profile.dominantDirection) stellst, hättest du heute Abend etwa \(minutes) Min mehr Sonne."
        }
        return "Eine freiere Stelle kann heute spürbar mehr Sonne bringen."
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
