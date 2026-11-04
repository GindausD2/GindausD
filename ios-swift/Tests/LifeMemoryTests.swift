import XCTest
@testable import Max

@MainActor
final class LifeMemoryTests: XCTestCase {
    private func isolated(_ body: (String) async throws -> Void) async rethrows {
        let store = StorageService.shared, previous = StorageService.shared.accountScope
        let scope = "life-test-" + UUID().uuidString
        store.setAccountScope(scope)
        defer {
            LifeMemoryApproval.shared.cancel()
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("max.account.\(scope).") { UserDefaults.standard.removeObject(forKey: key) }
            store.setAccountScope(previous)
        }
        try await body(scope)
    }

    func testConfirmedMeetingIsRecalledWithSourceAndAmbiguousMatchesArePreserved() async throws {
        try await isolated { scope in
            let store = StorageService.shared
            var event = LifeEvent(title: "Max voice meeting", person: "Justin", place: "Café Grenel", occurredAt: Date().addingTimeInterval(-86400), notes: "Discussed interruptions")
            event.attended = true
            XCTAssertTrue(store.saveLifeEvent(event, scope: scope))
            XCTAssertEqual(LifeEvent.matching(store.loadLifeEvents(), query: "who did I meet at cafe Grenel").first?.person, "Justin")
            let reply = await ToolsService.shared.execute(name: "recall_life_events", input: ["query": "voice"])
            let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(reply.utf8)) as? [String: Any])
            let records = try XCTUnwrap(json["events"] as? [[String: Any]])
            XCTAssertEqual(records.first?["id"] as? String, event.id)
            XCTAssertEqual(records.first?["attendance"] as? String, "confirmed_by_user")
            XCTAssertEqual(records.first?["sourceExcerpt"] as? String, event.sourceExcerpt)
            var other = event; other.id = UUID().uuidString; other.person = "David"; other.attended = false
            XCTAssertTrue(store.saveLifeEvent(other, scope: scope))
            XCTAssertEqual(LifeEvent.matching(store.loadLifeEvents(), query: "voice").count, 2)
            XCTAssertTrue(LifeEvent.matching(store.loadLifeEvents(), query: "unrecorded person").isEmpty)
        }
    }

    func testPlannedEntryStaysUnconfirmedAndSearchDateRangeIsExclusive() {
        let date = Date(timeIntervalSince1970: 1000)
        let event = LifeEvent(title: "Meeting", person: "Justin", place: "Cafe", occurredAt: date, notes: "")
        XCTAssertFalse(event.attended)
        XCTAssertEqual(LifeEvent.matching([event], query: "", from: date, to: date.addingTimeInterval(1)).count, 1)
        XCTAssertTrue(LifeEvent.matching([event], query: "", to: date).isEmpty)
    }

    func testLargeRecallEvidenceStaysWithinBackendContinuationLimit() async throws {
        try await isolated { scope in
            let store = StorageService.shared
            for index in 0..<20 {
                var event = LifeEvent(title: "Meeting \(index)", person: "Justin", place: "Cafe", occurredAt: Date(), notes: String(repeating: "界", count: 2000))
                event.sourceExcerpt = String(repeating: "界", count: 2000)
                XCTAssertTrue(store.saveLifeEvent(event, scope: scope))
            }
            let reply = await ToolsService.shared.execute(name: "recall_life_events", input: ["query": "Meeting"])
            XCTAssertLessThan(reply.utf8.count, 24000)
            let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(reply.utf8)) as? [String: Any])
            XCTAssertEqual(json["totalMatches"] as? Int, 20)
            XCTAssertEqual(json["moreMatches"] as? Bool, true)
        }
    }

    func testEditsForgetPauseAndAccountIsolation() async throws {
        await isolated { scope in
            let store = StorageService.shared
            var event = LifeEvent(title: "Meeting", person: "Justin", place: "Cafe", occurredAt: Date(), notes: "")
            XCTAssertTrue(store.saveLifeEvent(event, scope: scope))
            event.person = "Corrected name"
            XCTAssertTrue(store.saveLifeEvent(event, scope: scope, replacing: true))
            XCTAssertEqual(store.loadLifeEvents().first?.person, "Corrected name")
            store.setMemoryEnabled(false, accountScope: scope)
            let response = await ToolsService.shared.execute(name: "recall_life_events", input: ["query": ""])
            XCTAssertTrue(response.contains("paused")); XCTAssertFalse(response.contains("Corrected name"))
            XCTAssertFalse(store.saveLifeEvent(event, scope: scope, replacing: true))
            XCTAssertTrue(store.forgetLifeEvent(id: event.id, scope: scope))
            store.setMemoryEnabled(true, accountScope: scope)
            XCTAssertFalse(store.saveLifeEvent(event, scope: scope, replacing: true))
            store.setAccountScope("signed-out")
            XCTAssertTrue(store.loadLifeEvents().isEmpty)
            XCTAssertFalse(store.saveLifeEvent(event, scope: scope))
        }
    }

    func testProposalCannotSaveWithoutReviewAndCannotCrossAccounts() async throws {
        await isolated { scope in
            let approval = LifeMemoryApproval()
            let event = LifeEvent(title: "Meeting", person: "Justin", place: "Cafe", occurredAt: Date(), notes: "")
            let task = Task { await approval.propose(event, scope: scope) }
            for _ in 0..<100 {
                if approval.pending != nil { break }
                try? await Task.sleep(for: .milliseconds(5))
            }
            XCTAssertNotNil(approval.pending)
            XCTAssertTrue(StorageService.shared.loadLifeEvents().isEmpty)
            if let id = approval.pending?.id { approval.resolve(id: id, savedID: event.id) }
            let result = await task.value
            XCTAssertNil(result)
            let pending = Task { await approval.propose(event, scope: scope) }
            for _ in 0..<100 {
                if approval.pending != nil { break }
                try? await Task.sleep(for: .milliseconds(5))
            }
            pending.cancel()
            let cancelled = await pending.value
            XCTAssertNil(cancelled)
            XCTAssertTrue(StorageService.shared.loadLifeEvents().isEmpty)
        }
    }
}
