import XCTest
import UIKit
@testable import Max

@MainActor
final class VisualTextRecognitionTests: XCTestCase {
    func testReadsPrintedNameAndPreservesSpelling() throws {
        let name = "MIRA OKAFOR"
        let size = CGSize(width: 640, height: 160)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (name as NSString).draw(at: CGPoint(x: 28, y: 38), withAttributes: [
                .font: UIFont.systemFont(ofSize: 64, weight: .bold),
                .foregroundColor: UIColor.black
            ])
        }

        XCTAssertEqual(try VisualTextRecognition.read(XCTUnwrap(image.cgImage)), name)
    }

    func testBlankPhotoReturnsNoText() throws {
        let size = CGSize(width: 420, height: 240)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        XCTAssertEqual(try VisualTextRecognition.read(XCTUnwrap(image.cgImage)), "")
    }
}
