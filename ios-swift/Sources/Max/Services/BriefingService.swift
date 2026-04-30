import Foundation
import UserNotifications

// MARK: - Notification name used to trigger the briefing inside the app

extension Notification.Name {
    static let maxStartBriefing = Notification.Name("max.start.briefing")
}

// MARK: - BriefingService

final class BriefingService {
    static let shared = BriefingService()
    static let notificationID = "max.morning.briefing"
    static let userInfoTypeKey = "max_notification_type"
    static let briefingTypeValue = "morning_briefing"

    static let briefingPrompt = """
    Good morning! Please give me my daily briefing. \
    First check today's date and time with get_datetime, then pull up my calendar events for today with get_calendar_events, \
    read the top news headlines with read_news, and check my emails. \
    Summarise everything conversationally — like a smart friend catching me up before my day starts. \
    Keep it warm, brief, and actionable.
    """

    private init() {}

    func schedule(hour: Int, minute: Int) {
        cancel()
        let content = UNMutableNotificationContent()
        content.title = "Good morning"
        content.body = "Your Max briefing is ready — tap to hear it."
        content.sound = .default
        content.userInfo = [Self.userInfoTypeKey: Self.briefingTypeValue]

        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.notificationID]
        )
    }

    func rescheduleIfNeeded() {
        let settings = StorageService.shared.loadSettings()
        guard settings.briefingEnabled else { cancel(); return }
        schedule(hour: settings.briefingHour, minute: settings.briefingMinute)
    }
}
