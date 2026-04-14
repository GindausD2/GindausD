import SwiftUI

/// Triple moon / triple goddess symbol — the Max AI logo.
/// Rendered purely with SwiftUI Canvas; no image assets needed.
///
/// Layout (100 × 44 virtual units):
///   Left crescent  — large circle cx=15 r=21, inner circle cx=24 r=16 (offset right → opens right)
///   Center ring    — outer circle cx=50 r=14, inner circle cx=50 r=9
///   Right crescent — large circle cx=85 r=21, inner circle cx=76 r=16 (offset left → opens left)
struct MaxLogoView: View {
    var color: Color = .white
    var width: CGFloat = 180

    var height: CGFloat { width * 44 / 100 }

    var body: some View {
        Canvas(opaque: false, colorMode: .linear) { context, size in
            let u = size.width / 100.0

            func ellipse(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(
                    x: (cx - r) * u,
                    y: (cy - r) * u,
                    width:  2 * r * u,
                    height: 2 * r * u
                ))
            }

            // ── Left crescent ─────────────────────────────────────────────────
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 15, cy: 22, r: 21), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 24, cy: 22, r: 16), with: .color(.black))
            }

            // ── Center ring ───────────────────────────────────────────────────
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 50, cy: 22, r: 14), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 50, cy: 22, r:  9), with: .color(.black))
            }

            // ── Right crescent ────────────────────────────────────────────────
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 85, cy: 22, r: 21), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 76, cy: 22, r: 16), with: .color(.black))
            }
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    ZStack {
        Color(red: 0.18, green: 0.11, blue: 0.41)
        MaxLogoView(color: .white, width: 240)
    }
    .ignoresSafeArea()
}
