import XCTest
@testable import Noot

final class LineOpsTests: XCTestCase {
    func apply(_ e: LineOps.Edit, to s: String) -> String {
        (s as NSString).replacingCharacters(in: e.range, with: e.text)
    }

    func testLineOps() {
        let t = "a\nb\nc"
        // move: middle down, last up, edges are no-ops
        var e = LineOps.move(t, NSRange(location: 2, length: 0), up: false)!
        XCTAssertEqual(apply(e, to: t), "a\nc\nb"); XCTAssertEqual(e.selection.location, 4)
        e = LineOps.move(t, NSRange(location: 4, length: 0), up: true)!
        XCTAssertEqual(apply(e, to: t), "a\nc\nb"); XCTAssertEqual(e.selection.location, 2)
        XCTAssertNil(LineOps.move(t, NSRange(location: 4, length: 0), up: false))
        XCTAssertNil(LineOps.move(t, NSRange(location: 0, length: 0), up: true))
        // multi-line block keeps its selection
        e = LineOps.move(t, NSRange(location: 0, length: 3), up: false)!
        XCTAssertEqual(apply(e, to: t), "c\na\nb"); XCTAssertEqual(e.selection, NSRange(location: 2, length: 3))
        // copy
        e = LineOps.copy(t, NSRange(location: 4, length: 0), up: false)
        XCTAssertEqual(apply(e, to: t), "a\nb\nc\nc"); XCTAssertEqual(e.selection.location, 6)
        e = LineOps.copy(t, NSRange(location: 0, length: 0), up: true)
        XCTAssertEqual(apply(e, to: t), "a\na\nb\nc"); XCTAssertEqual(e.selection.location, 0)
        // delete
        XCTAssertEqual(apply(LineOps.delete(t, NSRange(location: 2, length: 0)), to: t), "a\nc")
        XCTAssertEqual(apply(LineOps.delete(t, NSRange(location: 4, length: 0)), to: t), "a\nb")
        // select line grows by one line per press
        let l1 = LineOps.selectLine(t, NSRange(location: 2, length: 0))
        XCTAssertEqual(l1, NSRange(location: 2, length: 2))
        XCTAssertEqual(LineOps.selectLine(t, l1), NSRange(location: 2, length: 3))
        XCTAssertEqual(LineOps.indent(ofLineAt: 5, in: "x\n  y"), "  ")
    }

    func testJoinSortComment() {
        let t = "b  \n  a\nc"
        // caret line joins with the next; caret lands at the join
        var e = LineOps.join(t, NSRange(location: 0, length: 0))!
        XCTAssertEqual(apply(e, to: t), "b a\nc"); XCTAssertEqual(e.selection.location, 1)
        // a selection joins all its lines
        e = LineOps.join(t, NSRange(location: 0, length: 9))!
        XCTAssertEqual(apply(e, to: t), "b a c")
        XCTAssertNil(LineOps.join("x", NSRange(location: 0, length: 0)))
        // sort: whole note with no selection, selected lines otherwise
        XCTAssertEqual(apply(LineOps.sort("b\nc\na", NSRange(location: 0, length: 0), descending: false), to: "b\nc\na"), "a\nb\nc")
        XCTAssertEqual(apply(LineOps.sort("b\nc\na", NSRange(location: 0, length: 3), descending: true), to: "b\nc\na"), "c\nb\na")
        // comment toggles per line, keeps indentation, skips blank lines
        let m = "  x\n\ny"
        e = LineOps.toggleComment(m, NSRange(location: 0, length: 6), code: false)
        XCTAssertEqual(apply(e, to: m), "  <!-- x -->\n\n<!-- y -->")
        let commented = apply(e, to: m)
        XCTAssertEqual(apply(LineOps.toggleComment(commented, e.selection, code: false), to: commented), m)
        e = LineOps.toggleComment("a", NSRange(location: 1, length: 0), code: true)
        XCTAssertEqual(apply(e, to: "a"), "// a"); XCTAssertEqual(e.selection.location, 4)
    }
}

