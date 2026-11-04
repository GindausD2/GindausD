import SwiftUI

private struct MaxBrandNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var maxBrandNamespace: Namespace.ID? {
        get { self[MaxBrandNamespaceKey.self] }
        set { self[MaxBrandNamespaceKey.self] = newValue }
    }
}

/// One artwork identity travels from entry to the home header.
struct MaxJourneyLogo: View {
    var width: CGFloat
    @Environment(\.maxBrandNamespace) private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        artwork
            .frame(width: width, height: width * MaxLogoView.aspectRatio)
            .accessibilityLabel("Max")
    }

    @ViewBuilder private var artwork: some View {
        if let namespace, !reduceMotion {
            Image("MaxLogo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .matchedGeometryEffect(id: "max.entry.logo", in: namespace)
        } else {
            Image("MaxLogo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
        }
    }
}

struct MaxEntryBrand: View {
    var width: CGFloat = 220

    var body: some View {
        VStack(spacing: 14) {
            MaxJourneyLogo(width: width)
            Text("Max")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Max")
    }
}

/// Displayed only while the real saved session is restored; no timed splash.
struct MaxBrandOpeningView: View {
    var body: some View {
        ZStack {
            CompanionCanvas()
            MaxEntryBrand()
        }
    }
}

struct EntryHero: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var logoWidth: CGFloat = 204
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 14) {
            MaxEntryBrand(width: typeSize.isAccessibilitySize ? 136 : logoWidth)
                .padding(.vertical, 8)
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
