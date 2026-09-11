import XCTest
@testable import Noot

final class MultiCursorTests: EditorTestCase {
    func testCommandDGrowsSelectionAndTypingEditsEveryRange() {
        load("foo bar foo baz foo", caret: 1)
        press(.d, .command) // word under caret
        XCTAssertEqual(selections, [NSRange(location: 0, length: 3)])
        press(.d, .command)
        press(.d, .command)
        XCTAssertEqual(selections.map(\.location), [0, 8, 16])
        press(.d, .command) // wraps, no duplicate
        XCTAssertEqual(selections.count, 3)

        type("X")
        XCTAssertEqual(tv.string, "X bar X baz X")
        XCTAssertEqual(cursors, [1, 7, 13])
        type("Y")
        XCTAssertEqual(tv.string, "XY bar XY baz XY")
        press(.backspace)
        press(.backspace)
        XCTAssertEqual(tv.string, " bar  baz ")
        XCTAssertEqual(cursors, [0, 5, 10])
    }

    func testSelectAllOccurrencesThenReplace() {
        load("a-b a-b a-b", caret: 0)
        press(.l, [.control, .shift])
        XCTAssertEqual(selections.count, 3)
        type("z")
        XCTAssertEqual(tv.string, "z-b z-b z-b")
    }

    func testCursorsAtLineEndsThenEnterAndDelete() {
        load("ab\ncd\nef")
        select(0, 8)
        press(.optShiftI, [.option, .shift])
        XCTAssertEqual(tv.string, "ab\ncd\nef", "dead key must not type")
        XCTAssertEqual(cursors, [2, 5, 8])
        press(.enter)
        XCTAssertEqual(tv.string, "ab\n\ncd\n\nef\n")
        XCTAssertEqual(cursors, [3, 7, 11])
        press(.backspace)
        press(.backspace)
        XCTAssertEqual(tv.string, "a\nc\ne")
    }

    func testAddCursorBelowAndAboveFromKeys() {
        load("aa\nbb\ncc", caret: 1)
        press(.down, [.command, .option])
        press(.down, [.command, .option])
        XCTAssertEqual(cursors, [1, 4, 7])
        press(.up, [.command, .option]) // top line already has a cursor: nothing new
        XCTAssertEqual(cursors, [1, 4, 7])
        type("-")
        XCTAssertEqual(tv.string, "a-a\nb-b\nc-c")
    }

    func testArrowsMoveEveryCursorAndShiftSelects() {
        load("ab\ncd\nef")
        tv.setCarets(primary: 0, extras: [3, 6])
        press(.right)
        XCTAssertEqual(cursors, [1, 4, 7])
        press(.right, .command) // ⌘→ end of line
        XCTAssertEqual(cursors, [2, 5, 8])
        press(.left, .shift)
        XCTAssertEqual(selections, [NSRange(location: 1, length: 1), NSRange(location: 4, length: 1),
                                    NSRange(location: 7, length: 1)])
        XCTAssertEqual(tv.extraCarets, [])
        type("Z")
        XCTAssertEqual(tv.string, "aZ\ncZ\neZ")
    }

    func testUndoRevertsAMultiCursorEditInOneStep() {
        load("x\nx\nx")
        tv.setCarets(primary: 1, extras: [3, 5])
        type("!")
        XCTAssertEqual(tv.string, "x!\nx!\nx!")
        press(.z, .command)
        XCTAssertEqual(tv.string, "x\nx\nx")
    }

    func testCursorUndoStepsBack() {
        load("abcdef", caret: 0)
        tv.setCarets(primary: 1, extras: [3])
        select(5, 0)
        press(.u, .command)
        XCTAssertEqual(cursors, [1, 3])
        press(.u, .command)
        XCTAssertEqual(cursors, [0])
    }

    func testPlainSelectionChangeDropsExtraCarets() {
        load("ab\ncd")
        tv.setCarets(primary: 0, extras: [3])
        select(1, 0)
        XCTAssertEqual(tv.extraCarets, [])
        type("Q")
        XCTAssertEqual(tv.string, "aQb\ncd")
    }

    func testMiddleDragPlacesCaretPerLineOrSelectsColumn() {
        load("aaa\nbbb\nccc\n")
        middleDrag(from: point(line: 0, x: 0), to: point(line: 2, x: 0))
        XCTAssertEqual(cursors, [0, 4, 8])
        type(">")
        XCTAssertEqual(tv.string, ">aaa\n>bbb\n>ccc\n")

        middleDrag(from: point(line: 0, x: 0), to: point(line: 2, x: 400))
        XCTAssertEqual(selections, [NSRange(location: 0, length: 4), NSRange(location: 5, length: 4),
                                    NSRange(location: 10, length: 4)])
        press(.backspace)
        XCTAssertEqual(tv.string, "\n\n\n")
    }

    func testTextPastryFillsEachCursorFromPalette() throws {
        load("x\nx\nx")
        tv.setCarets(primary: 1, extras: [3, 5])
        try action("Sequence 1, 2, 3…")
        XCTAssertEqual(tv.string, "x1\nx2\nx3")
        try action("Sequence a, b, c…")
        XCTAssertEqual(tv.string, "x1a\nx2b\nx3c")
        pasteboard.clearContents()
        pasteboard.setString("red\ngreen\n\nblue\n", forType: .string)
        try action("Paste Lines to Cursors")
        XCTAssertEqual(tv.string, "x1ared\nx2bgreen\nx3cblue")

        // counting on from a selected number: ⌘D on "7"
        load("7 7 7", caret: 0)
        press(.d, .command)
        press(.d, .command)
        press(.d, .command)
        try action("Sequence 1, 2, 3…")
        XCTAssertEqual(tv.string, "7 8 9")
    }
}
