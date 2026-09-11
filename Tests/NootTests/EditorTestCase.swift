import XCTest
import Carbon.HIToolbox
import SwiftUI
@testable import Noot

// The editor as the app builds it (same TextKit stack, same delegate, Edit
// menu installed, key window), driven the way a user drives it: real
// NSEvents through NSApp.sendEvent, palette actions by title, mouse events.
// Nothing here touches the real ~/Noot or the system clipboard.
class EditorTestCase: XCTestCase {
    static let notesDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("noot-tests-\(ProcessInfo.processInfo.processIdentifier)")

    var window: NSWindow!
    var scroll: NSScrollView!
    var tv: NootTextView!
    var coordinator: MarkdownEditor.Coordinator!
    var pasteboard: NSPasteboard!
    var store: NotesStore { NotesStore.shared }

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        NotesStore.shared = NotesStore(dir: Self.notesDir, migrateLegacy: false)
        store.codeMode = false
        store.wordWrap = true
        AppDelegate().installEditMenu()

        let storage = NootMarkdownTextStorage()
        let layout = NootMarkdownLayoutManager()
        let container = NootMarkdownTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        tv = NootTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 300), textContainer: container)
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainerInset = NSSize(width: 18, height: 16)
        pasteboard = NSPasteboard(name: NSPasteboard.Name("noot-tests"))
        pasteboard.clearContents()
        tv.pasteboard = pasteboard
        coordinator = MarkdownEditor.Coordinator(MarkdownEditor(text: .constant("")))
        tv.delegate = coordinator

        scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        scroll.documentView = tv
        scroll.hasVerticalRuler = true
        scroll.verticalRulerView = LineNumberRuler(textView: tv, scrollView: scroll)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scroll
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(tv)
        gTextView = tv
    }

    override func tearDown() {
        window.orderOut(nil)
        gTextView = nil
        try? FileManager.default.removeItem(at: Self.notesDir)
        super.tearDown()
    }

    // MARK: text and cursors

    func load(_ text: String, caret: Int = 0) {
        tv.string = text
        coordinator.refreshPresentation(tv)
        tv.setSelectedRange(NSRange(location: caret, length: 0))
    }

    func select(_ location: Int, _ length: Int) {
        tv.setSelectedRange(NSRange(location: location, length: length))
    }

    /// every cursor position, primary and extra, sorted
    var cursors: [Int] { ([tv.selectedRange().location] + tv.extraCarets).sorted() }
    var selections: [NSRange] { tv.selectedRanges.map(\.rangeValue) }

    // MARK: keyboard

    struct Key {
        let chars: String, ignoring: String, code: Int
        static func letter(_ c: String, code: Int) -> Key { Key(chars: c, ignoring: c, code: code) }
        static func function(_ f: Int, code: Int) -> Key {
            let s = String(utf16CodeUnits: [unichar(f)], count: 1)
            return Key(chars: s, ignoring: s, code: code)
        }
        static let enter = Key(chars: "\r", ignoring: "\r", code: kVK_Return)
        static let backspace = Key(chars: "\u{7f}", ignoring: "\u{7f}", code: kVK_Delete)
        static let up = function(NSUpArrowFunctionKey, code: kVK_UpArrow)
        static let down = function(NSDownArrowFunctionKey, code: kVK_DownArrow)
        static let left = function(NSLeftArrowFunctionKey, code: kVK_LeftArrow)
        static let right = function(NSRightArrowFunctionKey, code: kVK_RightArrow)
        static let d = letter("d", code: kVK_ANSI_D), l = letter("l", code: kVK_ANSI_L)
        static let k = letter("k", code: kVK_ANSI_K), c = letter("c", code: kVK_ANSI_C)
        static let x = letter("x", code: kVK_ANSI_X), j = letter("j", code: kVK_ANSI_J)
        static let u = letter("u", code: kVK_ANSI_U), z = letter("z", code: kVK_ANSI_Z)
        static let slash = letter("/", code: kVK_ANSI_Slash)
        // ⌥ chords carry the dead-key character, as the keyboard really sends them
        static let optShiftI = Key(chars: "ˆ", ignoring: "I", code: kVK_ANSI_I)
        static let optZ = Key(chars: "Ω", ignoring: "z", code: kVK_ANSI_Z)
    }

    /// Deliver a key press the way the system does: through NSApp.sendEvent, so
    /// menu key equivalents, menu validation and keyDown all get their turn.
    func press(_ key: Key, _ flags: NSEvent.ModifierFlags = []) {
        var chars = key.chars, ignoring = key.ignoring
        if flags.contains(.shift), key.chars.count == 1, key.chars.first!.isLetter {
            chars = chars.uppercased()
            ignoring = ignoring.uppercased()
        }
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil, characters: chars,
                                     charactersIgnoringModifiers: ignoring, isARepeat: false,
                                     keyCode: UInt16(key.code))!
        // A test process never becomes the active app, so AppKit's own menu
        // dispatch has no key window to send to. Run the same chain by hand:
        // window views, then the Edit menu (matching + validation + responder
        // chain, the layers that broke ⌘C and ⇧⌥I), then keyDown.
        if window.performKeyEquivalent(with: event) { return }
        if let item = menuItem(matching: event) {
            if tv.validateUserInterfaceItem(item) { _ = tv.tryToPerform(item.action!, with: item) }
            return
        }
        window.sendEvent(event)
    }

    /// AppKit's matching, as observed: key + exact modifiers, and an ⌥ chord
    /// whose character is a dead key (⇧⌥I → ˆ) never matches a menu item.
    private func menuItem(matching event: NSEvent) -> NSMenuItem? {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        let deadKey = flags.contains(.option) && event.characters != event.charactersIgnoringModifiers
        func search(_ menu: NSMenu) -> NSMenuItem? {
            for item in menu.items {
                if let sub = item.submenu, let hit = search(sub) { return hit }
                guard !item.keyEquivalent.isEmpty, item.action != nil, !deadKey,
                      item.keyEquivalent.lowercased() == event.charactersIgnoringModifiers?.lowercased(),
                      item.keyEquivalentModifierMask.intersection([.command, .option, .shift, .control]) == flags
                else { continue }
                return item
            }
            return nil
        }
        return NSApp.mainMenu.flatMap(search)
    }

    func type(_ text: String) {
        for character in text { press(.letter(String(character), code: 0)) }
    }

    // MARK: mouse (middle button)

    /// Real middle-button events (NSEvent.mouseEvent can't set the button; CGEvent can).
    func middleDrag(from a: NSPoint, to b: NSPoint) {
        func event(_ type: CGEventType, _ p: NSPoint) -> NSEvent {
            let inWindow = tv.convert(p, to: nil)
            let screen = window.convertPoint(toScreen: inWindow)
            let flipped = CGPoint(x: screen.x, y: NSScreen.screens[0].frame.height - screen.y)
            let cg = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: flipped,
                             mouseButton: .center)!
            return NSEvent(cgEvent: cg)!
        }
        tv.otherMouseDown(with: event(.otherMouseDown, a))
        tv.otherMouseDragged(with: event(.otherMouseDragged, b))
        tv.otherMouseUp(with: event(.otherMouseUp, b))
    }

    /// point inside the given line (0-based), x in points from the text's left edge
    func point(line: Int, x: CGFloat) -> NSPoint {
        let ns = tv.string as NSString
        var index = 0
        for _ in 0 ..< line { index = NSMaxRange(ns.lineRange(for: NSRange(location: index, length: 0))) }
        let glyph = tv.layoutManager!.glyphIndexForCharacter(at: index)
        let rect = tv.layoutManager!.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        return NSPoint(x: tv.textContainerInset.width + x, y: rect.midY + tv.textContainerInset.height)
    }

    // MARK: ⌘K palette

    func action(_ title: String) throws {
        try XCTUnwrap(currentActions().first { $0.id == title }, "no palette action titled \(title)").run()
    }
}
