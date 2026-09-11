import XCTest
@testable import Noot

final class LineCommandTests: EditorTestCase {
    func testMoveAndCopyLines() {
        load("a\nb\nc", caret: 2)
        press(.down, .option)
        XCTAssertEqual(tv.string, "a\nc\nb")
        XCTAssertEqual(tv.selectedRange().location, 4)
        press(.up, .option)
        press(.up, .option)
        XCTAssertEqual(tv.string, "b\na\nc")
        XCTAssertEqual(tv.selectedRange().location, 0)
        press(.up, .option) // already first line: no-op
        XCTAssertEqual(tv.string, "b\na\nc")
        press(.down, [.option, .shift])
        XCTAssertEqual(tv.string, "b\nb\na\nc")
        XCTAssertEqual(tv.selectedRange().location, 2, "caret moves onto the copy")
        press(.up, [.option, .shift])
        XCTAssertEqual(tv.string, "b\nb\nb\na\nc")
        XCTAssertEqual(tv.selectedRange().location, 2, "caret stays on the upper copy")
    }

    func testDeleteSelectInsertAndJoinLines() {
        load("a\nb\nc", caret: 2)
        press(.k, [.command, .shift])
        XCTAssertEqual(tv.string, "a\nc")
        press(.l, .command)
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 2, length: 1))
        press(.l, .command)
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 2, length: 1), "last line: nothing more to grow into")

        load("  x\ny", caret: 1)
        press(.enter, .command) // insert line below keeps indent
        XCTAssertEqual(tv.string, "  x\n  \ny")
        XCTAssertEqual(tv.selectedRange().location, 6)
        press(.enter, [.command, .shift]) // insert line above
        XCTAssertEqual(tv.string, "  x\n  \n  \ny")
        XCTAssertEqual(tv.selectedRange().location, 6)

        load("one  \n   two\nthree", caret: 0)
        press(.j, .control)
        XCTAssertEqual(tv.string, "one two\nthree")
        XCTAssertEqual(tv.selectedRange().location, 3)
    }

    func testCutAndCopyTakeTheLineWithoutSelection() {
        load("one\ntwo", caret: 1)
        press(.c, .command)
        XCTAssertEqual(pasteboard.string(forType: .string), "one\n")
        press(.x, .command)
        XCTAssertEqual(tv.string, "two")
        XCTAssertEqual(pasteboard.string(forType: .string), "one\n")

        select(0, 2) // with a selection, normal copy
        press(.c, .command)
        XCTAssertEqual(pasteboard.string(forType: .string), "tw")
    }

    func testPaletteTextTransforms() throws {
        load("b\nc \na  ", caret: 0)
        try action("Trim Trailing Whitespace")
        XCTAssertEqual(tv.string, "b\nc\na")
        try action("Sort Lines A→Z")
        XCTAssertEqual(tv.string, "a\nb\nc")
        try action("Sort Lines Z→A")
        XCTAssertEqual(tv.string, "c\nb\na")
        select(0, 1)
        try action("Uppercase")
        XCTAssertEqual(tv.string, "C\nb\na")
        try action("Lowercase")
        XCTAssertEqual(tv.string, "c\nb\na")
    }
}
