import XCTest
import SwiftUI
import UIKit
@testable import Max

@MainActor
final class ScreenshotTests: XCTestCase {
    func testUpdatedScreensWithSampleData() async throws {
        guard ProcessInfo.processInfo.environment["MAX_EXPORT_UPDATED_UI"] == "1" else { throw XCTSkip("Screenshots not requested") }
        let previous = StorageService.shared.accountScope
        let scope = "screenshot-" + UUID().uuidString
        StorageService.shared.setAccountScope(scope)
        defer {
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("max.account.\(scope).") { UserDefaults.standard.removeObject(forKey: key) }
            StorageService.shared.setAccountScope(previous)
        }
        let fact = UserMemory(key: "Morning routine", value: "I like a quiet start, tea, and a short plan for the day.", updatedAt: Date())
        StorageService.shared.rememberFact(key: fact.key, value: fact.value)
        try await capture(SavedMemoryEditor(target: .fact(fact), accountScope: scope, onSave: {}), name: "Max_Memory_Editor")
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-13T19:00:00Z"))
        let zone = try XCTUnwrap(TimeZone(identifier: "Africa/Lagos"))
        let reminder = Reminder(title: "Call David", body: "", fireDate: date)
        try await capture(ReminderConfirmationView(reminder: reminder, places: [], timeZone: zone, onDone: {}), name: "Max_Reminder_Confirmation")

        let onboarding = UserDefaults.standard.object(forKey: "max:onboarding_complete")
        UserDefaults.standard.set(true, forKey: "max:onboarding_complete")
        defer { UserDefaults.standard.set(onboarding, forKey: "max:onboarding_complete") }
        try await capture(WelcomeView(initialMode: .login).environmentObject(AuthService.shared), name: "Max_Glass_Slider_Login")
        try await capture(WelcomeView(initialMode: .signUp).environmentObject(AuthService.shared), name: "Max_Glass_Slider_Signup")
        try await capture(HomeView().environmentObject(AuthService.shared), name: "Max_Profile_Design_Home")
        try await capture(HomeView().environmentObject(AuthService.shared), name: "Max_Reference_Home_Dark", style: .dark)
        try await capture(HomeView().environmentObject(AuthService.shared), name: "Max_Reference_Home_Compact", size: CGSize(width: 375, height: 667))
        try await capture(HomeView().environmentObject(AuthService.shared).environment(\.dynamicTypeSize, .accessibility1), name: "Max_Reference_Home_Large_Text")
        try await capture(HomeView().environmentObject(AuthService.shared).environment(\.accessibilityReduceTransparency, true).environment(\.accessibilityReduceMotion, true), name: "Max_Reference_Home_Accessibility")
        try await capture(HomeView(initialPage: .profile).environmentObject(AuthService.shared), name: "Max_Profile_Design_Profile")
        try await capture(MemoryView(), name: "Max_Profile_Design_Memory_Empty")
        XCTAssertTrue(StorageService.shared.saveMemoryCard(MemoryCard(category: .personal, content: "I like quiet mornings, a cup of tea, and a little time to plan my day."), accountScope: scope))
        try await capture(MemoryView(), name: "Max_Profile_Design_Memory_Saved")
        try await capture(SettingsView().environmentObject(AuthService.shared), name: "Max_Profile_Design_Settings")
        try await capture(IslandOverviewView(), name: "Max_Profile_Design_Island")
        let voiceCapture = TestVoiceCapture()
        let model = HomeViewModel(capture: voiceCapture)
        model.loadMessages()
        model.handleMicTap()
        try await Task.sleep(for: .milliseconds(50))
        voiceCapture.text = "Remind me to call David tomorrow at eight."
        voiceCapture.result = voiceCapture.text
        try await capture(HomeView(viewModel: model).environmentObject(AuthService.shared), name: "Max_Profile_Design_Voice")
        model.endConversation()
        let draftCapture = TestVoiceCapture()
        let draftModel = HomeViewModel(capture: draftCapture)
        draftModel.loadMessages()
        draftModel.handleMicTap()
        try await Task.sleep(for: .milliseconds(50))
        draftCapture.text = "Remind me to call David tomorrow at eight."
        draftCapture.result = draftCapture.text
        draftModel.handleMicTap()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(draftModel.prefersTextReplyForDraft)
        try await capture(HomeView(viewModel: draftModel).environmentObject(AuthService.shared), name: "Max_Profile_Design_Draft")
        StorageService.shared.saveMessages([
            Message(role: "user", content: "Help me make a little room in my day."),
            Message(role: "assistant", content: "Let's start small. What's the one thing you'd like to finish today? We can build the rest around it.")
        ])
        try await capture(HomeView().environmentObject(AuthService.shared), name: "Max_Reference_Conversation")
    }

    private func capture<Content: View>(_ content: Content, name: String, style: UIUserInterfaceStyle = .light, size: CGSize = CGSize(width: 390, height: 844)) async throws {
        let controller = UIHostingController(rootView: content)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first { window.windowScene = scene }
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.94))
        XCTAssertEqual(image.size.width, size.width); XCTAssertGreaterThan(data.count, 5000)
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let encoded = data.base64EncodedString()
        for start in stride(from: 0, to: encoded.count, by: 6000) {
            let first = encoded.index(encoded.startIndex, offsetBy: start)
            let last = encoded.index(first, offsetBy: min(6000, encoded.count - start))
            print("MAX_UI_IMAGE " + name + " " + encoded[first..<last])
        }
        print("MAX_UI_IMAGE_END " + name)
    }
}
