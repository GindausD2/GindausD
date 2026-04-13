import SwiftUI

// MARK: - GlassCard ViewModifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var borderOpacity: CGFloat
    var shadowRadius: CGFloat
    var shadowOpacity: CGFloat
    var padding: EdgeInsets?

    func body(content: Content) -> some View {
        content
            .if(padding != nil) { view in
                view.padding(padding!)
            }
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius * 0.3
            )
    }
}

// MARK: - View Extension

extension View {
    func glassCard(
        cornerRadius: CGFloat = 20,
        borderOpacity: CGFloat = 0.25,
        shadowRadius: CGFloat = 16,
        shadowOpacity: CGFloat = 0.25,
        padding: EdgeInsets? = nil
    ) -> some View {
        modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            borderOpacity: borderOpacity,
            shadowRadius: shadowRadius,
            shadowOpacity: shadowOpacity,
            padding: padding
        ))
    }

    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - GlassCard View (standalone container)

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: EdgeInsets
    @ViewBuilder var content: () -> Content

    init(
        cornerRadius: CGFloat = 20,
        padding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .glassCard(cornerRadius: cornerRadius)
    }
}

// MARK: - Pill Button Style

struct GlassPillButtonStyle: ButtonStyle {
    var filled: Bool = false
    var fillColor: Color = Color.white.opacity(0.25)
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(filled ? fillColor : Color.white.opacity(0.12))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.75)
                    )
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.11, blue: 0.41),
                Color(red: 0.31, green: 0.27, blue: 0.90),
                Color(red: 0.49, green: 0.23, blue: 0.93)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassCard {
                VStack(spacing: 12) {
                    Text("Glass Card")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Using .ultraThinMaterial")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Button("Pill Button") {}
                .buttonStyle(GlassPillButtonStyle())

            Button("Filled Pill") {}
                .buttonStyle(GlassPillButtonStyle(filled: true))
        }
        .padding(32)
    }
}
