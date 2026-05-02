import Combine
import CoreLocation
import Foundation

@MainActor
final class SunsetService: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var lastKnownLocation: CLLocation?
    @Published var todaySunset: Date?
    @Published var permissionStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        permissionStatus = manager.authorizationStatus
    }

    func requestPermission() {
        if permissionStatus == .authorizedWhenInUse ||
            permissionStatus == .authorizedAlways {
            requestSingleLocationUpdate()
            return
        }
        manager.requestWhenInUseAuthorization()
    }

    func requestSingleLocationUpdate() {
        guard permissionStatus == .authorizedWhenInUse ||
            permissionStatus == .authorizedAlways else {
            return
        }
        manager.requestLocation()
    }

    static func sunsetTime(for date: Date, latitude: Double, longitude: Double) -> Date? {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = .current
        let dayOfYear = localCalendar.ordinality(of: .day, in: .year, for: date) ?? 1

        let gamma = 2 * Double.pi / 365 * Double(dayOfYear - 1)
        let declination = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148 * sin(3 * gamma)

        let latitudeRadians = latitude * .pi / 180
        let zenith = 90.833 * .pi / 180
        let cosHourAngle = (cos(zenith) / (cos(latitudeRadians) * cos(declination)))
            - tan(latitudeRadians) * tan(declination)
        guard cosHourAngle >= -1, cosHourAngle <= 1 else {
            return nil
        }

        let hourAngle = acos(cosHourAngle) * 180 / .pi
        let equationOfTime = 229.18 * (
            0.000075
                + 0.001868 * cos(gamma)
                - 0.032077 * sin(gamma)
                - 0.014615 * cos(2 * gamma)
                - 0.040849 * sin(2 * gamma)
        )

        let sunsetMinutesUTC = 720 - 4 * longitude - equationOfTime + 4 * hourAngle

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let dayComponents = localCalendar.dateComponents([.year, .month, .day], from: date)
        var utcComponents = DateComponents()
        utcComponents.timeZone = utcCalendar.timeZone
        utcComponents.year = dayComponents.year
        utcComponents.month = dayComponents.month
        utcComponents.day = dayComponents.day
        utcComponents.hour = 0
        utcComponents.minute = 0
        utcComponents.second = 0

        guard let dayStartUTC = utcCalendar.date(from: utcComponents) else {
            return nil
        }
        return dayStartUTC.addingTimeInterval(sunsetMinutesUTC * 60)
    }
}

extension SunsetService: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            return
        }

        Task { @MainActor in
            lastKnownLocation = location
            todaySunset = Self.sunsetTime(
                for: Date(),
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            permissionStatus = status
            requestSingleLocationUpdate()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}
