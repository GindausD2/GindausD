import Foundation
import XCTest
@testable import Max

final class EmailBriefTests: XCTestCase {
    func testSenderSearchTreatsTheNameAsALiteral() throws {
        XCTAssertEqual(try BriefEmail.senderQuery("  Ada Okafor  "), #"from:"Ada Okafor""#)
        XCTAssertEqual(try BriefEmail.senderQuery("ada+work@example.com"), #"from:"ada+work@example.com""#)
        XCTAssertThrowsError(try BriefEmail.senderQuery(#"Ada" OR from:someone"#))
    }

    func testMessageBodyPrefersPlainTextAndSkipsAttachments() throws {
        let encoded = Data("Can we move the meeting to Friday?".utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let payload = """
            {
              "mimeType": "multipart/mixed",
              "parts": [
                {"mimeType": "text/plain", "filename": "private.txt", "body": {"data": "U2VjcmV0"}},
                {"mimeType": "text/html", "body": {"data": "PGI+V3Jvbmc8L2I+"}},
                {"mimeType": "text/plain", "body": {"data": "\(encoded)"}}
              ]
            }
            """
        let part = try JSONDecoder().decode(BriefEmail.Part.self, from: Data(payload.utf8))
        XCTAssertEqual(part.readableText, "Can we move the meeting to Friday?")
    }

    func testHTMLBodyUsesInertText() throws {
        let html = "<style>secret</style><p>Friday &amp; Monday</p><script>ignored()</script>"
        let encoded = Data(html.utf8).base64EncodedString()
        let payload = #"{"mimeType":"text/html","body":{"data":"\#(encoded)"}}"#
        let part = try JSONDecoder().decode(BriefEmail.Part.self, from: Data(payload.utf8))
        XCTAssertEqual(part.readableText, "Friday & Monday")
    }

    func testLocalFallbackExtractsTheQuestionAndLabelsPartialInput() {
        let brief = EmailBrief.extract(from: """
            The revised launch plan is ready. Should we move the review to Friday?
            """, isPartial: true)
        XCTAssertEqual(brief.summary, "The revised launch plan is ready.")
        XCTAssertEqual(brief.requestedOpinion, "Should we move the review to Friday?")
        XCTAssertTrue(brief.usedExtracts)
        XCTAssertTrue(brief.isPartial)
        XCTAssertFalse(brief.suggestedResponse.isEmpty)
    }
}
