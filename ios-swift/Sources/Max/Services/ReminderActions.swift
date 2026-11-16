import Foundation
import UserNotifications

@MainActor
enum ReminderActions {
    private static var rescheduling: Set<String> = []

    static func complete(_ reminder: Reminder, scope: String) -> Bool {
        let storage = StorageService.shared
        guard storage.accountScope == scope, var latest = storage.loadReminders().first(where: { $0.id == reminder.id }), latest.completedAt == nil else { return false }
        latest.completedAt = Date()
        guard storage.updateReminder(latest, accountScope: scope) else { return false }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id])
        center.removeDeliveredNotifications(withIdentifiers: [reminder.id])
        return true
    }

    static func reschedule(_ reminder: Reminder, to date: Date, scope: String,
                           schedule: ((UNNotificationRequest) async throws -> Void)? = nil) async -> String? {
        let storage = StorageService.shared
        let delay = date.timeIntervalSinceNow
        guard storage.accountScope == scope, !Task.isCancelled,
              let latest = storage.loadReminders().first(where: { $0.id == reminder.id }), latest.completedAt == nil,
              delay > 0, delay <= 365 * 86400 else { return "Choose a future time within a year, or reopen this reminder." }
        guard rescheduling.insert(latest.id).inserted else { return "This reminder is already being updated." }
        defer { rescheduling.remove(latest.id) }
        let center = UNUserNotificationCenter.current()
        if schedule == nil {
            guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return "Allow notifications in Settings to reschedule." }
        }
        guard storage.accountScope == scope, !Task.isCancelled, date > Date(),
              storage.loadReminders().contains(where: { $0.id == latest.id && $0.completedAt == nil }) else { return "Your session or reminder time changed." }
        let request = ReminderNotifications.request(for: latest, at: date, scope: scope)
        do {
            if let schedule { try await schedule(request) } else { try await center.add(request) }
        } catch { return "Couldn't reschedule. Your saved reminder is unchanged." }
        guard storage.accountScope == scope, !Task.isCancelled,
              storage.loadReminders().first(where: { $0.id == latest.id })?.completedAt == nil,
              storage.loadReminders().contains(where: { $0.id == latest.id }) else {
            center.removePendingNotificationRequests(withIdentifiers: [latest.id]); return "Your session or reminder changed."
        }
        var updated = latest; updated.fireDate = date; updated.triggerKind = "time"; updated.contextName = nil; updated.placeID = nil
        guard storage.updateReminder(updated, accountScope: scope) else { center.removePendingNotificationRequests(withIdentifiers: [latest.id]); return "Your reminder changed. Please reopen it." }
        center.removeDeliveredNotifications(withIdentifiers: [latest.id])
        return nil
    }
}
