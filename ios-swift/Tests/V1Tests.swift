import XCTest
import SwiftUI
import UIKit
@testable import Max

@MainActor
final class V1Tests: XCTestCase {
    private func isolated(_ body: () async throws -> Void) async rethrows {
        let previous = StorageService.shared.accountScope
        let scope = "verification-" + UUID().uuidString
        StorageService.shared.setAccountScope(scope)
        defer {
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("max.account.\(scope).") { UserDefaults.standard.removeObject(forKey: key) }
            StorageService.shared.setAccountScope(previous)
        }
        try await body()
    }

    func testMemoryIsIsolatedAndRestoredByAccount() async throws {
        await isolated {
            let store = StorageService.shared
            let a = store.accountScope
            store.saveNote(title: "Private idea", content: "Glacier ❄️")
            store.rememberFact(key: "favorite", value: "blue")
            store.saveMessages([Message(role: "user", content: "Account A", isStreaming: true)])
            store.savePlaceVisit(PlaceVisit(destination: "Office", latitude: 51.5, longitude: -0.1))
            store.saveReminder(Reminder(title: "Call David", body: "", fireDate: .distantFuture, triggerKind: "context", contextName: "Work"))
            let b = "verification-" + UUID().uuidString
            store.setAccountScope(b)
            defer { for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("max.account.\(b).") { UserDefaults.standard.removeObject(forKey: key) } }
            XCTAssertTrue(store.loadNotes().isEmpty); XCTAssertTrue(store.recallFacts().isEmpty)
            XCTAssertTrue(store.loadMessages().isEmpty); XCTAssertTrue(store.loadPlaceVisits().isEmpty)
            XCTAssertTrue(store.loadReminders().isEmpty)
            store.saveNote(title: "B", content: "Separate")
            store.setAccountScope(a)
            XCTAssertEqual(store.loadNotes().map(\.title), ["Private idea"])
            XCTAssertEqual(store.recallFacts().first?.value, "blue")
            XCTAssertEqual(store.loadMessages().first?.content, "Account A")
            XCTAssertFalse(store.loadMessages().first?.isStreaming ?? true)
            XCTAssertEqual(store.loadPlaceVisits().first?.latitude, 51.5)
            XCTAssertEqual(store.loadReminders().first?.contextName, "Work")
        }
    }

    func testOldSettingsDecodeWithoutContinuousConversation() async throws {
        var fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSettings())) as! [String: Any]
        fields.removeValue(forKey: "continuousConversation")
        fields.removeValue(forKey: "speakingHapticsEnabled")
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: fields))
        XCTAssertNil(restored.continuousConversation)
        XCTAssertTrue(restored.voiceEnabled)
        XCTAssertNil(restored.speakingHapticsEnabled)
    }

    func testOrbTapSpeaksAndSecondTapStopsWithoutSavingGreeting() async throws {
        await isolated {
            let model = HomeViewModel()
            model.loadMessages()
            model.handleOrbTap()
            XCTAssertEqual(model.conversationState, .speaking)
            XCTAssertTrue(VoiceService.shared.isSpeaking)
            XCTAssertFalse(VoiceService.shared.isRecording)
            XCTAssertTrue(model.messages.isEmpty)
            model.handleOrbTap()
            XCTAssertEqual(model.conversationState, .idle)
            XCTAssertFalse(VoiceService.shared.isSpeaking)
            XCTAssertTrue(StorageService.shared.loadMessages().isEmpty)
        }
    }

    func testHomeViewRendersOrbPreview() async throws {
        try await isolated {
            let previousOnboarding = UserDefaults.standard.object(forKey: "max:onboarding_complete")
            UserDefaults.standard.set(true, forKey: "max:onboarding_complete")
            let controller = UIHostingController(rootView: HomeView().environmentObject(AuthService.shared))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first { window.windowScene = scene }
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            defer {
                window.isHidden = true; window.rootViewController = nil
                UserDefaults.standard.set(previousOnboarding, forKey: "max:onboarding_complete")
            }
            controller.view.frame = window.bounds
            controller.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(500))
            let format = UIGraphicsImageRendererFormat(); format.scale = 2
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let data = try XCTUnwrap(image.pngData())
            XCTAssertEqual(image.size.width, 390)
            XCTAssertGreaterThan(data.count, 5000)
            let attachment = XCTAttachment(image: image)
            attachment.name = "Max glass orb native preview"; attachment.lifetime = .keepAlways
            add(attachment)
            guard ProcessInfo.processInfo.environment["MAX_EXPORT_SCREENSHOT"] == "1" else { return }
            print("MAX_ORB_SCREENSHOT_BEGIN")
            let encoded = data.base64EncodedString()
            for start in stride(from: 0, to: encoded.count, by: 6000) {
                let first = encoded.index(encoded.startIndex, offsetBy: start)
                let last = encoded.index(first, offsetBy: min(6000, encoded.count - start))
                print("MAX_ORB_SCREENSHOT_DATA " + encoded[first..<last])
            }
            print("MAX_ORB_SCREENSHOT_END")
        }
    }

    func testOldPlacesDecodeWithoutCoordinates() async throws {
        var fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(PlaceVisit(destination: "Office"))) as! [String: Any]
        fields.removeValue(forKey: "latitude"); fields.removeValue(forKey: "longitude")
        let restored = try JSONDecoder().decode(PlaceVisit.self, from: JSONSerialization.data(withJSONObject: fields))
        XCTAssertEqual(restored.destination, "Office"); XCTAssertNil(restored.latitude); XCTAssertNil(restored.longitude)
    }

    func testInvalidReminderTimesDoNotPersistOrRequestPermission() async throws {
        await isolated {
            for minutes in ["-1", "0", "nan", "inf", "9999999", "tomorrow"] {
                let result = await ToolsService.shared.execute(name: "schedule_reminder", input: ["title": "Test", "minutesFromNow": minutes])
                XCTAssertTrue(result.contains("error"))
            }
            let past = await ToolsService.shared.execute(name: "schedule_reminder", input: ["title": "Past", "fireAt": "2020-01-01T00:00:00Z"])
            XCTAssertTrue(past.contains("error")); XCTAssertTrue(StorageService.shared.loadReminders().isEmpty)
            let conflicting = await ToolsService.shared.execute(name: "schedule_reminder", input: ["title": "Test", "fireAt": "invalid", "minutesFromNow": "5"])
            XCTAssertTrue(conflicting.contains("error")); XCTAssertTrue(StorageService.shared.loadReminders().isEmpty)
        }
    }

    func testAmbiguousArrivalPlaceIsRejectedBeforePermission() async throws {
        await isolated {
            let store = StorageService.shared
            store.savePlaceVisit(PlaceVisit(destination: "Office", latitude: 51.5, longitude: -0.1))
            store.savePlaceVisit(PlaceVisit(destination: "office", latitude: 52.5, longitude: -1.1))
            let result = await ToolsService.shared.execute(name: "schedule_location_reminder", input: ["title": "Call David", "placeName": "Office"])
            XCTAssertTrue(result.contains("unique name")); XCTAssertTrue(store.loadReminders().isEmpty)
        }
    }

    func testContextReminderPersistsWithExplicitContext() async throws {
        await isolated {
            let result = await ToolsService.shared.execute(name: "schedule_context_reminder", input: ["title": "Review idea", "context": "Work"])
            XCTAssertTrue(result.contains("success"))
            let reminder = StorageService.shared.loadReminders().first
            XCTAssertEqual(reminder?.triggerKind, "context"); XCTAssertEqual(reminder?.contextName, "Work")
            let fields = (try? JSONSerialization.jsonObject(with: Data(result.utf8))) as? [String: Any]
            XCTAssertEqual(fields?["id"] as? String, reminder?.id)
            XCTAssertEqual(fields?["triggerKind"] as? String, "context")
        }
    }

    func testBookingsAreExcludedFromV1() async throws {
        for tool in ["book_uber", "book_flight"] {
            let result = await ToolsService.shared.execute(name: tool, input: [:])
            XCTAssertTrue(result.contains("not available"))
        }
    }

    func testStoppingDoesNotPersistEmptyRepliesOrStaleStreamText() async throws {
        await isolated {
            let model = HomeViewModel()
            model.loadMessages()
            model.messages = [Message(role: "user", content: "Hello"), Message(role: "assistant", content: "", isStreaming: true)]
            model.streamingText = "Stale partial"
            model.conversationState = .thinking
            model.endConversation()
            XCTAssertEqual(model.conversationState, .idle)
            XCTAssertEqual(model.streamingText, "")
            XCTAssertEqual(StorageService.shared.loadMessages().count, 1)
            XCTAssertEqual(StorageService.shared.loadMessages().first?.content, "Hello")
        }
    }

    func testStaleToolCallCannotWriteToAnotherAccount() async throws {
        await isolated {
            let result = await ToolsService.shared.execute(name: "save_note", input: ["title": "Private", "content": "Previous account"], accountScope: "previous-account")
            XCTAssertTrue(result.contains("session changed"))
            XCTAssertTrue(StorageService.shared.loadNotes().isEmpty)
        }
    }

    func testEditingSavedMemoryPreservesIdentityAndOtherItems() async throws {
        await isolated {
            let store = StorageService.shared
            let scope = store.accountScope
            let note = store.saveNote(title: "Original", content: "First draft")
            let storedNoteDate = store.loadNotes().first { $0.id == note.id }?.createdAt
            store.saveNote(title: "Keep", content: "Unrelated note")
            XCTAssertTrue(store.updateNote(id: note.id, title: "Updated", content: "New draft", accountScope: scope))
            let updated = store.loadNotes().first { $0.id == note.id }
            XCTAssertEqual(updated?.createdAt, storedNoteDate)
            XCTAssertEqual(updated?.content, "New draft")
            XCTAssertEqual(store.loadNotes().count, 2)
            XCTAssertFalse(store.updateNote(id: note.id, content: "  ", accountScope: scope))
            store.rememberFact(key: "Favorite drink", value: "Coffee")
            XCTAssertTrue(store.updateFact(key: "favorite drink", value: "Tea", accountScope: scope))
            XCTAssertEqual(store.recallFacts().first?.key, "Favorite drink")
            XCTAssertEqual(store.recallFacts().first?.value, "Tea")
            let card = MemoryCard(category: .personal, content: "Original detail")
            XCTAssertTrue(store.saveMemoryCard(card, accountScope: scope))
            let storedCardDate = store.loadMemoryCards().first?.createdAt
            XCTAssertTrue(store.updateMemoryCard(id: card.id, content: "Edited detail", category: .goals, accountScope: scope))
            XCTAssertEqual(store.loadMemoryCards().first?.id, card.id)
            XCTAssertEqual(store.loadMemoryCards().first?.createdAt, storedCardDate)
            XCTAssertEqual(store.loadMemoryCards().first?.category, .goals)
        }
    }

    func testForgottenItemsAreNotRevivedByAnOldEditor() async throws {
        await isolated {
            let store = StorageService.shared
            let scope = store.accountScope
            let note = store.saveNote(title: "Forget", content: "Draft")
            XCTAssertTrue(store.deleteNote(id: note.id, accountScope: scope))
            XCTAssertFalse(store.updateNote(id: note.id, content: "Old editor", accountScope: scope))
            store.rememberFact(key: "Favorite", value: "Blue")
            store.rememberFact(key: "Keep", value: "Separate fact")
            XCTAssertTrue(store.forgetFact(key: "FAVORITE", accountScope: scope))
            XCTAssertFalse(store.updateFact(key: "Favorite", value: "Old value", accountScope: scope))
            XCTAssertEqual(store.recallFacts().map(\.key), ["Keep"])
            let card = MemoryCard(category: .other, content: "Forget this")
            XCTAssertTrue(store.saveMemoryCard(card, accountScope: scope))
            XCTAssertTrue(store.deleteMemoryCard(id: card.id, accountScope: scope))
            XCTAssertFalse(store.updateMemoryCard(id: card.id, content: "Old editor", category: .other, accountScope: scope))
            XCTAssertTrue(store.loadNotes().isEmpty); XCTAssertTrue(store.loadMemoryCards().isEmpty)
        }
    }

    func testOldMemoryEditorCannotChangeAnotherAccountsMatchingItems() async throws {
        await isolated {
            let store = StorageService.shared
            let previousAccount = "previous-account"
            let note = store.saveNote(title: "Current account", content: "Private")
            store.rememberFact(key: "Favorite", value: "Keep this")
            let card = MemoryCard(category: .other, content: "Private card")
            XCTAssertTrue(store.saveMemoryCard(card, accountScope: store.accountScope))
            XCTAssertFalse(store.updateNote(id: note.id, content: "Wrong account", accountScope: previousAccount))
            XCTAssertFalse(store.deleteNote(id: note.id, accountScope: previousAccount))
            XCTAssertFalse(store.updateFact(key: "Favorite", value: "Wrong account", accountScope: previousAccount))
            XCTAssertFalse(store.forgetFact(key: "Favorite", accountScope: previousAccount))
            XCTAssertFalse(store.updateMemoryCard(id: card.id, content: "Wrong account", category: .people, accountScope: previousAccount))
            XCTAssertFalse(store.deleteMemoryCard(id: card.id, accountScope: previousAccount))
            XCTAssertFalse(store.saveMemoryCard(MemoryCard(category: .other, content: "Wrong account"), accountScope: previousAccount))
            XCTAssertEqual(store.loadNotes().first?.content, "Private")
            XCTAssertEqual(store.recallFacts().first?.value, "Keep this")
            XCTAssertEqual(store.loadMemoryCards().first?.content, "Private card")
        }
    }

    func testReminderConfirmationUsesLocalDatePlaceAndExplicitContext() async throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-12T23:30:00Z"))
        let zone = try XCTUnwrap(TimeZone(identifier: "Africa/Lagos"))
        let time = Reminder(title: "Call David", body: "", fireDate: date)
        let summary = time.triggerSummary(locale: Locale(identifier: "en_GB"), timeZone: zone)
        XCTAssertTrue(summary.contains("13 Oct 2026"), summary)
        XCTAssertTrue(summary.contains("00:30"), summary)
        let place = PlaceVisit(destination: "Office", note: "Bauchi", latitude: 10.3, longitude: 9.8)
        let arrival = Reminder(title: "Call", body: "Arriving at Office", fireDate: .distantFuture, triggerKind: "location", placeID: place.id)
        XCTAssertEqual(arrival.triggerSummary(place: place), "When iOS detects arrival at Office")
        let context = Reminder(title: "Review", body: "", fireDate: .distantFuture, triggerKind: "context", contextName: "Work")
        XCTAssertEqual(context.triggerSummary(), "When you check Work in Max")
    }
}
