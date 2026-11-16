import Foundation
import UserNotifications

enum ReminderNotifications {
    static let category = "max.reminder"
    static let done = "max.reminder.done"
    static let snooze = "max.reminder.snooze"
    static let scopeKey = "max.reminder.account"
    static let changed = Notification.Name("max.reminders.changed")

    static var actionCategory: UNNotificationCategory {
        UNNotificationCategory(identifier: category, actions: [
            UNNotificationAction(identifier: done, title: "Done", options: [.authenticationRequired]),
            UNNotificationAction(identifier: snooze, title: "Remind me in 10 min", options: [.authenticationRequired])
        ], intentIdentifiers: [])
    }

    static func request(for reminder: Reminder, at date: Date, scope: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = [scopeKey: scope, "max.reminder.time": date.timeIntervalSince1970]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        return UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
    }

    @MainActor
    static func handle(action: String, id: String, scope: String, scheduledTime: Double?) async {
        // Notification actions can launch Max before the local session is restored.
        let auth = AuthService.shared
        for _ in 0..<30 {
            if !auth.isRestoringSession { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard auth.currentUser?.storageScope == scope,
              StorageService.shared.accountScope == scope,
              let reminder = StorageService.shared.loadReminders().first(where: { $0.id == id && $0.completedAt == nil }),
              let scheduledTime, abs(reminder.fireDate.timeIntervalSince1970 - scheduledTime) < 1 else { return }
        if action == done {
            _ = ReminderActions.complete(reminder, scope: scope)
        } else if action == snooze {
            _ = await ReminderActions.reschedule(reminder, to: Date().addingTimeInterval(600), scope: scope)
        }
    }
}
