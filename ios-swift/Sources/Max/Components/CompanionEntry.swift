import SwiftUI

struct CompanionWordmark: View {
    var body: some View {
        MaxLogoView(color: .primary, width: 82)
            .accessibilityLabel("Max")
    }
}

struct EntryHero: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var orbSize: CGFloat = 120
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 14) {
            OrbView(state: .idle, size: typeSize.isAccessibilitySize ? 86 : orbSize)
                .padding(.vertical, 8)
                .accessibilityHidden(true)
            Text(eyebrow)
                .font(.caption2.weight(.semibold))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .medium))
                .tracking(-0.8)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

struct EntryPrimaryButton: View {
    var title: String
    var isLoading = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading { ProgressView().tint(.white) }
                Text(title).fontWeight(.semibold)
                if !isLoading { Spacer(); Image(systemName: "arrow.right") }
            }
            .frame(maxWidth: .infinity, minHeight: 22)
            .padding(18)
            .foregroundStyle(.white)
            .background(LinearGradient(colors: [Color(hex: "#477D95"), Color(hex: "#2F586C")], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 0.75))
            .shadow(color: Color(hex: "#315F75").opacity(0.16), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
