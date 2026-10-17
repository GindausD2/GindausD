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
                VStack(spacing: 0) {
                    Text("A little more you.")
                        .font(.system(.title, design: .rounded).weight(.medium))
                        .tracking(-0.7)
                        .multilineTextAlignment(.center)
                        .padding(.top, 26)
                    Text("The things that make Max yours.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                    Spacer(minLength: 30)
                    portrait
                    Text("Welcome, \(displayName).")
                        .font(.title2.weight(.medium))
                        .tracking(-0.5)
                        .multilineTextAlignment(.center)
                        .padding(.top, 22)
                    Label(authService.currentUser?.isDemo == true ? "Seven-day demo" : "Your personal space", systemImage: "person.crop.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer(minLength: 40)
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
                    Text("Remember what matters. Leave room for today.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 28)
                        .padding(.bottom, 26)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
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
                    .frame(width: 146, height: 146).clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: "#E1F2F9"), Color(hex: "#C2E1EF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    MaxLogoView(color: Color(hex: "#376A82"), width: 62)
                }.frame(width: 146, height: 146)
            }
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
        .padding(8)
        .overlay(Circle().strokeBorder(Color(hex: "#A2C8D8").opacity(0.28), lineWidth: 0.75))
        .shadow(color: Color(hex: "#84B9CD").opacity(0.12), radius: 24, y: 10)
        .accessibilityHidden(true)
    }

    private func hubButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(.horizontal, 6)
                .glassCard(cornerRadius: 28, interactive: true)
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
