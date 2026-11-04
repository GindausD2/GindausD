import XCTest
import UserNotifications
@testable import Max

@MainActor
final class KeepOnTrackTests: XCTestCase {
    private func isolated(_ body: (String) async throws -> Void) async rethrows {
        let storage = StorageService.shared, previous = StorageService.shared.accountScope
        let scope = "on-track-" + UUID().uuidString
        storage.setAccountScope(scope)
        defer {
            ReminderApprovalService.shared.cancel()
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("max.account.\(scope).") { UserDefaults.standard.removeObject(forKey: key) }
            storage.setAccountScope(previous)
        }
        try await body(scope)
    }

    private func pending(_ service: ReminderApprovalService) async {
        for _ in 0..<100 {
            if service.pending != nil { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Expected a reminder review")
    }

    func testModelReminderHasNoSideEffectUntilExplicitConfirmation() async throws {
        await isolated { scope in
            let service = ReminderApprovalService.shared
            let task = Task { await ToolsService.shared.execute(name: "schedule_context_reminder", input: ["title": "Post about Max", "context": "Work"], accountScope: scope, requireReminderConfirmation: true) }
            await pending(service)
            XCTAssertTrue(StorageService.shared.loadReminders().isEmpty)
            XCTAssertEqual(service.pending?.reminder.title, "Post about Max")
            if let id = service.pending?.id { service.resolve(id: id, approved: true) }
            let result = await task.value
            XCTAssertTrue(result.contains("success"))
            XCTAssertEqual(StorageService.shared.loadReminders().count, 1)
        }
    }

    func testCancellingTimeReminderDoesNotScheduleOrPersist() async throws {
        await isolated { scope in
            let service = ReminderApprovalService.shared
            let task = Task { await ToolsService.shared.execute(name: "schedule_reminder", input: ["title": "Post", "fireAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))], accountScope: scope, requireReminderConfirmation: true) }
            await pending(service)
            XCTAssertTrue(service.pending?.detail.contains(TimeZone.current.identifier) == true)
            service.cancel()
            let result = await task.value
            XCTAssertTrue(result.contains("cancelled"))
            XCTAssertTrue(StorageService.shared.loadReminders().isEmpty)
        }
    }

    func testCancelledApprovalAndOldAccountCannotApproveLater() async throws {
        await isolated { scope in
            let service = ReminderApprovalService()
            let reminder = Reminder(title: "Private", body: "", fireDate: Date().addingTimeInterval(3600))
            let task = Task { await service.confirm(reminder, detail: "A future time", scope: scope) }
            await pending(service)
            let id = service.pending!.id
            StorageService.shared.setAccountScope("signed-out")
            service.resolve(id: id, approved: true)
            let result = await task.value
            XCTAssertFalse(result)
            StorageService.shared.setAccountScope(scope)
            let cancelled = Task { await service.confirm(reminder, detail: "Later", scope: scope) }
            await pending(service); cancelled.cancel()
            let cancelledResult = await cancelled.value
            XCTAssertFalse(cancelledResult); XCTAssertNil(service.pending)
            service.resolve(id: id, approved: true) // Old sheet is harmless.
        }
    }

    func testThreePrioritiesAreDayAndAccountScoped() async throws {
        await isolated { scope in
            let store = StorageService.shared
            let day = "2026-11-4"
            let values = (1...3).map { DailyPriority(title: "Priority \($0)", day: day) }
            XCTAssertTrue(store.savePriorities(values, day: day, accountScope: scope))
            XCTAssertFalse(store.savePriorities(values + [DailyPriority(title: "Fourth", day: day)], day: day, accountScope: scope))
            XCTAssertEqual(store.loadPriorities(day: day).count, 3)
            XCTAssertTrue(store.loadPriorities(day: "2026-11-5").isEmpty)
            store.setAccountScope("signed-out")
            XCTAssertTrue(store.loadPriorities(day: day).isEmpty)
            XCTAssertFalse(store.savePriorities([], day: day, accountScope: scope))
        }
    }

    func testPauseMemoryPreventsToolWritesAndRecallWithoutDeletingExistingFacts() async throws {
        await isolated { scope in
            let store = StorageService.shared
            store.rememberFact(key: "Private", value: "Existing fact")
            store.setMemoryEnabled(false, accountScope: scope)
            let write = await ToolsService.shared.execute(name: "remember_fact", input: ["key": "New", "value": "Do not save"])
            let recall = await ToolsService.shared.execute(name: "recall_facts", input: [:])
            XCTAssertTrue(write.contains("paused")); XCTAssertFalse(recall.contains("Existing fact"))
            XCTAssertEqual(store.recallFacts().count, 1)
            store.setMemoryEnabled(true, accountScope: scope)
            XCTAssertTrue(store.usesSavedMemory)
            XCTAssertEqual(store.recallFacts().first?.value, "Existing fact")
        }
    }

    func testVocabularyValidationPersistenceAndAccountIsolation() async throws {
        await isolated { scope in
            let store = StorageService.shared
            XCTAssertTrue(store.saveVocabulary(["Gindaus", "TeemFlow", "Ọlá"], accountScope: scope))
            XCTAssertEqual(store.loadVocabulary(), ["Gindaus", "TeemFlow", "Ọlá"])
            for words in [["Gindaus", "gindaus"], ["bad\nword"], ["<tag>"], [String(repeating: "x", count: 65)], (1...26).map { "Word \($0)" }] {
                XCTAssertFalse(store.saveVocabulary(words, accountScope: scope))
            }
            store.setAccountScope("signed-out")
            XCTAssertTrue(store.loadVocabulary().isEmpty)
            XCTAssertFalse(store.saveVocabulary([], accountScope: scope))
        }
    }

    func testRescheduleReplacesSameIdentifierOnlyAfterSchedulingSucceeds() async throws {
        await isolated { scope in
            let store = StorageService.shared
            let original = Reminder(title: "Post about Max", body: "On X", fireDate: Date().addingTimeInterval(-60))
            store.saveReminder(original)
            let date = Date().addingTimeInterval(3600)
            let failed = await ReminderActions.reschedule(original, to: date, scope: scope, schedule: { _ in throw URLError(.notConnectedToInternet) })
            XCTAssertNotNil(failed); XCTAssertEqual(store.loadReminders().first?.fireDate.timeIntervalSince1970 ?? 0, original.fireDate.timeIntervalSince1970, accuracy: 1)
            let success = await ReminderActions.reschedule(original, to: date, scope: scope, schedule: { request in
                XCTAssertEqual(request.identifier, original.id)
                XCTAssertEqual(request.content.title, original.title)
                XCTAssertNotNil(request.trigger as? UNTimeIntervalNotificationTrigger)
            })
            XCTAssertNil(success)
            XCTAssertEqual(store.loadReminders().count, 1)
            XCTAssertEqual(store.loadReminders().first?.fireDate.timeIntervalSince1970 ?? 0, date.timeIntervalSince1970, accuracy: 1)
            XCTAssertTrue(ReminderActions.complete(original, scope: scope))
            XCTAssertNotNil(store.loadReminders().first?.completedAt)
            let completed = await ReminderActions.reschedule(original, to: date, scope: scope, schedule: { _ in XCTFail("Completed item must not schedule") })
            XCTAssertNotNil(completed)
        }
    }
}
