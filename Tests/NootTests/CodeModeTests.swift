import XCTest
@testable import Noot

final class CodeModeTests: EditorTestCase {
    func testPaletteTogglesModeAndRendering() throws {
        load("# Title\n\n**bold** `code`\n\n---\n")
        let storage = tv.textStorage as! NootMarkdownTextStorage
        XCTAssertFalse(storage.presentation.syntaxRanges.isEmpty, "markdown mode hides syntax")
        XCTAssertFalse((storage.attribute(.font, at: 0, effectiveRange: nil) as! NSFont).isFixedPitch)

        try action("Code Mode")
        XCTAssertTrue(store.codeMode)
        coordinator.refreshPresentation(tv)
        XCTAssertTrue(storage.presentation.syntaxRanges.isEmpty, "code mode hides nothing")
        XCTAssertTrue(storage.presentation.dividerRanges.isEmpty)
        XCTAssertTrue((storage.attribute(.font, at: 0, effectiveRange: nil) as! NSFont).isFixedPitch)
        XCTAssertNil(storage.attribute(.link, at: 0, effectiveRange: nil))

        try action("Code Mode")
        XCTAssertFalse(store.codeMode)
        coordinator.refreshPresentation(tv)
        XCTAssertFalse(storage.presentation.syntaxRanges.isEmpty)
    }

    func testEnterContinuesListsInMarkdownButOnlyKeepsIndentInCode() {
        load("- item", caret: 6)
        press(.enter)
        XCTAssertEqual(tv.string, "- item\n- ")

        store.codeMode = true
        load("- item", caret: 6)
        press(.enter)
        XCTAssertEqual(tv.string, "- item\n")
        load("    x", caret: 5)
        press(.enter)
        XCTAssertEqual(tv.string, "    x\n    ")
        XCTAssertEqual(tv.selectedRange().location, 10)
    }

    func testCheckboxAutoConvertOnlyInMarkdown() {
        load("")
        type("[] ")
        XCTAssertEqual(tv.string, "- [ ] ")

        store.codeMode = true
        load("")
        type("[] ")
        XCTAssertEqual(tv.string, "[] ")
    }

    func testDividerCompletionOnlyInMarkdown() {
        load("")
        type("---")
        XCTAssertEqual(tv.string, "---\n")

        store.codeMode = true
        load("")
        type("---")
        XCTAssertEqual(tv.string, "---")
    }

    func testCommentStyleFollowsMode() {
        load("a")
        press(.slash, .command)
        XCTAssertEqual(tv.string, "<!-- a -->")
        press(.slash, .command)
        XCTAssertEqual(tv.string, "a")

        store.codeMode = true
        load("  a", caret: 3)
        press(.slash, .command)
        XCTAssertEqual(tv.string, "  // a")
        XCTAssertEqual(tv.selectedRange().location, 6)
    }

    func testGutterWidthFollowsLineCount() {
        let ruler = scroll.verticalRulerView as! LineNumberRuler
        load("a\nb\nc")
        XCTAssertEqual(ruler.ruleThickness, 36)
        load(Array(repeating: "x", count: 1000).joined(separator: "\n"))
        XCTAssertEqual(ruler.ruleThickness, 16 + 8 * 4)
    }

    func testWordWrapToggleFromKeyAndPalette() throws {
        load("a")
        press(.optZ, .option) // ⌥Z is a dead key: must not type Ω
        XCTAssertEqual(tv.string, "a")
        XCTAssertFalse(store.wordWrap)
        coordinator.applyWordWrap(tv, scroll)
        XCTAssertFalse(tv.textContainer!.widthTracksTextView)
        XCTAssertTrue(scroll.hasHorizontalScroller)
        XCTAssertEqual(tv.textContainer!.containerSize.width, .greatestFiniteMagnitude)

        try action("Word Wrap")
        XCTAssertTrue(store.wordWrap)
        coordinator.applyWordWrap(tv, scroll)
        XCTAssertTrue(tv.textContainer!.widthTracksTextView)
        XCTAssertFalse(scroll.hasHorizontalScroller)
        XCTAssertLessThan(tv.textContainer!.containerSize.width, 1000)
    }
}
