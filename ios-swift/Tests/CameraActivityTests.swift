import XCTest
@testable import Max

final class CameraActivityTests: XCTestCase {
    func testResultIsBoundedAndCameraTakesPrecedenceOverAnEmailBadge() throws {
        let photo = UUID()
        let card = MaxActivityAttributes.ContentState.CameraCard(
            stage: .result, result: String(repeating: "🐈", count: 500), thumbnail: photo
        )
        let state = MaxActivityAttributes.ContentState(
            phase: .idle, snippet: "", emailAlert: .init(count: 1, latestFrom: "", latestSubject: ""), camera: card
        )
        let data = try JSONEncoder().encode(state)
        XCTAssertLessThan(data.count, 4096)
        XCTAssertEqual(state.statusLabel, "Identification ready")
        XCTAssertEqual(state.statusSymbol, "checkmark.circle.fill")
        XCTAssertEqual(state.camera?.result?.unicodeScalars.count, 160)
        XCTAssertEqual(try JSONDecoder().decode(MaxActivityAttributes.ContentState.self, from: data), state)
    }

    func testExistingActivityStateCanStillDecode() throws {
        let data = Data(#"{"phase":"idle","snippet":""}"#.utf8)
        let state = try JSONDecoder().decode(MaxActivityAttributes.ContentState.self, from: data)
        XCTAssertNil(state.camera)
        XCTAssertEqual(state.statusLabel, "Ready")
    }

    @MainActor
    func testCameraLinkWaitsForForegroundAndConsumesOnce() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        MaxShortcutRequest.enqueue(.camera, defaults: defaults, notify: false)
        XCTAssertNil(MaxShortcutRequest.takePending(canEnterHome: true, isActive: false, defaults: defaults))
        XCTAssertNil(MaxShortcutRequest.takePending(canEnterHome: false, isActive: true, defaults: defaults))
        XCTAssertEqual(MaxShortcutRequest.takePending(canEnterHome: true, isActive: true, defaults: defaults), .camera)
        XCTAssertNil(MaxShortcutRequest.takePending(canEnterHome: true, isActive: true, defaults: defaults))
    }
}
