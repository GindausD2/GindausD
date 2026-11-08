import XCTest
@testable import Max

final class PeopleRecallTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    func testDateAndPlaceMatchUsesConfirmedRecordAndSource() throws {
        var match = LifeEvent(title: "Voice demo", person: "Zac Wingate", place: "Café Grenel",
                              occurredAt: date(10, 20), notes: "Reviewed the prototype.")
        match.attended = true
        let other = LifeEvent(title: "Coffee", person: "Jordan", place: "Café Grenel",
                             occurredAt: date(9, 20), notes: "")
        let result = try XCTUnwrap(PeopleRecall.answer("Who did I meet at that café last month?",
                                                     events: [other, match], now: date(11, 8), calendar: calendar))
        XCTAssertTrue(result.text.contains("you met Zac Wingate"))
        XCTAssertTrue(result.text.contains("Reviewed the prototype."))
        XCTAssertEqual(result.eventID, match.id)
        XCTAssertFalse(result.text.contains("Jordan"))
    }

    func testAmbiguousMatchesRequireChoiceAndRespectDeletion() throws {
        let a = LifeEvent(title: "Design", person: "Jordan", place: "Café Grenel", occurredAt: date(10, 20), notes: "")
        let b = LifeEvent(title: "Demo", person: "Zac", place: "Café Grenel", occurredAt: date(10, 19), notes: "")
        let result = try XCTUnwrap(PeopleRecall.answer("Who did I meet at Café Grenel?", events: [b, a],
                                                     now: date(11, 8), calendar: calendar))
        XCTAssertEqual(result.choices, [a.id, b.id])
        XCTAssertNil(result.eventID)
        let chosen = PeopleRecall.answer("2", events: [a, b], previousChoices: result.choices)
        XCTAssertEqual(chosen?.eventID, b.id)
        XCTAssertTrue(chosen?.text.contains("scheduled with Zac") == true)
        XCTAssertTrue(chosen?.text.contains("doesn’t confirm") == true)
        XCTAssertNil(PeopleRecall.answer("2", events: [a], previousChoices: result.choices)?.eventID)
    }

    func testOrdinaryConversationAndNoMatch() {
        XCTAssertNil(PeopleRecall.answer("Who is the CEO?", events: []))
        XCTAssertNil(PeopleRecall.answer("1", events: []))
        XCTAssertNil(PeopleRecall.answer("Who did I meet yesterday?", events: [])?.eventID)
    }
}
