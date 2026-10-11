import CoreLocation

@MainActor
final class LocationAccessService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationAccessService()
    private let manager = CLLocationManager()
    private var waiter: CheckedContinuation<Bool, Never>?
    private override init() { super.init(); manager.delegate = self }
    func authorize() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return true
        case .notDetermined:
            guard waiter == nil else { return false }
            return await withCheckedContinuation { continuation in
                waiter = continuation
                manager.requestWhenInUseAuthorization()
            }
        default: return false
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        let allowed = manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
        waiter?.resume(returning: allowed); waiter = nil
    }
}
