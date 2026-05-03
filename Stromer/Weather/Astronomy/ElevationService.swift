import CoreLocation
import Foundation

@MainActor
final class ElevationService {
    static let shared = ElevationService()

    private var horizonCache: [String: HorizonProfile] = [:]
    private let cacheLimit = 10

    init() {}

    struct HorizonProfile: Equatable {
        let observerElevation: Double
        let observerEyeHeight: Double
        let samples: [HorizonSample]
        let sampleDistanceKm: Double
        let fetchedAt: Date

        struct HorizonSample: Equatable, Identifiable {
            let azimuth: Double
            let terrainElevation: Double
            let horizonAngle: Double

            var id: Double { azimuth }
        }

        func horizonAngle(at azimuth: Double) -> Double {
            let normalized = azimuth.truncatingRemainder(dividingBy: 360)
            let positive = normalized < 0 ? normalized + 360 : normalized
            let sortedSamples = samples.sorted { $0.azimuth < $1.azimuth }

            guard let first = sortedSamples.first else {
                return 0
            }
            guard sortedSamples.count >= 2 else {
                return first.horizonAngle
            }

            if let exact = sortedSamples.first(where: { abs($0.azimuth - positive) < 0.0001 }) {
                return exact.horizonAngle
            }

            let lower = sortedSamples.last(where: { $0.azimuth < positive }) ?? sortedSamples.last ?? first
            let upper = sortedSamples.first(where: { $0.azimuth > positive }) ?? first
            var upperAzimuth = upper.azimuth
            var targetAzimuth = positive

            if upperAzimuth < lower.azimuth {
                upperAzimuth += 360
                if targetAzimuth < lower.azimuth {
                    targetAzimuth += 360
                }
            }

            let distance = upperAzimuth - lower.azimuth
            guard distance > 0 else {
                return lower.horizonAngle
            }

            let weight = (targetAzimuth - lower.azimuth) / distance
            return lower.horizonAngle * (1 - weight) + upper.horizonAngle * weight
        }
    }

    func fetchHorizonProfile(
        for coordinate: CLLocationCoordinate2D,
        sampleDistanceKm: Double = 5.0,
        observerEyeHeight: Double = 1.7
    ) async throws -> HorizonProfile {
        let eyeHeight = max(observerEyeHeight, 0)
        let key = cacheKey(
            for: coordinate,
            sampleDistanceKm: sampleDistanceKm,
            observerEyeHeight: eyeHeight
        )

        if let cached = horizonCache[key],
           Date().timeIntervalSince(cached.fetchedAt) < 7 * 24 * 3600 {
            return cached
        }

        let observerElevation = try await fetchElevation(for: [coordinate]).first ?? 0
        let ringCoordinates = (0..<36).map { index in
            destination(
                from: coordinate,
                azimuthDegrees: Double(index) * 10,
                distanceKm: sampleDistanceKm
            )
        }
        let ringElevations = try await fetchElevation(for: ringCoordinates)
        let samples = ringElevations.enumerated().map { index, elevation in
            let azimuth = Double(index) * 10
            let heightDifference = elevation - (observerElevation + eyeHeight)
            let distanceMeters = sampleDistanceKm * 1000
            let angleDegrees = atan2(max(heightDifference, 0), distanceMeters) * 180 / .pi

            return HorizonProfile.HorizonSample(
                azimuth: azimuth,
                terrainElevation: elevation,
                horizonAngle: angleDegrees
            )
        }

        let profile = HorizonProfile(
            observerElevation: observerElevation,
            observerEyeHeight: eyeHeight,
            samples: samples,
            sampleDistanceKm: sampleDistanceKm,
            fetchedAt: Date()
        )

        if horizonCache.count >= cacheLimit, let firstKey = horizonCache.keys.first {
            horizonCache.removeValue(forKey: firstKey)
        }
        horizonCache[key] = profile
        return profile
    }

    private func fetchElevation(for coordinates: [CLLocationCoordinate2D]) async throws -> [Double] {
        guard !coordinates.isEmpty else {
            return []
        }

        let latitudes = coordinates.map { String(format: "%.5f", $0.latitude) }.joined(separator: ",")
        let longitudes = coordinates.map { String(format: "%.5f", $0.longitude) }.joined(separator: ",")

        var components = URLComponents(string: "https://api.open-meteo.com/v1/elevation")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: latitudes),
            URLQueryItem(name: "longitude", value: longitudes)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        struct Response: Decodable {
            let elevation: [Double]
        }

        return try JSONDecoder().decode(Response.self, from: data).elevation
    }

    private func destination(
        from origin: CLLocationCoordinate2D,
        azimuthDegrees: Double,
        distanceKm: Double
    ) -> CLLocationCoordinate2D {
        let earthRadiusKm = 6371.0
        let bearing = azimuthDegrees * .pi / 180
        let ratio = distanceKm / earthRadiusKm
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(ratio) + cos(lat1) * sin(ratio) * cos(bearing))
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(ratio) * cos(lat1),
            cos(ratio) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    private func cacheKey(
        for coordinate: CLLocationCoordinate2D,
        sampleDistanceKm: Double,
        observerEyeHeight: Double
    ) -> String {
        String(
            format: "%.3f,%.3f|%.1fkm|%.1fm",
            coordinate.latitude,
            coordinate.longitude,
            sampleDistanceKm,
            observerEyeHeight
        )
    }
}
