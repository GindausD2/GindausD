import UIKit
import XCTest
@testable import Max

final class PhotoUploadTests: XCTestCase {
    @MainActor
    func testLargePhotoIsPreparedWithinTheChatLimit() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let source = UIGraphicsImageRenderer(size: CGSize(width: 1800, height: 1200), format: format).image { context in
            context.cgContext.setFillColor(UIColor.systemBlue.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 1800, height: 1200))
        }
        let data = try XCTUnwrap(PhotoUpload.jpeg(source))
        XCTAssertLessThanOrEqual(data.base64EncodedString().utf8.count, 400_000)
        XCTAssertEqual(Array(data.prefix(3)), [0xFF, 0xD8, 0xFF])
        let prepared = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertLessThanOrEqual(prepared.width, 1280)
        XCTAssertEqual(Double(prepared.width) / Double(prepared.height), 1.5, accuracy: 0.01)
    }

    @MainActor
    func testAnEmptyImageCannotBePrepared() {
        XCTAssertNil(PhotoUpload.jpeg(UIImage()))
    }
}
