import XCTest
@testable import Max

final class ThoughtStoreTests: XCTestCase {
    @MainActor
    func testThoughtSurvivesRelaunchAndStaysWithinAccount() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory)
        let thought = MaxThought(title: "Morning run", source: "Apple Watch", audio: Data([1, 2]))
        store.open(scope: "account-a")
        try store.save(thought)

        let reopened = ThoughtStore(directory: directory)
        reopened.open(scope: "account-b")
        XCTAssertTrue(reopened.thoughts.isEmpty)
        reopened.open(scope: "account-a")
        XCTAssertEqual(reopened.thoughts.first?.id, thought.id)
        XCTAssertEqual(reopened.thoughts.first?.audio, thought.audio)
        XCTAssertFalse(reopened.syncEnabled)

        try reopened.removeLocal(scope: "account-a")
        reopened.open(scope: "account-a")
        XCTAssertTrue(reopened.thoughts.isEmpty)
    }
}
