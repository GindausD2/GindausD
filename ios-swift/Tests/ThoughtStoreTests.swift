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

    @MainActor
    func testAlertPersistsAndCancelsAcrossRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var cancelled: [UUID] = []
        let store = ThoughtStore(directory: directory, scheduleAlert: { _ in })
        let thoughtID = UUID()
        store.open(scope: "a")
        try await store.scheduleAlert(for: thoughtID, kind: .alarm, date: .now.addingTimeInterval(60), scope: "a")
        let alert = try XCTUnwrap(store.alert(for: thoughtID, kind: .alarm))

        let reopened = ThoughtStore(directory: directory, cancelAlert: { cancelled.append($0.id) })
        reopened.open(scope: "b")
        XCTAssertNil(reopened.alert(for: thoughtID, kind: .alarm))
        reopened.open(scope: "a")
        XCTAssertEqual(reopened.alert(for: thoughtID, kind: .alarm), alert)
        try reopened.cancelAlert(alert)
        XCTAssertEqual(cancelled, [alert.id])
        XCTAssertNil(reopened.alert(for: thoughtID, kind: .alarm))
    }

    @MainActor
    func testFailedScheduleDoesNotShowAnActiveAlert() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, scheduleAlert: { _ in
            throw ThoughtAlertError.notificationPermission
        }, cancelAlert: { _ in })
        let thoughtID = UUID()
        store.open(scope: "a")
        do {
            try await store.scheduleAlert(for: thoughtID, kind: .reminder, date: .now.addingTimeInterval(60), scope: "a")
            XCTFail("A denied system alert cannot be confirmed")
        } catch ThoughtAlertError.notificationPermission {}
        XCTAssertNil(store.alert(for: thoughtID, kind: .reminder))
    }
}
