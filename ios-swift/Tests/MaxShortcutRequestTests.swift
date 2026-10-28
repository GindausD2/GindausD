import XCTest
@testable import Max

@MainActor
final class MaxShortcutRequestTests: XCTestCase {
    private func isolated(_ body: (UserDefaults) -> Void) {
        let name = "max-shortcut-test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(defaults)
    }

    func testIslandWaitsForAccessAndForegroundThenRunsOnlyOnce() {
        isolated { defaults in
            MaxShortcutRequest.enqueue(.island, defaults: defaults, notify: false)
            XCTAssertNil(MaxShortcutRequest.takePending(canEnterHome: false, isActive: true, defaults: defaults))
            XCTAssertNil(MaxShortcutRequest.takePending(canEnterHome: true, isActive: false, defaults: defaults))
            XCTAssertEqual(MaxShortcutRequest.takePending(canEnterHome: true, isActive: true, defaults: defaults), .island)
            XCTAssertNil(MaxShortcutRequest.takePending(canEnterHome: true, isActive: true, defaults: defaults))
        }
    }

    func testInitialLoginPreservesRequestButExistingAccountChangeClearsIt() {
        isolated { defaults in
            MaxShortcutRequest.enqueue(.voice, defaults: defaults, notify: false)
            MaxShortcutRequest.accountDidChange(hadPreviousUser: false, defaults: defaults)
            XCTAssertEqual(MaxShortcutRequest.takePending(canEnterHome: true, isActive: true, defaults: defaults), .voice)
            for action in [MaxShortcutRequest.Action.voice, .island] {
                MaxShortcutRequest.enqueue(action, defaults: defaults, notify: false)
                MaxShortcutRequest.accountDidChange(hadPreviousUser: true, defaults: defaults)
                XCTAssertNil(MaxShortcutRequest.takePending(canEnterHome: true, isActive: true, defaults: defaults))
            }
        }
    }

    func testLatestExplicitRequestReplacesEarlierRequestWithoutOpeningMicrophone() {
        isolated { defaults in
            MaxShortcutRequest.enqueue(.voice, defaults: defaults, notify: false)
            MaxShortcutRequest.enqueue(.island, defaults: defaults, notify: false)
            XCTAssertEqual(MaxShortcutRequest.takePending(canEnterHome: true, isActive: true, defaults: defaults), .island)
            MaxShortcutRequest.enqueue(.voice, defaults: defaults, notify: false)
            XCTAssertEqual(MaxShortcutRequest.takePending(canEnterHome: true, isActive: true, defaults: defaults), .voice)
        }
    }
}
