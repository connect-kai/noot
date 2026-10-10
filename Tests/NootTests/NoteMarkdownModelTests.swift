import Foundation
import XCTest
@testable import Noot

final class NoteMarkdownModelTests: XCTestCase {
    func testParserClassifiesMarkdownBlocksAndInlineMarkers() {
        let source = "# Title\n- [ ] task\n> quote\n```swift\nlet x = 1\n```\n"
        let markdown = NoteMarkdownParser.parse(source)
        XCTAssertEqual(markdown.lines[0].kind, .heading(level: 1))
        XCTAssertEqual(markdown.lines[1].kind, .task(checked: false))
        XCTAssertEqual(markdown.lines[2].kind, .quote(depth: 1))
        XCTAssertEqual(markdown.lines[3].kind, .fenceOpen(language: "swift"))
        XCTAssertEqual(markdown.lines[4].kind, .code)
        XCTAssertEqual(markdown.lines[5].kind, .fenceClose)
        XCTAssertEqual(markdown.fenceBlocks, [3...5])
    }

    func testEditingPlansListContinuationAndInlineFormatting() {
        let source = "- item"
        let markdown = NoteMarkdownParser.parse(source)
        let newline = NoteMarkdownEditing.plan(
            .newline, source: source, selection: NSRange(location: 6, length: 0), markdown: markdown)
        XCTAssertEqual(newline?.replacement, "\n- ")

        let plain = "hello"
        let plainMarkdown = NoteMarkdownParser.parse(plain)
        let bold = NoteMarkdownEditing.plan(
            .toggleInline(.bold), source: plain, selection: NSRange(location: 0, length: 5),
            markdown: plainMarkdown)
        XCTAssertEqual(bold?.replacement, "**hello**")
    }

    func testRevealPolicyRevealsWholeFence() {
        let source = "```\ncode\n```\ntext"
        let markdown = NoteMarkdownParser.parse(source)
        let revealed = NoteRevealPolicy.revealedLines(
            selection: NSRange(location: 5, length: 0), markdown: markdown, isFocused: true)
        XCTAssertEqual(revealed, IndexSet([0, 1, 2]))
    }
}
