import SwiftUI
import UIKit

struct ProfileHubView: View {
    @EnvironmentObject private var authService: AuthService
    let onYourDay: () -> Void
    let onIsland: () -> Void
    let onMemory: () -> Void
    let onSettings: () -> Void
    let refreshID: UUID
    @State private var photo: UIImage?
    @State private var preferredName = ""

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Text("A little space that's yours.")
                        .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    VStack(spacing: 20) {
                        portrait
                        VStack(spacing: 8) {
                            Text("Welcome, \(displayName)")
                                .font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                            Text("Your companion, shaped around you.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            hubButton("Your day", icon: "sun.horizon", action: onYourDay)
                            hubButton("Dynamic Island", icon: "capsule", action: onIsland)
                        }
                        HStack(spacing: 12) {
                            hubButton("Memory", icon: "brain", action: onMemory)
                            hubButton("Settings", icon: "slider.horizontal.3", action: onSettings)
                        }
                    }
                    Text("Remember what matters. Make room for today.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.top, 8)
                }
                .padding(.horizontal, 24).padding(.vertical, 34)
                .frame(minHeight: geometry.size.height)
            }
        }
        .onAppear(perform: reloadIdentity)
        .onChange(of: authService.currentUser) { _, _ in reloadIdentity() }
        .onChange(of: refreshID) { _, _ in reloadIdentity() }
    }

    private var portrait: some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
                    .frame(width: 144, height: 144).clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(RadialGradient(colors: [Color(hex: "#EAF9FF"), Color(hex: "#A4D8EB"), Color(hex: "#619BB6")], center: .topLeading, startRadius: 0, endRadius: 160))
                    MaxLogoView(color: .white, width: 68)
                }.frame(width: 144, height: 144)
            }
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: Color(hex: "#84B9CD").opacity(0.22), radius: 22, y: 8)
        .accessibilityHidden(true)
    }

    private func hubButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 8)
                .glassCard(cornerRadius: 26, interactive: true)
        }.buttonStyle(.plain).foregroundStyle(.primary)
    }

    private var displayName: String {
        if !preferredName.isEmpty { return preferredName }
        let name = authService.currentUser?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Guest" : name
    }
    private func reloadIdentity() {
        photo = StorageService.shared.loadProfilePhoto()
        preferredName = StorageService.shared.loadSettings().userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
