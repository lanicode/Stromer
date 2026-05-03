import CoreLocation
import Foundation

protocol SolarForecastProviding: Sendable {
    func fetchSolarForecast(
        latitude: Double,
        longitude: Double,
        forecastDays: Int
    ) async throws -> SolarForecastResponse
}

actor SolarForecastService: SolarForecastProviding {
    static let shared = SolarForecastService()

    private let baseURL = "https://api.open-meteo.com/v1/forecast"
    private var cache: [String: CachedForecast] = [:]
    private let cacheLifetime: TimeInterval
    private let dataLoader: @Sendable (URL) async throws -> (Data, URLResponse)
    private let nowProvider: @Sendable () -> Date

    struct CachedForecast {
        let response: SolarForecastResponse
        let fetchedAt: Date
    }

    enum ServiceError: Error, LocalizedError {
        case invalidURL
        case requestFailed(String)
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Ungültige Forecast-URL."
            case let .requestFailed(message):
                return "Solar-Vorhersage fehlgeschlagen: \(message)"
            case let .decodingFailed(message):
                return "Solar-Vorhersage konnte nicht gelesen werden: \(message)"
            }
        }
    }

    init(
        cacheLifetime: TimeInterval = 3600,
        nowProvider: @escaping @Sendable () -> Date = { Date() },
        dataLoader: @escaping @Sendable (URL) async throws -> (Data, URLResponse) = {
            try await URLSession.shared.data(from: $0)
        }
    ) {
        self.cacheLifetime = cacheLifetime
        self.nowProvider = nowProvider
        self.dataLoader = dataLoader
    }

    func fetchSolarForecast(
        latitude: Double,
        longitude: Double,
        forecastDays: Int = 7
    ) async throws -> SolarForecastResponse {
        let key = String(format: "%.3f,%.3f|%dd", latitude, longitude, forecastDays)
        let now = nowProvider()

        if let cached = cache[key],
           now.timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return cached.response
        }

        guard let url = Self.makeURL(
            baseURL: baseURL,
            latitude: latitude,
            longitude: longitude,
            forecastDays: forecastDays
        ) else {
            throw ServiceError.invalidURL
        }

        do {
            let (data, response) = try await dataLoader(url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw ServiceError.requestFailed("HTTP \(httpResponse.statusCode)")
            }

            let decoded = try JSONDecoder().decode(SolarForecastResponse.self, from: data)
            cache[key] = CachedForecast(response: decoded, fetchedAt: now)
            return decoded
        } catch let decodingError as DecodingError {
            throw ServiceError.decodingFailed(String(describing: decodingError))
        } catch let serviceError as ServiceError {
            throw serviceError
        } catch {
            throw ServiceError.requestFailed(error.localizedDescription)
        }
    }

    static func makeURL(
        baseURL: String = "https://api.open-meteo.com/v1/forecast",
        latitude: Double,
        longitude: Double,
        forecastDays: Int
    ) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: [
                "shortwave_radiation",
                "direct_radiation",
                "diffuse_radiation",
                "direct_normal_irradiance",
                "cloud_cover",
                "is_day",
                "weather_code",
                "temperature_2m"
            ].joined(separator: ",")),
            URLQueryItem(name: "daily", value: [
                "shortwave_radiation_sum",
                "sunrise",
                "sunset",
                "weather_code"
            ].joined(separator: ",")),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: String(forecastDays)),
            URLQueryItem(name: "past_days", value: "1")
        ]
        return components?.url
    }
}

struct SolarForecastResponse: Decodable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let hourly: HourlyData
    let daily: DailyData

    struct HourlyData: Decodable, Equatable, Sendable {
        let time: [String]
        let shortwave_radiation: [Double?]
        let direct_radiation: [Double?]
        let diffuse_radiation: [Double?]
        let direct_normal_irradiance: [Double?]
        let cloud_cover: [Double?]
        let is_day: [Int?]
        let weather_code: [Int?]
        let temperature_2m: [Double?]
    }

    struct DailyData: Decodable, Equatable, Sendable {
        let time: [String]
        let shortwave_radiation_sum: [Double?]
        let sunrise: [String]
        let sunset: [String]
        let weather_code: [Int?]
    }
}

extension SolarForecastResponse {
    func dayIndex(for date: Date, calendar: Calendar = .current) -> Int? {
        daily.time.firstIndex { dayString in
            guard let day = Self.dayFormatter.date(from: dayString) else {
                return false
            }
            return calendar.isDate(day, inSameDayAs: date)
        }
    }

    func hourlyIndexes(for date: Date, calendar: Calendar = .current) -> [Int] {
        hourly.time.indices.filter { index in
            guard let hour = Self.hourFormatter.date(from: hourly.time[index]) else {
                return false
            }
            return calendar.isDate(hour, inSameDayAs: date)
        }
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()
}
