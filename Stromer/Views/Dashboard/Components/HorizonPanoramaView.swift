import SwiftUI

struct HorizonPanoramaView: View {
    let profile: ElevationService.HorizonProfile
    let sunAzimuth: Double?
    let sunAltitude: Double?

    private var maxAngle: Double {
        max(profile.samples.map(\.horizonAngle).max() ?? 0, 5)
    }

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size).insetBy(dx: 10, dy: 12)
            let baseline = rect.maxY - 26

            ZStack {
                Color.boltPaper

                Path { path in
                    path.move(to: CGPoint(x: rect.minX, y: baseline))
                    path.addLine(to: CGPoint(x: rect.maxX, y: baseline))
                }
                .stroke(Color.boltHair, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                horizonFillPath(in: rect, baseline: baseline)
                    .fill(Color.boltTealSoft)

                horizonLinePath(in: rect, baseline: baseline)
                    .stroke(Color.boltInkSoft, style: StrokeStyle(lineWidth: 1.5, lineJoin: .miter))

                ForEach(directionTicks, id: \.azimuth) { tick in
                    Text(tick.label)
                        .font(.boltMono(9))
                        .foregroundStyle(Color.boltInkSoft)
                        .position(
                            x: xPosition(for: tick.azimuth, in: rect),
                            y: rect.maxY - 8
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(obstacleHeadline.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(Color.boltInkSoft)
                    Text(profile.dominantDirection)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color.boltInk)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if let sunAzimuth {
                    sunMarker(
                        azimuth: sunAzimuth,
                        altitude: sunAltitude,
                        rect: rect,
                        baseline: baseline
                    )
                }
            }
            .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
        }
    }

    private var obstacleHeadline: String {
        switch profile.dominantObstacleType {
        case "Berge":
            return "Höchste Berge"
        case "Hügel":
            return "Höchste Hügel"
        default:
            return "Höchstes Gelände"
        }
    }

    private var directionTicks: [(label: String, azimuth: Double)] {
        [
            ("N", 0), ("O", 90), ("S", 180), ("W", 270), ("N", 360)
        ]
    }

    private var closedSamples: [ElevationService.HorizonProfile.HorizonSample] {
        let sorted = profile.samples.sorted { $0.azimuth < $1.azimuth }
        guard let first = sorted.first else {
            return []
        }

        return sorted + [
            ElevationService.HorizonProfile.HorizonSample(
                azimuth: 360,
                terrainElevation: first.terrainElevation,
                horizonAngle: first.horizonAngle
            )
        ]
    }

    private func horizonFillPath(in rect: CGRect, baseline: CGFloat) -> Path {
        var path = horizonLinePath(in: rect, baseline: baseline)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    private func horizonLinePath(in rect: CGRect, baseline: CGFloat) -> Path {
        Path { path in
            for (index, sample) in closedSamples.enumerated() {
                let point = horizonPoint(
                    azimuth: sample.azimuth,
                    angle: sample.horizonAngle,
                    rect: rect,
                    baseline: baseline
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func horizonPoint(
        azimuth: Double,
        angle: Double,
        rect: CGRect,
        baseline: CGFloat
    ) -> CGPoint {
        let usableHeight = max(baseline - rect.minY - 14, 1)
        let normalized = min(max(angle / maxAngle, 0), 1)
        let y = baseline - CGFloat(pow(normalized, 0.78)) * usableHeight
        return CGPoint(x: xPosition(for: azimuth, in: rect), y: y)
    }

    private func sunMarker(
        azimuth: Double,
        altitude: Double?,
        rect: CGRect,
        baseline: CGFloat
    ) -> some View {
        let horizonAngle = profile.horizonAngle(at: azimuth)
        let markerAngle = max(altitude ?? horizonAngle + 2, horizonAngle + 1)
        let usableHeight = max(baseline - rect.minY - 14, 1)
        let normalized = min(max(markerAngle / max(maxAngle, markerAngle), 0), 1)
        let y = baseline - CGFloat(normalized) * usableHeight - 8

        return Image(systemName: "sun.max.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.boltYellow)
            .position(x: xPosition(for: azimuth, in: rect), y: max(rect.minY + 16, y))
    }

    private func xPosition(for azimuth: Double, in rect: CGRect) -> CGFloat {
        let normalized = positiveAzimuth(azimuth) / 360
        return rect.minX + CGFloat(normalized) * rect.width
    }

    private func positiveAzimuth(_ azimuth: Double) -> Double {
        let normalized = azimuth.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }
}
