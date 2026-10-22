import SwiftUI

/// Max's supplied brand mark, traced from branding/Max_Logo_Reference.jpeg.
/// The detached lower-right curve and ring opening are intentional.
/// Kept in code so the app and widget share the exact same scalable artwork.
struct MaxLogoView: View {
    var color: Color = .white
    var width: CGFloat = 180
    static let aspectRatio: CGFloat = 521.524 / 1000

    var body: some View {
        MaxBrandShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: width, height: width * Self.aspectRatio)
            .accessibilityLabel("Max")
    }
}

private struct MaxBrandShape: Shape {
    private static let contours: [[CGPoint]] = [
        [CGPoint(x: 492.265, y: 0.597), CGPoint(x: 464.505, y: 3.638), CGPoint(x: 427.493, y: 11.717), CGPoint(x: 383.078, y: 28.466), CGPoint(x: 360.871, y: 40.899), CGPoint(x: 330.139, y: 61.712), CGPoint(x: 305.352, y: 83.765), CGPoint(x: 273.892, y: 120.72), CGPoint(x: 257.236, y: 105.482), CGPoint(x: 233.178, y: 86.99), CGPoint(x: 198.955, y: 67.264), CGPoint(x: 159.153, y: 49.848), CGPoint(x: 114.738, y: 36.475), CGPoint(x: 77.726, y: 29.774), CGPoint(x: 42.564, y: 29.273), CGPoint(x: 31.985, y: 32.102), CGPoint(x: 33.311, y: 36.266), CGPoint(x: 88.415, y: 67.264), CGPoint(x: 122.141, y: 90.991), CGPoint(x: 150.552, y: 115.38), CGPoint(x: 178.457, y: 146.841), CGPoint(x: 197.405, y: 176.451), CGPoint(x: 209.576, y: 206.061), CGPoint(x: 216.391, y: 239.372), CGPoint(x: 216.988, y: 267.131), CGPoint(x: 212.377, y: 296.741), CGPoint(x: 202.207, y: 326.351), CGPoint(x: 186.778, y: 355.961), CGPoint(x: 162.348, y: 389.272), CGPoint(x: 133.245, y: 419.271), CGPoint(x: 99.933, y: 447.193), CGPoint(x: 40.984, y: 487.355), CGPoint(x: 3.674, y: 507.711), CGPoint(x: 0, y: 513.263), CGPoint(x: 1.509, y: 516.965), CGPoint(x: 7.402, y: 519.388), CGPoint(x: 25.909, y: 521.524), CGPoint(x: 61.07, y: 519.398), CGPoint(x: 99.933, y: 510.845), CGPoint(x: 138.796, y: 496.902), CGPoint(x: 177.659, y: 477.445), CGPoint(x: 218.373, y: 450.865), CGPoint(x: 253.854, y: 420.732), CGPoint(x: 273.892, y: 399.201), CGPoint(x: 291.109, y: 420.732), CGPoint(x: 316.456, y: 445.065), CGPoint(x: 336.109, y: 459.595), CGPoint(x: 368.273, y: 478.172), CGPoint(x: 383.078, y: 484.498), CGPoint(x: 412.688, y: 493.717), CGPoint(x: 442.298, y: 499.359), CGPoint(x: 471.908, y: 501.391), CGPoint(x: 499.667, y: 500.709), CGPoint(x: 529.277, y: 496.752), CGPoint(x: 558.887, y: 489.457), CGPoint(x: 588.497, y: 479.239), CGPoint(x: 618.107, y: 464.83), CGPoint(x: 642.038, y: 450.342), CGPoint(x: 668.9, y: 429.985), CGPoint(x: 692.132, y: 408.121), CGPoint(x: 722.382, y: 370.766), CGPoint(x: 747.773, y: 326.351), CGPoint(x: 758.999, y: 300.442), CGPoint(x: 776.474, y: 252.326), CGPoint(x: 794.86, y: 194.957), CGPoint(x: 809.913, y: 165.347), CGPoint(x: 823.925, y: 144.99), CGPoint(x: 853.135, y: 112.614), CGPoint(x: 882.745, y: 87.926), CGPoint(x: 922.12, y: 61.712), CGPoint(x: 966.023, y: 37.354), CGPoint(x: 968.044, y: 35.804), CGPoint(x: 968.476, y: 32.102), CGPoint(x: 958.621, y: 29.398), CGPoint(x: 947.517, y: 28.849), CGPoint(x: 921.608, y: 29.823), CGPoint(x: 886.447, y: 36.498), CGPoint(x: 853.135, y: 46.223), CGPoint(x: 819.824, y: 58.943), CGPoint(x: 790.214, y: 73.591), CGPoint(x: 764.449, y: 89.472), CGPoint(x: 736.546, y: 112.4), CGPoint(x: 710.638, y: 80.738), CGPoint(x: 690.281, y: 61.243), CGPoint(x: 662.522, y: 40.637), CGPoint(x: 632.912, y: 24.937), CGPoint(x: 603.302, y: 13.507), CGPoint(x: 563.85, y: 4.343), CGPoint(x: 529.277, y: 0.176), CGPoint(x: 492.265, y: 0.597)],
        [CGPoint(x: 516.323, y: 79.866), CGPoint(x: 544.082, y: 80.919), CGPoint(x: 558.887, y: 83.155), CGPoint(x: 588.497, y: 92.721), CGPoint(x: 603.302, y: 100.09), CGPoint(x: 621.808, y: 112.913), CGPoint(x: 633.188, y: 122.783), CGPoint(x: 644.764, y: 135.737), CGPoint(x: 655.152, y: 150.542), CGPoint(x: 662.97, y: 165.347), CGPoint(x: 672.229, y: 194.957), CGPoint(x: 674.181, y: 209.762), CGPoint(x: 674.427, y: 237.521), CGPoint(x: 669.623, y: 267.131), CGPoint(x: 657.965, y: 300.442), CGPoint(x: 639.815, y: 331.903), CGPoint(x: 629.615, y: 344.857), CGPoint(x: 610.704, y: 363.889), CGPoint(x: 592.198, y: 378.545), CGPoint(x: 577.393, y: 387.968), CGPoint(x: 544.082, y: 403.298), CGPoint(x: 514.472, y: 410.758), CGPoint(x: 499.667, y: 412.482), CGPoint(x: 471.908, y: 412.662), CGPoint(x: 442.298, y: 408.134), CGPoint(x: 412.688, y: 396.859), CGPoint(x: 397.883, y: 388.515), CGPoint(x: 386.851, y: 380.019), CGPoint(x: 368.066, y: 361.513), CGPoint(x: 350.443, y: 335.604), CGPoint(x: 341.925, y: 315.247), CGPoint(x: 334.816, y: 281.936), CGPoint(x: 334.254, y: 254.177), CGPoint(x: 338.663, y: 224.74), CGPoint(x: 348.336, y: 194.957), CGPoint(x: 365.038, y: 165.347), CGPoint(x: 381.228, y: 144.286), CGPoint(x: 412.688, y: 116.327), CGPoint(x: 442.298, y: 98.951), CGPoint(x: 460.804, y: 90.947), CGPoint(x: 486.713, y: 83.501), CGPoint(x: 516.323, y: 79.866)],
        [CGPoint(x: 786.513, y: 288.376), CGPoint(x: 778.557, y: 311.546), CGPoint(x: 763.6, y: 344.857), CGPoint(x: 746.209, y: 374.467), CGPoint(x: 728.446, y: 398.525), CGPoint(x: 727.674, y: 400.376), CGPoint(x: 729.144, y: 402.027), CGPoint(x: 753.202, y: 426.743), CGPoint(x: 793.916, y: 459.627), CGPoint(x: 827.227, y: 480.479), CGPoint(x: 856.837, y: 495.157), CGPoint(x: 901.251, y: 511.711), CGPoint(x: 936.413, y: 519.245), CGPoint(x: 973.426, y: 521.428), CGPoint(x: 991.932, y: 519.466), CGPoint(x: 997.573, y: 516.965), CGPoint(x: 1000, y: 513.263), CGPoint(x: 997.484, y: 508.484), CGPoint(x: 951.218, y: 482.299), CGPoint(x: 921.608, y: 462.38), CGPoint(x: 886.447, y: 435.584), CGPoint(x: 854.314, y: 405.927), CGPoint(x: 827.012, y: 374.467), CGPoint(x: 812.245, y: 352.259), CGPoint(x: 797.522, y: 322.65), CGPoint(x: 786.513, y: 288.376)]
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for contour in Self.contours {
            guard let first = contour.first else { continue }
            func point(_ value: CGPoint) -> CGPoint {
                CGPoint(x: rect.minX + value.x / 1000 * rect.width,
                        y: rect.minY + value.y / 521.524 * rect.height)
            }
            path.move(to: point(first))
            for value in contour.dropFirst() { path.addLine(to: point(value)) }
            path.closeSubpath()
        }
        return path
    }
}
