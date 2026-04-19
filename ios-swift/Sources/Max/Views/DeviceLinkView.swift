import SwiftUI
import WatchConnectivity

// MARK: - DeviceLinkService

@MainActor
final class DeviceLinkService: NSObject, ObservableObject {
    static let shared = DeviceLinkService()

    @Published var watchPaired: Bool = false
    @Published var watchReachable: Bool = false
    @Published var iCloudEnabled: Bool = false

    private override init() {
        super.init()
        checkiCloud()
        if WCSession.isSupported() {
            let s = WCSession.default
            s.delegate = self
            s.activate()
        }
    }

    func checkiCloud() {
        iCloudEnabled = FileManager.default.ubiquityIdentityToken != nil
    }

    func enableiCloudSync() {
        // Push current settings + memories to iCloud KV store
        let storage = StorageService.shared
        let settings = storage.loadSettings()
        let kv = NSUbiquitousKeyValueStore.default
        if let data = try? JSONEncoder().encode(settings) {
            kv.set(data, forKey: "max:settings")
        }
        let cards = storage.loadMemoryCards()
        if let data = try? JSONEncoder().encode(cards) {
            kv.set(data, forKey: "max:memorycards")
        }
        kv.synchronize()
        iCloudEnabled = true
    }
}

extension DeviceLinkService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.watchPaired     = session.isPaired
            self.watchReachable  = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.watchReachable = session.isReachable
        }
    }
}

// MARK: - DeviceLinkView

struct DeviceLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var linkService = DeviceLinkService.shared

    private let violet = Color(hex: "#7C3AED")

    var body: some View {
        ZStack(alignment: .top) {
            // Liquid glass background
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.98, green: 0.97, blue: 1.00), location: 0.0),
                    .init(color: Color(red: 0.95, green: 0.93, blue: 1.00), location: 0.5),
                    .init(color: Color(red: 0.91, green: 0.87, blue: 1.00), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(violet.opacity(0.07))
                .frame(width: 260)
                .blur(radius: 60)
                .offset(x: 100, y: -40)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Subtitle
                        Text("Access Max on your other Apple devices without needing your iPhone nearby.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)

                        // Device rows
                        VStack(spacing: 12) {
                            deviceRow(
                                icon: "laptopcomputer",
                                iconColor: Color(hex: "#3B82F6"),
                                name: "MacBook",
                                description: "Access Max from macOS via iCloud sync",
                                status: linkService.iCloudEnabled ? .connected : .available,
                                action: { linkService.enableiCloudSync() }
                            )
                            deviceRow(
                                icon: "ipad",
                                iconColor: Color(hex: "#10B981"),
                                name: "iPad",
                                description: "Sync your memories and settings to iPad",
                                status: linkService.iCloudEnabled ? .connected : .available,
                                action: { linkService.enableiCloudSync() }
                            )
                            deviceRow(
                                icon: "applewatch",
                                iconColor: Color(hex: "#7C3AED"),
                                name: "Apple Watch",
                                description: linkService.watchPaired
                                    ? (linkService.watchReachable ? "Watch is nearby and reachable" : "Watch paired — out of range")
                                    : "No Apple Watch paired with this iPhone",
                                status: linkService.watchReachable ? .connected
                                    : (linkService.watchPaired ? .paired : .unavailable),
                                action: nil
                            )
                        }
                        .padding(.horizontal, 16)

                        // iCloud note
                        HStack(spacing: 8) {
                            Image(systemName: "icloud.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#3B82F6").opacity(0.8))
                            Text("Mac and iPad sync uses your iCloud account.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)

                        Spacer().frame(height: 32)
                    }
                    .padding(.top, 16)
                }
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color.white.opacity(0.55))
            VStack {
                LinearGradient(colors: [.white.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 2)
                Spacer()
            }
            VStack {
                Spacer()
                LinearGradient(colors: [violet.opacity(0.18), violet.opacity(0.06)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 0.5)
            }

            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.28))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                Spacer()
            }

            HStack {
                Button { dismiss() } label: {
                    ZStack {
                        Circle().fill(.ultraThinMaterial).frame(width: 30, height: 30)
                        Circle().fill(Color.white.opacity(0.52)).frame(width: 30, height: 30)
                        Circle().strokeBorder(LinearGradient(
                            colors: [Color.white.opacity(0.80), Color.black.opacity(0.08)],
                            startPoint: .top, endPoint: .bottom
                        ), lineWidth: 1).frame(width: 30, height: 30)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .shadow(color: .black.opacity(0.09), radius: 6, y: 3)
                }
                .padding(.leading, 16).padding(.top, 4)

                Spacer()
                Text("Connect Devices")
                    .font(.headline.weight(.semibold))
                    .padding(.top, 4)
                Spacer()

                Color.clear.frame(width: 30, height: 30)
                    .padding(.trailing, 16).padding(.top, 4)
            }
        }
        .frame(height: 50)
        .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
    }

    // MARK: - Device Row

    enum ConnectionStatus { case connected, paired, available, unavailable }

    @ViewBuilder
    private func deviceRow(icon: String, iconColor: Color, name: String,
                           description: String, status: ConnectionStatus,
                           action: (() -> Void)?) -> some View {
        HStack(spacing: 14) {
            // Icon medallion
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Status badge / button
            statusBadge(status: status, action: action)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.62))
                }
                .overlay {
                    VStack {
                        LinearGradient(colors: [.white.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 24)
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(LinearGradient(
                            colors: [.white.opacity(0.85), Color.black.opacity(0.06)],
                            startPoint: .top, endPoint: .bottom
                        ), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        }
    }

    @ViewBuilder
    private func statusBadge(status: ConnectionStatus, action: (() -> Void)?) -> some View {
        switch status {
        case .connected:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hex: "#10B981"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#10B981").opacity(0.12), in: Capsule())

        case .paired:
            Label("Paired", systemImage: "link.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(violet)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(violet.opacity(0.10), in: Capsule())

        case .available:
            if let action {
                Button(action: action) {
                    Text("Connect")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(violet)
                                .overlay {
                                    Capsule().fill(LinearGradient(
                                        colors: [.white.opacity(0.25), .clear],
                                        startPoint: .top, endPoint: .center
                                    ))
                                }
                                .overlay {
                                    Capsule().strokeBorder(LinearGradient(
                                        colors: [.white.opacity(0.5), violet.opacity(0.2)],
                                        startPoint: .top, endPoint: .bottom
                                    ), lineWidth: 1)
                                }
                                .shadow(color: violet.opacity(0.40), radius: 8, y: 4)
                        }
                }
                .buttonStyle(.plain)
            }

        case .unavailable:
            Label("Unavailable", systemImage: "xmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.10), in: Capsule())
        }
    }
}

// MARK: - Preview

#Preview {
    DeviceLinkView()
}
