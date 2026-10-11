import Foundation
import UserNotifications

extension Notification.Name {
    static let maxStartBriefing = Notification.Name("max.start.briefing")
    static let maxWidgetActivate = Notification.Name("max.widget.activate")
    static let maxQuickReply = Notification.Name("max.quick.reply")
}
final class BriefingService {
    static let shared = BriefingService()
    static let notificationID = "max.morning.briefing"
    static let userInfoTypeKey = "max_notification_type"
    static let briefingTypeValue = "morning_briefing"
    private init() {}

    func schedule(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return }
        cancel()
        let content = UNMutableNotificationContent()
        content.title = "Good morning"
        content.body = "Start your day with Max — tap for your morning briefing."
        content.sound = .default
        content.userInfo = [Self.userInfoTypeKey: Self.briefingTypeValue]
        var dc = DateComponents(); dc.hour = hour; dc.minute = minute
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
    }
    func cancel() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID]) }
    func rescheduleIfNeeded() {
        let s = StorageService.shared.loadSettings()
        if s.briefingEnabled { schedule(hour: s.briefingHour, minute: s.briefingMinute) } else { cancel() }
    }
    func snapshot() async -> String {
        let tools = ToolsService.shared
        async let weather = tools.execute(name: "get_weather", input: [:])
        async let calendar = tools.execute(name: "get_calendar_events", input: ["daysAhead": "1"])
        async let reminders = tools.execute(name: "get_reminders", input: [:])
        func parse(_ raw: String) -> [String: Any] {
            guard let data = raw.data(using: .utf8) else { return [:] }
            return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        let (w, c, r) = await (parse(weather), parse(calendar), parse(reminders))
        var lines = ["Good morning. Here's your day at a glance."]
        if let temp = w["temperatureC"] as? Double, let place = w["place"] as? String {
            lines.append("Weather in \(place): \(Int(temp.rounded()))°C, \(w["condition"] as? String ?? ""). Source: Apple Weather.")
        } else { lines.append("Weather: \(w["error"] as? String ?? "unavailable").") }
        if let events = c["events"] as? [[String: String]] {
            lines.append(events.isEmpty ? "Calendar: no events in the next 24 hours." : "Calendar: " + events.map { "\($0["title"] ?? "Event") at \($0["start"] ?? "")" }.joined(separator: "; "))
        } else { lines.append("Calendar: permission or connection unavailable.") }
        if let items = r["reminders"] as? [[String: Any]] {
            lines.append(items.isEmpty ? "Reminders: none upcoming." : "Reminders: " + items.compactMap { $0["title"] as? String }.joined(separator: "; "))
        }
        lines.append(await EmailMonitorService.shared.briefingSummary())
        lines.append("Missed calls: not available to Max.")
        return lines.joined(separator: "\n\n")
    }
}
