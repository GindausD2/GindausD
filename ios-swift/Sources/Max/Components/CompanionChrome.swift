import SwiftUI

struct CompanionCanvas: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: "#121A20"), Color(hex: "#1E2B34"), Color(hex: "#223640")]
                : [Color(hex: "#F8FBFC"), Color(hex: "#EEF5F7"), Color(hex: "#E8F0F3")],
            startPoint: .top, endPoint: .bottom
        ).ignoresSafeArea()
    }
}

struct CompanionSheetHeader: View {
    let title: String
    let onClose: () -> Void
    var onAdd: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Capsule().fill(Color.secondary.opacity(0.25)).frame(width: 34, height: 4)
                .accessibilityHidden(true)
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .glassCard(cornerRadius: 22, interactive: true)
                }
                .accessibilityLabel("Close \(title)")
                Spacer()
                Text(title).font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .glassCard(cornerRadius: 20)
                Spacer()
                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .glassCard(cornerRadius: 22, interactive: true)
                    }
                    .accessibilityLabel("Add saved memory")
                } else { Color.clear.frame(width: 44, height: 44).accessibilityHidden(true) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 14)
    }
}
