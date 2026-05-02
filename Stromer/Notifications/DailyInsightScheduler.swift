import Foundation
import StromerScanner
import UserNotifications

@MainActor
final class DailyInsightScheduler {
    private let settings: NotificationSettings
    private let sunsetService: SunsetService
    private let historyStore: any HistoryStore
    private let center: any LocalNotificationScheduling

    init(
        settings: NotificationSettings,
        sunsetService: SunsetService,
        historyStore: any HistoryStore,
        center: any LocalNotificationScheduling = UNUserNotificationCenter.current()
    ) {
        self.settings = settings
        self.sunsetService = sunsetService
        self.historyStore = historyStore
        self.center = center
    }

    func reschedule() async {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-insight"])

        guard settings.notificationsEnabled,
              settings.dailyInsightEnabled else {
            return
        }

        let triggerTime: DateComponents
        if settings.dailyInsightUseSunset,
           let sunset = sunsetService.todaySunset {
            let scheduled = sunset.addingTimeInterval(30 * 60)
            triggerTime = Calendar.current.dateComponents(
                [.hour, .minute],
                from: scheduled
            )
        } else {
            triggerTime = settings.dailyInsightFixedTime
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerTime,
            repeats: true
        )

        let content = UNMutableNotificationContent()
        content.title = "Stromer Tagesfazit"
        content.body = "Tippe für die Energie-Zusammenfassung von heute."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "daily-insight",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    func generateInsightText(deviceID: UUID) async -> String {
        guard let today = await historyStore.todayAggregate(deviceID: deviceID) else {
            return "Keine Daten heute"
        }

        var parts: [String] = []
        if let yieldTodayMax = today.yieldTodayMax {
            parts.append("Solar-Ertrag: \(Int(yieldTodayMax.rounded())) Wh")
        }
        if let socMin = today.socMin, let socMax = today.socMax {
            parts.append("SoC \(Int(socMin.rounded()))-\(Int(socMax.rounded())) %")
        }
        if let outputMin = today.outputVoltageMin, let outputMax = today.outputVoltageMax {
            parts.append(String(format: "DC/DC %.1f-%.1f V", outputMin, outputMax))
        }

        return parts.isEmpty ? "Keine Daten heute" : parts.joined(separator: " · ")
    }
}
