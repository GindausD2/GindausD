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
}
