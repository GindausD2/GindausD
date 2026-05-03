import SwiftUI

/// Triple moon / triple goddess symbol — the Max AI logo.
/// Rendered purely with SwiftUI Canvas; no image assets needed.
///
/// Virtual canvas: 100 × 50 units
///   Left crescent  — outer cx=18 r=24, cutout cx=29 r=19  (opens right, tips kiss center ring)
///   Center ring    — outer cx=50 r=17, inner  cx=50 r=10  (thick ring)
///   Right crescent — outer cx=82 r=24, cutout cx=71 r=19  (opens left,  tips kiss center ring)
struct MaxLogoView: View {
    var color: Color = .white
    var width: CGFloat = 180

    var height: CGFloat { width * 50 / 100 }

    var body: some View {
        Canvas(opaque: false, colorMode: .linear) { context, size in
            let u = size.width / 100.0

            func circle(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(
                    x: (cx - r) * u,
                    y: (cy - r) * u,
                    width:  2 * r * u,
                    height: 2 * r * u
                ))
            }

            // ── Left crescent (opens right) ───────────────────────────────────
            context.drawLayer { ctx in
                ctx.fill(circle(cx: 18, cy: 25, r: 24), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(circle(cx: 29, cy: 25, r: 19), with: .color(.black))
            }

            // ── Center ring ───────────────────────────────────────────────────
            context.drawLayer { ctx in
                ctx.fill(circle(cx: 50, cy: 25, r: 17), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(circle(cx: 50, cy: 25, r: 10), with: .color(.black))
            }

            // ── Right crescent (opens left) ───────────────────────────────────
            context.drawLayer { ctx in
                ctx.fill(circle(cx: 82, cy: 25, r: 24), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(circle(cx: 71, cy: 25, r: 19), with: .color(.black))
            }
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    ZStack {
        Color(red: 0.18, green: 0.11, blue: 0.41)
        VStack(spacing: 32) {
            MaxLogoView(color: .white, width: 240)
            MaxLogoView(color: .white, width: 120)
            MaxLogoView(color: .white, width: 60)
        }
    }
    .ignoresSafeArea()
}
