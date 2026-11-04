import XCTest
@testable import Max

final class MemoryReplayTests: XCTestCase {
    private func event() -> LifeEvent {
        LifeEvent(title: "Max meeting", person: "Justin", place: "Cafe Grenel", occurredAt: Date(timeIntervalSince1970: 1000), notes: "Discussed voice interruptions.")
    }

    func testReplayUsesSavedWordsAndKeepsSourceAndUnconfirmedAttendance() {
        let value = event()
        let cards = MemoryReplay.cards(for: value, locale: Locale(identifier: "en_US"), timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(cards.map(\.id), ["event", "people", "place", "notes", "source"])
        XCTAssertEqual(cards.first(where: { $0.id == "people" })?.text, value.person)
        XCTAssertEqual(cards.first(where: { $0.id == "notes" })?.text, value.notes)
        XCTAssertTrue(cards[0].text.contains("Attendance has not been confirmed"))
        XCTAssertTrue(cards.last!.text.contains(value.sourceExcerpt))
    }

    func testMissingDetailsAreOmittedInsteadOfInvented() {
        let value = LifeEvent(title: "A meeting", person: "", place: "", occurredAt: Date(), notes: "")
        XCTAssertEqual(MemoryReplay.cards(for: value).map(\.id), ["event", "source"])
    }

    func testHidingCardsNeverHidesAttendanceOrEvidence() {
        var value = event()
        value.hiddenReplaySections = ["event", "source", "people", "notes", "place"]
        let cards = MemoryReplay.cards(for: value)
        XCTAssertEqual(cards.map(\.id), ["event", "source"])
        XCTAssertTrue(cards.allSatisfy { !$0.hideable })
        XCTAssertEqual(value.person, "Justin") // Hiding is not forgetting.
    }

    func testConfirmedEventUsesUserConfirmationNotInferredAttendance() {
        var value = event(); value.attended = true
        XCTAssertTrue(MemoryReplay.cards(for: value)[0].text.contains("You confirmed this meeting happened."))
    }

    func testOldEventWithoutReplayPreferencesStillDecodes() throws {
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoder.encode(event())) as? [String: Any])
        json.removeValue(forKey: "hiddenReplaySections")
        let decoded = try decoder.decode(LifeEvent.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.hiddenReplaySections)
        XCTAssertEqual(MemoryReplay.cards(for: decoded).count, 5)
    }
}
