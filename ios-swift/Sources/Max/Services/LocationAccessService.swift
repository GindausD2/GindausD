import CoreLocation

@MainActor
final class LocationAccessService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationAccessService()
    private let manager = CLLocationManager()
    private var waiter: CheckedContinuation<Bool, Never>?
    private override init() { super.init(); manager.delegate = self }
    func authorize() async -> Bool {
        guard CLLocationManager.locationServicesEnabled() else { return false }
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
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self, self.manager.authorizationStatus != .notDetermined else { return }
            let status = self.manager.authorizationStatus
            self.waiter?.resume(returning: status == .authorizedAlways || status == .authorizedWhenInUse)
            self.waiter = nil
        }
    }
}
