import SwiftUI

// MARK: - Glass Depth

enum GlassDepth {
    case ultraThin  // Barely-there overlays
    case thin       // Standard cards
    case regular    // Prominent panels & sheets

    var material: Material {
        switch self {
        case .ultraThin: return .ultraThinMaterial
        case .thin:      return .thinMaterial
        case .regular:   return .regularMaterial
        }
    }
}

// MARK: - GlassCardModifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var depth: GlassDepth = .thin
    var padding: EdgeInsets?

    func body(content: Content) -> some View {
        content
            .if(padding != nil) { v in v.padding(padding!) }
            .background(glassBackground)
            .overlay(edgeBorder)
            // Three-layer shadow system for premium depth
            .shadow(color: .black.opacity(0.06), radius: 1,  x: 0, y: 1)
            .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.12), radius: 48, x: 0, y: 24)
    }

    private var glassBackground: some View {
        ZStack {
            // 1. Material blur base
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(depth.material)
            // 2. Warm white tint
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))
            // 3. Specular top highlight — simulates light striking the upper face
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.24), location: 0.00),
                            .init(color: .white.opacity(0.09), location: 0.22),
                            .init(color: .clear,               location: 0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var edgeBorder: some View {
        // Gradient border: bright at top-left, fades to invisible at bottom-right
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.60), location: 0.00),
                        .init(color: .white.opacity(0.25), location: 0.30),
                        .init(color: .white.opacity(0.05), location: 0.70),
                        .init(color: .clear,               location: 1.00)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.0
            )
    }
}

// MARK: - View Extension

extension View {
    /// Apply liquid-glass card styling with optional internal padding.
    func glassCard(
        cornerRadius: CGFloat = 24,
        depth: GlassDepth = .thin,
        // Legacy params kept for existing call-site compatibility (not used internally)
        borderOpacity: CGFloat = 0.25,
        shadowRadius:  CGFloat = 16,
        shadowOpacity: CGFloat = 0.25,
        padding: EdgeInsets?   = nil
    ) -> some View {
        modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            depth: depth,
            padding: padding
        ))
    }

    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - GlassCard Container

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var depth: GlassDepth = .thin
    var padding: EdgeInsets = EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
    @ViewBuilder var content: () -> Content

    init(
        cornerRadius: CGFloat = 24,
        depth: GlassDepth = .thin,
        padding: EdgeInsets = EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.depth = depth
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .glassCard(cornerRadius: cornerRadius, depth: depth)
    }
}

// MARK: - GlassPillButtonStyle

struct GlassPillButtonStyle: ButtonStyle {
    var filled: Bool = false
    var fillColor: Color = Color.white.opacity(0.22)
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .background(
                ZStack {
                    // Base fill
                    Capsule().fill(filled ? fillColor : Color.white.opacity(0.10))
                    // Specular streak
                    Capsule().fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.22), location: 0),
                                .init(color: .clear, location: 0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    // Gradient edge
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
                }
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.70), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.01, blue: 0.06),
                Color(red: 0.06, green: 0.03, blue: 0.13),
                Color(red: 0.31, green: 0.23, blue: 0.90).opacity(0.3)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 24) {
            GlassCard {
                VStack(spacing: 10) {
                    Text("Liquid Glass")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Multi-layer depth · specular highlights · gradient border")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            HStack(spacing: 14) {
                Button("← Back") {}.buttonStyle(GlassPillButtonStyle())
                Button("Continue →") {}.buttonStyle(GlassPillButtonStyle(filled: true))
            }
        }
        .padding(32)
    }
}
