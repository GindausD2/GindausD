import UIKit

@MainActor
enum PhotoUpload {
    // Both endpoints accept at most 400,000 Base64 bytes.
    static let maxJPEGBytes = 300_000

    static func jpeg(_ image: UIImage) -> Data? {
        let attempts: [(edge: CGFloat, quality: CGFloat)] = [
            (1280, 0.78), (1024, 0.73), (768, 0.68), (512, 0.62)
        ]
        for (edge, quality) in attempts {
            let data = autoreleasepool {
                normalizedImage(image, edge: edge)?.jpegData(compressionQuality: quality)
            }
            if let data, data.count <= maxJPEGBytes { return data }
        }
        return nil
    }

    static func normalizedImage(_ image: UIImage, edge: CGFloat) -> UIImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest.isFinite, longest > 0 else { return nil }
        let ratio = min(1, edge / longest)
        let size = CGSize(width: max(1, image.size.width * ratio), height: max(1, image.size.height * ratio))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(bounds)
            image.draw(in: bounds)
        }
    }
}
