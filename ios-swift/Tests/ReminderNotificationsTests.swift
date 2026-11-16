import XCTest
import UserNotifications
@testable import Max

final class ReminderNotificationsTests: XCTestCase {
    func testNotificationUsesReminderIDAndCarriesTheNewDueTimeAfterSnooze() {
        let reminder = Reminder(title: "Grocery run", body: "Rice and fresh meat", fireDate: Date().addingTimeInterval(60))
        let snoozed = reminder.fireDate.addingTimeInterval(600)
        let request = ReminderNotifications.request(for: reminder, at: snoozed, scope: "account-a")
        XCTAssertEqual(request.identifier, reminder.id)
        XCTAssertEqual(request.content.title, reminder.title)
        XCTAssertEqual(request.content.body, reminder.body)
        XCTAssertEqual(request.content.categoryIdentifier, ReminderNotifications.actionCategory.identifier)
        XCTAssertEqual(request.content.userInfo[ReminderNotifications.scopeKey] as? String, "account-a")
        XCTAssertEqual(request.content.userInfo["max.reminder.time"] as? Double, snoozed.timeIntervalSince1970)
        XCTAssertNotNil(request.content.sound)
        XCTAssertEqual(ReminderNotifications.actionCategory.actions.map(\.identifier), [
            ReminderNotifications.done, ReminderNotifications.snooze
        ])
    }
}
