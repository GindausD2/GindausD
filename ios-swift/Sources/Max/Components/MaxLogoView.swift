import SwiftUI

/// The approved glacier-blue glass artwork, shared by the app and extensions.
/// Original rendering preserves its colors, ring opening and detached curve.
struct MaxLogoView: View {
    var width: CGFloat = 180
    static let aspectRatio: CGFloat = 930.0 / 1691.0

    var body: some View {
        Image("MaxLogo")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: width, height: width * Self.aspectRatio)
            .accessibilityLabel("Max")
    }
}
