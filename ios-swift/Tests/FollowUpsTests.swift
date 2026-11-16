import XCTest
@testable import Max

final class FollowUpsTests: XCTestCase {
    func testMeetingSelectionPrefersConfirmedAndRejectsAmbiguousNames() {
        let now = Date()
        var confirmed = LifeEvent(title: "Voice demo", person: "Zac Wingate", place: "",
                                  occurredAt: now.addingTimeInterval(-200), notes: "")
        confirmed.attended = true
        let planned = LifeEvent(title: "Review", person: "Zac Wingate", place: "",
                                occurredAt: now.addingTimeInterval(-100), notes: "")
        let another = LifeEvent(title: "Catch-up", person: "Zac Chen", place: "",
                                occurredAt: now.addingTimeInterval(-300), notes: "")
        guard case .linked(let linked) = FollowUps.meeting(for: "Zac Wingate", events: [planned, another, confirmed]) else {
            return XCTFail("Expected a source for the exact name")
        }
        XCTAssertEqual(linked.id, confirmed.id)
        guard case .ambiguous = FollowUps.meeting(for: "Zac", events: [confirmed, another]) else {
            return XCTFail("Do not guess between two people")
        }
    }

    func testOpenFollowUpsIncludeOverdueAndExcludeCompletedAndOtherPeople() {
        var overdue = Reminder(title: "Send voice demo", body: "", fireDate: Date().addingTimeInterval(-10))
        overdue.followUpPerson = "Zac Wingate"
        var completed = Reminder(title: "Send agenda", body: "", fireDate: Date())
        completed.followUpPerson = "Zac Wingate"
        completed.completedAt = Date()
        var unrelated = Reminder(title: "Call Alex", body: "", fireDate: Date())
        unrelated.followUpPerson = "Alex"
        XCTAssertEqual(FollowUps.open(for: "Zac", reminders: [completed, unrelated, overdue]).map(\.id), [overdue.id])
        XCTAssertEqual(FollowUps.requestedPerson("What do I owe Zac?"), "zac")
        XCTAssertNil(FollowUps.requestedPerson("Remind me to send Zac the demo"))
    }

    func testOldReminderDecodesAndLinkedReminderRoundTrips() throws {
        let reminder = Reminder(title: "Old", body: "", fireDate: Date())
        let data = try JSONEncoder().encode(reminder)
        XCTAssertNil(try JSONDecoder().decode(Reminder.self, from: data).followUpPerson)
        var linked = reminder
        linked.followUpPerson = "Zac"
        linked.followUpMeetingID = "meeting"
        let result = try JSONDecoder().decode(Reminder.self, from: JSONEncoder().encode(linked))
        XCTAssertEqual(result.followUpPerson, "Zac")
        XCTAssertEqual(result.followUpMeetingID, "meeting")
    }
}
