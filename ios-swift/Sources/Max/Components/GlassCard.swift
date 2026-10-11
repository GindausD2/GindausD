import SwiftUI

enum GlassDepth {
    case ultraThin, thin, regular
    var material: Material {
        switch self { case .ultraThin: return .ultraThinMaterial; case .thin: return .thinMaterial; case .regular: return .regularMaterial }
    }
}
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var depth: GlassDepth = .thin
    var padding: EdgeInsets?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        let padded = content.if(padding != nil) { $0.padding(padding!) }
        if reduceTransparency {
            padded.background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            // Older SDKs and iOS versions retain a quiet material fallback.
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                padded.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                fallback(padded)
            }
            #else
            fallback(padded)
            #endif
        }
    }
    private func fallback<V: View>(_ content: V) -> some View {
        content
            .background(depth.material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(0.65), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 8)
    }
}
extension View {
    func glassCard(cornerRadius: CGFloat = 24, depth: GlassDepth = .thin, borderOpacity: CGFloat = 0.25, shadowRadius: CGFloat = 16, shadowOpacity: CGFloat = 0.25, padding: EdgeInsets? = nil) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, depth: depth, padding: padding))
    }
    @ViewBuilder func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var depth: GlassDepth = .thin
    var padding = EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
    @ViewBuilder var content: () -> Content
    init(cornerRadius: CGFloat = 24, depth: GlassDepth = .thin, padding: EdgeInsets = EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22), @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius; self.depth = depth; self.padding = padding; self.content = content
    }
    var body: some View { content().padding(padding).glassCard(cornerRadius: cornerRadius, depth: depth) }
}
struct GlassPillButtonStyle: ButtonStyle {
    var filled = false
    var fillColor = Color(hex: "#596F60")
    var foregroundColor = Color.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 22).padding(.vertical, 13)
            .background(filled ? fillColor.opacity(0.15) : Color.clear, in: Capsule())
            .glassCard(cornerRadius: 28)
            .foregroundStyle(foregroundColor)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
