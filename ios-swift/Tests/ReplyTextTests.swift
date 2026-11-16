import XCTest
@testable import Max

final class ReplyTextTests: XCTestCase {
    func testSavedReminderReplyReadsCleanlyWithoutChangingItsContent() {
        let original = "Done — I’ll remind you at **3:00 PM** to chat **Justin**."
        let message = Message(role: "assistant", content: original)
        XCTAssertEqual(message.displayContent, "Done. I’ll remind you at 3:00 PM to chat Justin.")
        XCTAssertEqual(message.content, original)
        let history = Conversation(title: "Reminder", messages: [message])
        XCTAssertEqual(history.assistantPreview, message.displayContent)
    }

    func testHistoricalListAndStreamingEmphasisDoNotExposeMarkdown() {
        XCTAssertEqual(ReplyText.display("1. **When?**\n2. **What should I remind you about?**"),
                       "When?\nWhat should I remind you about?")
        XCTAssertEqual(ReplyText.display("Did you mean **3:00 PM", streaming: true), "Did you mean 3:00 PM")
        XCTAssertEqual(ReplyText.display("_Using get_datetime…_"), "")
    }

    func testPreservesUserTextAndLiteralValuesInAssistantReplies() {
        let exact = "Use -5, 3–5 PM, `a * b`, and https://example.test/a-b."
        XCTAssertEqual(Message(role: "user", content: "**3:00 PM** — hi").displayContent, "**3:00 PM** — hi")
        XCTAssertEqual(ReplyText.display(exact), "Use -5, 3–5 PM, a * b, and https://example.test/a-b.")
        XCTAssertEqual(ReplyText.display("Code:\n```swift\nlet delta = a - b\n```"), "Code:\nlet delta = a - b")
    }
}
