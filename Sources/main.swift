import SwiftUI
import Carbon.HIToolbox
import ApplicationServices
import ServiceManagement
import Quartz

let accent = Color(red: 1, green: 0.39, blue: 0.39) // raycast-ish #FF6363
let accentNS = NSColor(red: 1, green: 0.39, blue: 0.39, alpha: 1)
weak var gTextView: NSTextView?

// The opening shortcut is stored as Carbon values because Carbon is still the
// macOS API for registering a system-wide hotkey. Keeping the display label as
// part of the preference means less-common keys remain readable after relaunch.
struct OpeningShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    static let defaultValue = OpeningShortcut(
        keyCode: UInt32(kVK_ANSI_N),
        modifiers: UInt32(cmdKey | optionKey),
        keyLabel: "N")

    static var saved: OpeningShortcut {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "openingShortcutKeyCode") != nil,
              defaults.object(forKey: "openingShortcutModifiers") != nil,
              let label = defaults.string(forKey: "openingShortcutKeyLabel"),
              !label.isEmpty else { return .defaultValue }
        let shortcut = OpeningShortcut(
            keyCode: UInt32(defaults.integer(forKey: "openingShortcutKeyCode")),
            modifiers: UInt32(defaults.integer(forKey: "openingShortcutModifiers")),
            keyLabel: label)
        return shortcut.hasRequiredModifier ? shortcut : .defaultValue
    }

    var hasRequiredModifier: Bool {
        modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    var displayName: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result + keyLabel
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: "openingShortcutKeyCode")
        defaults.set(Int(modifiers), forKey: "openingShortcutModifiers")
        defaults.set(keyLabel, forKey: "openingShortcutKeyLabel")
    }

    static func from(_ event: NSEvent) -> OpeningShortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        let shortcut = OpeningShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyLabel: label(for: Int(event.keyCode)))
        return shortcut.hasRequiredModifier ? shortcut : nil
    }

    private static func label(for keyCode: Int) -> String {
        switch keyCode {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Grave: return String(UnicodeScalar(96))
        case kVK_Space: return "Space"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default: return "Key " + String(keyCode)
        }
    }
}

// MARK: - Store

struct Note: Identifiable {
    let url: URL
    var text: String
    var lastEdited: Date
    var id: URL { url }
    var title: String {
        var line = text.split(separator: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }).map(String.init) ?? ""
        for p in ["- [ ] ", "- [x] ", "[ ] ", "[x] "] where line.hasPrefix(p) { line = String(line.dropFirst(p.count)) }
        let t = line.trimmingCharacters(in: CharacterSet(charactersIn: "#->*+ ").union(.whitespaces))
        return t.isEmpty ? "Untitled" : t
    }
}

final class NotesStore: ObservableObject {
    static let shared = NotesStore()
    let dir: URL
    @Published var notes: [Note] = []
    @Published var currentIndex = 0
    @Published var fontSize: CGFloat {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: "fontSize")
        fontSize = saved == 0 ? 15 : saved
        // ~/Noot: directly in $HOME, outside TCC's protected folders — no permission prompts,
        // still user-visible plain files and covered by Time Machine
        dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Noot")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        migrateLegacyDirs()
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { $0.pathExtension == "md" }
        notes = files.map {
            let mod = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return Note(url: $0, text: (try? String(contentsOf: $0, encoding: .utf8)) ?? "", lastEdited: mod)
        }.sorted { $0.lastEdited > $1.lastEdited }
        if notes.isEmpty {
            newNote(initial: "# Welcome\n\nFloating notes, Raycast style.\n\n- **⌘⌘** or **⌥⌘N** toggle window, `esc` hides\n- **⌘N** new note, **⌘P** search notes, **⌘K** actions\n- **⌘=** / **⌘-** zoom\n\n- [ ] click a checkbox to toggle it\n- [x] like this one\n\nFiles live in `~/Noot`.")
        }
    }

    // one-shot: pull notes + assets out of the pre-1.3 locations (Documents is TCC-gated,
    // so this may show one final Documents prompt for upgraders — never again after)
    func migrateLegacyDirs() {
        guard !UserDefaults.standard.bool(forKey: "homeMigrationDone") else { return }
        UserDefaults.standard.set(true, forKey: "homeMigrationDone")
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacyDirs = [
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FloatNotes"),
            docs.appendingPathComponent("FloatNotes"),
            docs.appendingPathComponent("Noot"),
        ]
        for legacy in legacyDirs {
            guard let old = try? FileManager.default.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil) else { continue }
            for f in old where f.pathExtension == "md" {
                try? FileManager.default.moveItem(at: f, to: dir.appendingPathComponent(f.lastPathComponent))
            }
            let oldAssets = legacy.appendingPathComponent("assets")
            if let items = try? FileManager.default.contentsOfDirectory(at: oldAssets, includingPropertiesForKeys: nil) {
                let newAssets = dir.appendingPathComponent("assets")
                try? FileManager.default.createDirectory(at: newAssets, withIntermediateDirectories: true)
                for f in items {
                    try? FileManager.default.moveItem(at: f, to: newAssets.appendingPathComponent(f.lastPathComponent))
                }
            }
        }
    }

    var current: Note? { notes.indices.contains(currentIndex) ? notes[currentIndex] : nil }

    func newNote(initial: String = "") {
        let url = dir.appendingPathComponent(UUID().uuidString + ".md")
        try? initial.write(to: url, atomically: true, encoding: .utf8)
        notes.insert(Note(url: url, text: initial, lastEdited: Date()), at: 0)
        currentIndex = 0
    }

    func update(text: String) {
        guard notes.indices.contains(currentIndex) else { return }
        notes[currentIndex].text = text
        notes[currentIndex].lastEdited = Date()
        // ponytail: write on every keystroke; debounce if files ever get huge
        try? text.write(to: notes[currentIndex].url, atomically: true, encoding: .utf8)
    }

    func select(_ note: Note) {
        if let i = notes.firstIndex(where: { $0.id == note.id }) { currentIndex = i }
    }

    func openDaily() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let day = df.string(from: Date())
        let url = dir.appendingPathComponent("daily-\(day).md")
        if let i = notes.firstIndex(where: { $0.url == url }) {
            currentIndex = i
            return
        }
        let text = "# \(day)\n\n"
        try? text.write(to: url, atomically: true, encoding: .utf8)
        notes.insert(Note(url: url, text: text, lastEdited: Date()), at: 0)
        currentIndex = 0
    }

    // append clipboard text to the inbox note without touching the current note
    func capture(_ s: String) {
        let url = dir.appendingPathComponent("inbox.md")
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? "# Inbox\n\n"
        if !text.hasSuffix("\n") { text += "\n" }
        text += s.contains("\n") ? s + "\n\n" : "- " + s + "\n"
        try? text.write(to: url, atomically: true, encoding: .utf8)
        if let i = notes.firstIndex(where: { $0.url == url }) {
            notes[i].text = text
            notes[i].lastEdited = Date()
        } else {
            notes.insert(Note(url: url, text: text, lastEdited: Date()), at: 0)
        }
    }

    struct DeletedNote {
        let trashURL: URL
        let originalURL: URL
        let title: String
        let text: String
    }
    @Published var lastDeleted: DeletedNote?

    func delete(_ note: Note) {
        var trashURL: NSURL?
        try? FileManager.default.trashItem(at: note.url, resultingItemURL: &trashURL)
        if let t = trashURL as URL? {
            lastDeleted = DeletedNote(trashURL: t, originalURL: note.url, title: note.title, text: note.text)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                if self?.lastDeleted?.trashURL == t { self?.lastDeleted = nil }
            }
        }
        notes.removeAll { $0.id == note.id }
        if notes.isEmpty { newNote() }
        currentIndex = min(currentIndex, notes.count - 1)
    }

    func undoDelete() {
        guard let d = lastDeleted else { return }
        lastDeleted = nil
        try? FileManager.default.moveItem(at: d.trashURL, to: d.originalURL)
        notes.insert(Note(url: d.originalURL, text: d.text, lastEdited: Date()), at: 0)
        currentIndex = 0
    }
}

// MARK: - Overlay state (switcher / actions)

enum OverlayKind { case switcher, actions }

final class UIState: ObservableObject {
    static let shared = UIState()
    @Published var overlay: OverlayKind? = nil
    @Published var query = ""
    @Published var selIndex = 0
    var monitorInstalled = false
}

func filteredNotes() -> [Note] {
    let q = UIState.shared.query.lowercased()
    let sorted = NotesStore.shared.notes.sorted { $0.lastEdited > $1.lastEdited }
    guard !q.isEmpty else { return sorted }
    return sorted.filter { $0.title.lowercased().contains(q) || $0.text.lowercased().contains(q) }
}

struct ActionItem: Identifiable {
    let id: String
    let icon: String
    let keys: [String]
    let run: () -> Void
}

func currentActions() -> [ActionItem] {
    let s = NotesStore.shared
    return [
        ActionItem(id: "New Note", icon: "plus.square", keys: ["⌘", "N"]) { s.newNote() },
        ActionItem(id: "Daily Note", icon: "calendar", keys: ["⇧", "⌘", "D"]) { s.openDaily() },
        ActionItem(id: "Duplicate Note", icon: "plus.square.on.square", keys: []) {
            s.newNote(initial: s.current?.text ?? "")
        },
        ActionItem(id: "Copy Note", icon: "doc.on.doc", keys: []) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(s.current?.text ?? "", forType: .string)
        },
        ActionItem(id: "Delete Note", icon: "trash", keys: []) {
            if let n = s.current { s.delete(n) }
        },
        ActionItem(id: "Zoom In", icon: "plus.magnifyingglass", keys: ["⌘", "="]) {
            s.fontSize = min(s.fontSize + 1, 24)
        },
        ActionItem(id: "Zoom Out", icon: "minus.magnifyingglass", keys: ["⌘", "-"]) {
            s.fontSize = max(s.fontSize - 1, 11)
        },
    ]
}

func focusEditor() {
    if let tv = gTextView { tv.window?.makeFirstResponder(tv) }
}

// MARK: - Formatting commands (toolbar + shortcuts)

enum Fmt {
    // toggle inline markers around the selection, e.g. **bold**
    static func wrap(_ marker: String, _ suffixMarker: String? = nil) {
        guard let tv = gTextView else { return }
        let suffix = suffixMarker ?? marker
        let ns = tv.string as NSString
        let sel = tv.selectedRange()
        let text = ns.substring(with: sel)
        let pre = NSRange(location: sel.location - marker.count, length: marker.count)
        let post = NSRange(location: NSMaxRange(sel), length: suffix.count)
        if text.hasPrefix(marker), text.hasSuffix(suffix), text.count >= marker.count + suffix.count {
            let inner = String(text.dropFirst(marker.count).dropLast(suffix.count))
            tv.insertText(inner, replacementRange: sel)
            tv.setSelectedRange(NSRange(location: sel.location, length: (inner as NSString).length))
        } else if pre.location >= 0, NSMaxRange(post) <= ns.length,
                  ns.substring(with: pre) == marker, ns.substring(with: post) == suffix {
            tv.insertText(text, replacementRange: NSRange(location: pre.location,
                                                          length: marker.count + sel.length + suffix.count))
            tv.setSelectedRange(NSRange(location: pre.location, length: sel.length))
        } else {
            tv.insertText(marker + text + suffix, replacementRange: sel)
            tv.setSelectedRange(NSRange(location: sel.location + marker.count, length: (text as NSString).length))
        }
        focusEditor()
    }

    // toggle a line-start marker (headers, lists, quotes) on every selected line
    static func linePrefix(_ marker: String, header: Bool = false) {
        guard let tv = gTextView else { return }
        let ns = tv.string as NSString
        let lines = ns.lineRange(for: tv.selectedRange())
        var block = ns.substring(with: lines)
        let trailingNL = block.hasSuffix("\n")
        if trailingNL { block.removeLast() }
        let out = block.components(separatedBy: "\n").map { line -> String in
            var l = line
            if header {
                if l.hasPrefix(marker) { return String(l.dropFirst(marker.count)) }
                while l.first == "#" { l.removeFirst() }
                if l.first == " " { l.removeFirst() }
                return marker + l
            }
            if l.hasPrefix("- [ ] ") || l.hasPrefix("- [x] ") {
                let stripped = String(l.dropFirst(6))
                return marker == "- [ ] " ? stripped : marker + stripped
            }
            if l.hasPrefix(marker) { return String(l.dropFirst(marker.count)) }
            if marker == "- [ ] ", l.hasPrefix("- ") { return marker + l.dropFirst(2) }
            return marker + l
        }.joined(separator: "\n")
        tv.insertText(out + (trailingNL ? "\n" : ""), replacementRange: lines)
        focusEditor()
    }

    static func link() {
        guard let tv = gTextView else { return }
        let sel = tv.selectedRange()
        let text = (tv.string as NSString).substring(with: sel)
        let clip = NSPasteboard.general.string(forType: .string) ?? ""
        let url = clip.hasPrefix("http") ? clip : ""
        tv.insertText("[\(text)](\(url))", replacementRange: sel)
        if text.isEmpty {
            tv.setSelectedRange(NSRange(location: sel.location + 1, length: 0))
        } else if url.isEmpty {
            tv.setSelectedRange(NSRange(location: sel.location + (text as NSString).length + 3, length: 0))
        }
        focusEditor()
    }

    static func divider() {
        guard let tv = gTextView as? NootTextView else { return }
        tv.insertDivider()
        focusEditor()
    }
}

// resolve markdown link targets: absolute URLs pass through, relative paths land in the notes dir
func linkURL(_ s: String) -> URL? {
    if let u = URL(string: s), u.scheme != nil { return u }
    return URL(fileURLWithPath: s.removingPercentEncoding ?? s, relativeTo: NotesStore.shared.dir)
}

// MARK: - Markdown editor (native TextKit + swift-markdown)

final class QuickLooker: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLooker()
    var url: URL?
    func show(_ u: URL) {
        url = u
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { url == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { url! as NSURL }
}

// text view that accepts pasted/dropped images and files, copying them into assets/
final class NootTextView: NSTextView {
    // Completing `---` at the start of an otherwise-empty line immediately
    // creates the block and advances into the following editable paragraph.
    // The newline remains in the Markdown source, but no extra Enter press is
    // required from the user.
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let insertedText: String?
        if let string = insertString as? String {
            insertedText = string
        } else if let string = insertString as? NSString {
            insertedText = string as String
        } else {
            insertedText = nil
        }

        let effectiveRange = replacementRange.location == NSNotFound
            ? selectedRange()
            : replacementRange
        if insertedText == "-",
           let completion = dividerCompletion(at: effectiveRange) {
            super.insertText(completion.text, replacementRange: completion.range)
            return
        }
        super.insertText(insertString, replacementRange: replacementRange)
    }

    private func dividerCompletion(at replacementRange: NSRange)
        -> (text: String, range: NSRange)? {
        guard replacementRange.location != NSNotFound,
              replacementRange.length == 0 else { return nil }
        let ns = string as NSString
        let caret = replacementRange.location
        guard caret >= 2, caret <= ns.length else { return nil }

        var lineStart = caret
        while lineStart > 0 {
            let previous = ns.character(at: lineStart - 1)
            if previous == 10 || previous == 13 { break }
            lineStart -= 1
        }
        let prefix = NSRange(location: lineStart, length: caret - lineStart)
        guard ns.substring(with: prefix) == "--" else { return nil }

        if caret == ns.length {
            return ("---\n", prefix)
        }
        if ns.character(at: caret) == 13 {
            let newlineLength = caret + 1 < ns.length && ns.character(at: caret + 1) == 10 ? 2 : 1
            return ("---" + ns.substring(with: NSRange(location: caret, length: newlineLength)),
                    NSRange(location: lineStart, length: prefix.length + newlineLength))
        }
        if ns.character(at: caret) == 10 {
            return ("---\n", NSRange(location: lineStart, length: prefix.length + 1))
        }
        return nil
    }

    func insertDivider() {
        let ns = string as NSString
        let selection = selectedRange()
        guard selection.location != NSNotFound,
              selection.location <= ns.length,
              NSMaxRange(selection) <= ns.length else { return }

        if selection.length == 0 {
            let lineRange = ns.lineRange(for: selection)
            var contentRange = lineRange
            while contentRange.length > 0 {
                let last = ns.character(at: NSMaxRange(contentRange) - 1)
                guard last == 10 || last == 13 else { break }
                contentRange.length -= 1
            }
            let content = ns.substring(with: contentRange)
            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                let lineEnding = ns.substring(with: NSRange(
                    location: NSMaxRange(contentRange),
                    length: lineRange.length - contentRange.length
                ))
                insertText("---" + (lineEnding.isEmpty ? "\n" : lineEnding),
                           replacementRange: lineRange)
                return
            }
        }

        let selectedLines = ns.lineRange(for: selection)
        let endsWithNewline = selectedLines.length > 0 && {
            let last = ns.character(at: NSMaxRange(selectedLines) - 1)
            return last == 10 || last == 13
        }()
        let insertion = NSMaxRange(selectedLines)
        insertText(endsWithNewline ? "---\n" : "\n---\n",
                   replacementRange: NSRange(location: insertion, length: 0))
    }

    // A rendered thematic break is a block boundary, not an inline attachment.
    // Clicking it moves into the following editable line instead of leaving an
    // insertion point beside the hidden `---` source.
    override func mouseDown(with event: NSEvent) {
        guard event.clickCount == 1,
              !event.modifierFlags.contains(.shift),
              let layoutManager = layoutManager as? NootMarkdownLayoutManager,
              !layoutManager.dividerRanges.isEmpty
        else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let containerPoint = NSPoint(x: point.x - textContainerOrigin.x,
                                     y: point.y - textContainerOrigin.y)
        guard let divider = layoutManager.divider(at: containerPoint) else {
            super.mouseDown(with: event)
            return
        }

        window?.makeFirstResponder(self)
        let target = positionAfterDivider(divider)
        setSelectedRange(NSRange(location: target, length: 0))
        scrollRangeToVisible(selectedRange())
    }

    func positionAfterDivider(_ divider: NSRange) -> Int {
        let ns = string as NSString
        var target = NSMaxRange(divider)
        guard target < ns.length else { return target }
        if ns.character(at: target) == 13 {
            target += 1
            if target < ns.length, ns.character(at: target) == 10 { target += 1 }
        } else if ns.character(at: target) == 10 {
            target += 1
        }
        return target
    }

    func positionBeforeDivider(_ divider: NSRange) -> Int {
        let ns = string as NSString
        var target = divider.location
        guard target > 0 else { return target }
        if ns.character(at: target - 1) == 10 {
            target -= 1
            if target > 0, ns.character(at: target - 1) == 13 { target -= 1 }
        } else if ns.character(at: target - 1) == 13 {
            target -= 1
        }
        return target
    }

    // Backspace at the beginning of the paragraph after a divider removes the
    // whole Markdown block in one native, undoable replacement.
    override func deleteBackward(_ sender: Any?) {
        let selection = selectedRange()
        guard selection.length == 0,
              let dividerRanges = (layoutManager as? NootMarkdownLayoutManager)?.dividerRanges,
              !dividerRanges.isEmpty
        else {
            super.deleteBackward(sender)
            return
        }
        let ns = string as NSString
        if let divider = dividerRanges.first(where: { divider in
            let end = NSMaxRange(divider)
            guard end < selection.location else { return false }
            let gap = NSRange(location: end, length: selection.location - end)
            let separator = ns.substring(with: gap)
            return separator == "\n" || separator == "\r" || separator == "\r\n"
        }) {
            insertText("", replacementRange: NSRange(location: divider.location,
                                                       length: selection.location - divider.location))
            return
        }
        super.deleteBackward(sender)
    }

    // ⌘Y: Quick Look the file link under the caret
    @objc func quickLookLink(_ sender: Any?) {
        guard let storage = textStorage, storage.length > 0 else { return }
        let idx = min(selectedRange().location, storage.length - 1)
        for i in [idx, max(idx - 1, 0)] {
            if let link = storage.attribute(.link, at: i, effectiveRange: nil) as? URL, link.isFileURL {
                QuickLooker.shared.show(link)
                return
            }
        }
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            insertAssets(urls)
            return
        }
        // pasting a URL over selected text links the selection instead of replacing it
        if selectedRange().length > 0,
           let s = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           s.hasPrefix("http://") || s.hasPrefix("https://"),
           !s.contains(" "), !s.contains("\n"), URL(string: s) != nil {
            let sel = selectedRange()
            let text = (string as NSString).substring(with: sel)
            insertText("[\(text)](\(s))", replacementRange: sel)
            return
        }
        if let img = NSImage(pasteboard: pb), let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let name = "pasted-\(Int(Date().timeIntervalSince1970)).png"
            let dest = assetsDir().appendingPathComponent(name)
            try? png.write(to: dest)
            insertText("![\(name)](assets/\(name))\n", replacementRange: selectedRange())
            return
        }
        super.paste(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                            options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            insertAssets(urls)
            return true
        }
        return super.performDragOperation(sender)
    }

    func assetsDir() -> URL {
        let d = NotesStore.shared.dir.appendingPathComponent("assets")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func insertAssets(_ urls: [URL]) {
        let images = ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp"]
        var md = ""
        for u in urls {
            var dest = assetsDir().appendingPathComponent(u.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                dest = assetsDir().appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(u.lastPathComponent)")
            }
            try? FileManager.default.copyItem(at: u, to: dest)
            let bang = images.contains(u.pathExtension.lowercased()) ? "!" : ""
            md += "\(bang)[\(u.lastPathComponent)](assets/\(dest.lastPathComponent))\n"
        }
        insertText(md, replacementRange: selectedRange())
    }
}

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let storage = NootMarkdownTextStorage()
        let layoutManager = NootMarkdownLayoutManager()
        let textContainer = NootMarkdownTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        let tv = NootTextView(frame: .zero, textContainer: textContainer)
        tv.autoresizingMask = .width
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets()
        scroll.scrollerInsets = NSEdgeInsets()
        scroll.scrollerStyle = .overlay // no permanent track — kills the bottom-right notch
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        scroll.drawsBackground = false
        tv.textContainerInset = NSSize(width: 18, height: 16)
        tv.insertionPointColor = accentNS
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.linkTextAttributes = [.cursor: NSCursor.pointingHand]
        tv.setAccessibilityLabel("Note editor")
        tv.string = text
        gTextView = tv
        context.coordinator.refreshPresentation(tv)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        let tv = scroll.documentView as! NSTextView
        let size = NotesStore.shared.fontSize
        if tv.string != text {
            tv.string = text
            context.coordinator.refreshPresentation(tv)
        } else if context.coordinator.lastFontSize != size {
            context.coordinator.refreshPresentation(tv)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        var lastFontSize: CGFloat = 0
        var lastPara = NSRange(location: NSNotFound, length: 0)
        var lastSelectionLocation = 0
        var isNormalizingDividerSelection = false
        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ n: Notification) {
            guard let tv = n.object as? NSTextView else { return }
            autoConvert(tv)
            parent.text = tv.string
            refreshPresentation(tv)
        }

        // typing "[] ", "[ ] " or "[x] " at line start becomes a real task item "- [ ] "
        func autoConvert(_ tv: NSTextView) {
            let ns = tv.string as NSString
            let sel = tv.selectedRange()
            guard sel.length == 0, sel.location <= ns.length else { return }
            let line = ns.lineRange(for: NSRange(location: sel.location, length: 0))
            let upto = NSRange(location: line.location, length: sel.location - line.location)
            guard upto.length > 0, upto.length <= 12 else { return }
            let prefix = ns.substring(with: upto)
            guard let re = try? NSRegularExpression(pattern: "^(\\s*)\\[([ x])?\\] $"),
                  let m = re.firstMatch(in: prefix, range: NSRange(location: 0, length: (prefix as NSString).length))
            else { return }
            let p = prefix as NSString
            let indent = p.substring(with: m.range(at: 1))
            let mark = m.range(at: 2).location == NSNotFound ? " " : p.substring(with: m.range(at: 2))
            tv.insertText(indent + "- [\(mark)] ", replacementRange: upto)
        }

        // caret moved to another line: reveal its syntax, re-hide the previous line's.
        // Compare line START only (the range grows while typing), and defer out of the
        // text system's edit pass — rehighlighting mid-edit garbles glyph layout.
        func textViewDidChangeSelection(_ n: Notification) {
            guard let tv = n.object as? NSTextView else { return }
            if isNormalizingDividerSelection {
                lastSelectionLocation = tv.selectedRange().location
                return
            }
            if normalizeDividerSelection(tv) { return }
            lastSelectionLocation = tv.selectedRange().location
            if caretLines(tv).location != lastPara.location {
                DispatchQueue.main.async { [weak self, weak tv] in
                    guard let self, let tv else { return }
                    self.refreshPresentation(tv)
                }
            }
        }

        func normalizeDividerSelection(_ tv: NSTextView) -> Bool {
            guard let tv = tv as? NootTextView,
                  let layoutManager = tv.layoutManager as? NootMarkdownLayoutManager else { return false }
            let selection = tv.selectedRange()
            guard selection.length == 0,
                  let divider = layoutManager.dividerRanges.first(where: {
                      selection.location >= $0.location
                          && selection.location <= NSMaxRange($0)
                  }) else { return false }
            let target = selection.location >= lastSelectionLocation
                ? tv.positionAfterDivider(divider)
                : tv.positionBeforeDivider(divider)
            guard target != selection.location else { return false }
            isNormalizingDividerSelection = true
            tv.setSelectedRange(NSRange(location: target, length: 0))
            isNormalizingDividerSelection = false
            lastSelectionLocation = target
            DispatchQueue.main.async { [weak self, weak tv] in
                guard let self, let tv else { return }
                self.refreshPresentation(tv)
            }
            return true
        }

        func caretLines(_ tv: NSTextView) -> NSRange {
            let ns = tv.string as NSString
            guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
            var sel = tv.selectedRange()
            sel.location = min(sel.location, ns.length)
            sel.length = min(sel.length, ns.length - sel.location)
            return ns.lineRange(for: sel)
        }

        // esc hides the window; enter continues lists/checkboxes
        func textView(_ tv: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.cancelOperation(_:)) || sel == NSSelectorFromString("complete:") {
                tv.window?.orderOut(nil)
                return true
            }
            if sel == #selector(NSResponder.insertTab(_:)) {
                return changeIndentation(tv, outdent: false)
            }
            if sel == #selector(NSResponder.insertBacktab(_:)) {
                return changeIndentation(tv, outdent: true)
            }
            if sel == #selector(NSResponder.insertNewline(_:)) { return continueList(tv) }
            return false
        }

        // Tab and Shift-Tab operate on complete Markdown lines. A selection is
        // kept selected after replacement, so repeated presses move the whole
        // block through nesting levels as one undoable edit.
        func changeIndentation(_ tv: NSTextView, outdent: Bool) -> Bool {
            let ns = tv.string as NSString
            let selection = tv.selectedRange()
            guard selection.location != NSNotFound, selection.location <= ns.length else { return true }

            var effectiveSelection = selection
            // A selection ending exactly at the next line's start should not
            // unexpectedly include that otherwise-unselected line.
            if effectiveSelection.length > 0,
               NSMaxRange(effectiveSelection) > effectiveSelection.location,
               NSMaxRange(effectiveSelection) <= ns.length,
               NSMaxRange(effectiveSelection) > 0,
               ns.character(at: NSMaxRange(effectiveSelection) - 1) == 10 {
                effectiveSelection.length -= 1
            }

            let lineRange = ns.lineRange(for: effectiveSelection)
            var block = ns.substring(with: lineRange)
            let hasTrailingNewline = block.hasSuffix("\n")
            if hasTrailingNewline { block.removeLast() }
            var lines = block.components(separatedBy: "\n")

            var firstLineDelta = 0
            var changed = false
            for index in lines.indices {
                if outdent {
                    let removed: Int
                    if lines[index].hasPrefix("\t") {
                        removed = 1
                    } else {
                        removed = min(lines[index].prefix { $0 == " " }.count, 2)
                    }
                    if removed > 0 {
                        lines[index].removeFirst(removed)
                        changed = true
                    }
                    if index == 0 { firstLineDelta = -removed }
                } else {
                    lines[index] = "  " + lines[index]
                    changed = true
                    if index == 0 { firstLineDelta = 2 }
                }
            }
            guard changed else { return true }

            let replacement = lines.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
            tv.insertText(replacement, replacementRange: lineRange)
            let replacementLength = (replacement as NSString).length
            if selection.length > 0 {
                let selectedLength = max(0, replacementLength - (hasTrailingNewline ? 1 : 0))
                tv.setSelectedRange(NSRange(location: lineRange.location, length: selectedLength))
            } else {
                let location = max(lineRange.location,
                                   min(lineRange.location + replacementLength,
                                       selection.location + firstLineDelta))
                tv.setSelectedRange(NSRange(location: location, length: 0))
            }
            return true
        }

        func continueList(_ tv: NSTextView) -> Bool {
            let ns = tv.string as NSString
            let sel = tv.selectedRange()
            guard sel.location != NSNotFound else { return false }
            let lineRange = ns.lineRange(for: NSRange(location: sel.location, length: 0))
            var line = ns.substring(with: lineRange)
            if line.hasSuffix("\n") { line.removeLast() }
            let lineNS = line as NSString
            guard let re = try? NSRegularExpression(pattern: "^(\\s*)(?:([-*+]) (\\[[ x]\\] )?|(\\d+)\\. )(.*)$"),
                  let m = re.firstMatch(in: line, range: NSRange(location: 0, length: lineNS.length))
            else { return false }
            let g = { (i: Int) -> String in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : lineNS.substring(with: r)
            }
            let indent = g(1), bullet = g(2), checkbox = g(3), number = g(4), rest = g(5)
            if rest.trimmingCharacters(in: .whitespaces).isEmpty {
                // enter on an empty item clears the marker
                tv.insertText("", replacementRange: NSRange(location: lineRange.location, length: lineNS.length))
                return true
            }
            var marker: String
            if !bullet.isEmpty {
                marker = bullet + " " + (checkbox.isEmpty ? "" : "[ ] ")
            } else {
                marker = "\((Int(number) ?? 0) + 1). "
            }
            tv.insertText("\n" + indent + marker, replacementRange: sel)
            return true
        }

        func textView(_ tv: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL else { return false }
            if url.scheme == "noottag" {
                UIState.shared.query = "#" + ((url.host ?? "").removingPercentEncoding ?? "")
                UIState.shared.selIndex = 0
                UIState.shared.overlay = .switcher
                return true
            }
            if url.scheme == "fncheck", let loc = Int(url.host ?? "") {
                let ns = tv.string as NSString
                guard loc + 3 <= ns.length else { return true }
                let token = ns.substring(with: NSRange(location: loc, length: 3))
                tv.insertText(token == "[x]" ? "[ ]" : "[x]", replacementRange: NSRange(location: loc, length: 3))
                return true
            }
            NSWorkspace.shared.open(url)
            return true
        }

        func refreshPresentation(_ tv: NSTextView) {
            guard let storage = tv.textStorage as? NootMarkdownTextStorage,
                  let layoutManager = tv.layoutManager as? NootMarkdownLayoutManager
            else { return }
            let size = NotesStore.shared.fontSize
            lastFontSize = size
            storage.refreshPresentation(fontSize: size)
            tv.typingAttributes = storage.baseTypingAttributes
            let reveal = caretLines(tv)
            lastPara = reveal
            layoutManager.updatePresentation(storage.presentation,
                                             revealing: reveal,
                                             selection: tv.selectedRange(),
                                             textLength: storage.length)
        }
    }
}

// MARK: - UI

struct VisualEffect: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.state = .active
        updateNSView(v, context: context)
        return v
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        // HUD material is intentionally dark. Use an appearance-aware material
        // in light mode so the glass does not turn into a muddy grey sheet.
        view.material = colorScheme == .light ? .underWindowBackground : .hudWindow
    }
}

final class ResizeHandleView: NSView {
    private var startingFrame: NSRect?
    private var startingMouse: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        toolTip = "Drag to resize"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Resize Noot")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startingFrame = window.frame
        startingMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let startingFrame, let startingMouse else { return }
        let mouse = NSEvent.mouseLocation
        let width = max(window.minSize.width, startingFrame.width + mouse.x - startingMouse.x)
        let height = max(window.minSize.height, startingFrame.height + startingMouse.y - mouse.y)
        let frame = NSRect(x: startingFrame.minX,
                           y: startingFrame.maxY - height,
                           width: width,
                           height: height)
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        startingFrame = nil
        startingMouse = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.secondaryLabelColor.withAlphaComponent(0.6).setStroke()
        for inset in [7.0, 12.0, 17.0] {
            let path = NSBezierPath()
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: bounds.maxX - inset, y: 5))
            path.line(to: NSPoint(x: bounds.maxX - 5, y: inset))
            path.stroke()
        }
    }
}

struct ResizeHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeHandleView { ResizeHandleView() }
    func updateNSView(_ nsView: ResizeHandleView, context: Context) {}
}

final class HeaderMenuView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // The transparent overlay should never interfere with formatting buttons.
    // It participates in hit-testing only for right-click or Control-click.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point), let event = NSApp.currentEvent else { return nil }
        if event.type == .rightMouseDown ||
            (event.type == .leftMouseDown && event.modifierFlags.contains(.control)) {
            return self
        }
        return nil
    }

    override func rightMouseDown(with event: NSEvent) { showMenu(with: event) }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showMenu(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    private func showMenu(with event: NSEvent) {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        NSMenu.popUpContextMenu(delegate.makeStatusMenu(), with: event, for: self)
    }
}

struct HeaderMenuPresenter: NSViewRepresentable {
    func makeNSView(context: Context) -> HeaderMenuView { HeaderMenuView() }
    func updateNSView(_ nsView: HeaderMenuView, context: Context) {}
}

func kbd(_ s: String) -> some View {
    Text(s)
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 4).padding(.vertical, 2)
        .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
}

let relFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f
}()

struct ContentView: View {
    @ObservedObject var store = NotesStore.shared
    @ObservedObject var ui = UIState.shared
    @State private var hoveredNote: URL?

    var textBinding: Binding<String> {
        Binding(get: { store.current?.text ?? "" }, set: { store.update(text: $0) })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.35)
                MarkdownEditor(text: textBinding)
                    .id(store.current?.id) // fresh undo stack per note
                Divider().opacity(0.5)
                bottomBar
            }
            if ui.overlay != nil {
                Color.black.opacity(0.001)
                    .onTapGesture { ui.overlay = nil }
            }
            if ui.overlay == .switcher {
                HStack { switcherOverlay; Spacer() }
            }
            if ui.overlay == .actions {
                HStack { Spacer(); actionsOverlay }
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .onAppear(perform: installKeyMonitor)
        .onChange(of: ui.query) { _ in ui.selIndex = 0 }
    }

    func toggleOverlay(_ kind: OverlayKind) {
        if ui.overlay == kind {
            ui.overlay = nil
            focusEditor()
        } else {
            ui.query = ""
            ui.selIndex = 0
            ui.overlay = kind
        }
    }

    // arrow keys / enter / esc for the overlays, whatever has focus
    func installKeyMonitor() {
        guard !ui.monitorInstalled else { return }
        ui.monitorInstalled = true
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            // while the delete toast is up, ⌘Z means "un-delete", not text undo
            if e.keyCode == 6, // z
               e.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
               NotesStore.shared.lastDeleted != nil {
                NotesStore.shared.undoDelete()
                return nil
            }
            guard let kind = UIState.shared.overlay else { return e }
            let ui = UIState.shared
            let count = kind == .switcher ? filteredNotes().count : currentActions().count
            switch e.keyCode {
            case 53: // esc
                ui.overlay = nil
                focusEditor()
                return nil
            case 125: // down
                ui.selIndex = min(ui.selIndex + 1, max(count - 1, 0))
                return nil
            case 126: // up
                ui.selIndex = max(ui.selIndex - 1, 0)
                return nil
            case 36: // return
                if kind == .switcher {
                    let list = filteredNotes()
                    if list.indices.contains(ui.selIndex) { NotesStore.shared.select(list[ui.selIndex]) }
                } else {
                    let list = currentActions()
                    if list.indices.contains(ui.selIndex) { list[ui.selIndex].run() }
                }
                ui.overlay = nil
                focusEditor()
                return nil
            default:
                return e
            }
        }
    }

    func tb(_ label: String, symbol: Bool = true, _ tip: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if symbol { Image(systemName: label).font(.system(size: 11.5)) }
                else { Text(label).font(.system(size: 10.5, weight: .bold)) }
            }
            .frame(width: 24, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tip)
    }

    var toolbar: some View {
        HStack(spacing: 2) {
            tb("H1", symbol: false, "Heading 1  ⌥⌘1") { Fmt.linePrefix("# ", header: true) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            tb("H2", symbol: false, "Heading 2  ⌥⌘2") { Fmt.linePrefix("## ", header: true) }
                .keyboardShortcut("2", modifiers: [.command, .option])
            tb("H3", symbol: false, "Heading 3  ⌥⌘3") { Fmt.linePrefix("### ", header: true) }
                .keyboardShortcut("3", modifiers: [.command, .option])
            Divider().frame(height: 13).padding(.horizontal, 4)
            tb("bold", "Bold  ⌘B") { Fmt.wrap("**") }
                .keyboardShortcut("b", modifiers: .command)
            tb("italic", "Italic  ⌘I") { Fmt.wrap("*") }
                .keyboardShortcut("i", modifiers: .command)
            tb("strikethrough", "Strikethrough  ⌘⇧X") { Fmt.wrap("~~") }
                .keyboardShortcut("x", modifiers: [.command, .shift])
            tb("chevron.left.forwardslash.chevron.right", "Code  ⌘E") { Fmt.wrap("`") }
                .keyboardShortcut("e", modifiers: .command)
            Divider().frame(height: 13).padding(.horizontal, 4)
            tb("list.bullet", "Bullet List  ⌘⇧8") { Fmt.linePrefix("- ") }
                .keyboardShortcut("8", modifiers: [.command, .shift])
            tb("checklist", "Checkbox  ⌘⇧T") { Fmt.linePrefix("- [ ] ") }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            tb("text.quote", "Quote") { Fmt.linePrefix("> ") }
            tb("minus", "Divider") { Fmt.divider() }
                .accessibilityLabel("Divider")
            tb("link", "Link  ⌘⇧L") { Fmt.link() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .overlay(HeaderMenuPresenter())
    }

    var bottomBar: some View {
        HStack(spacing: 12) {
            Button { toggleOverlay(.switcher) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                    Text(store.current?.title ?? "Notes").lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("p", modifiers: .command)
            Spacer()
            if let d = store.lastDeleted {
                Button("Deleted “\(d.title)” — ⌘Z to undo") { store.undoDelete(); focusEditor() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(accent)
            } else {
                Text("\(store.current?.text.count ?? 0) characters")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Button { toggleOverlay(.actions) } label: {
                HStack(spacing: 4) { Text("Actions"); kbd("⌘"); kbd("K") }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.trailing, 24) // keep Actions clear of the larger resize target
        .frame(height: 36) // fixed so the overlays can dock exactly on top
        .background(hiddenShortcuts) // in the hierarchy for key equivalents, out of the layout
    }

    var hiddenShortcuts: some View {
        Group {
            Button("") { store.newNote(); ui.overlay = nil; focusEditor() }
                .keyboardShortcut("n", modifiers: .command)
            Button("") { store.openDaily(); ui.overlay = nil; focusEditor() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("") { store.fontSize = min(store.fontSize + 1, 24) }
                .keyboardShortcut("=", modifiers: .command)
            Button("") { store.fontSize = max(store.fontSize - 1, 11) }
                .keyboardShortcut("-", modifiers: .command)
            Button("") { NSApp.keyWindow?.orderOut(nil) }
                .keyboardShortcut("w", modifiers: .command)
        }
        .opacity(0).frame(width: 0)
    }

    var switcherOverlay: some View {
        VStack(spacing: 0) {
            SearchField()
            Divider().opacity(0.5)
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(Array(filteredNotes().enumerated()), id: \.element.id) { i, note in
                        HStack {
                            Text(note.title).lineLimit(1)
                            Spacer()
                            Text(relFormatter.localizedString(for: note.lastEdited, relativeTo: Date()))
                                .font(.system(size: 10)).foregroundStyle(.tertiary)
                            Button { store.delete(note) } label: {
                                Image(systemName: "trash").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                            .help("Move to Trash")
                            .opacity(hoveredNote == note.id ? 1 : 0) // hover-only, constant layout
                        }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(i == ui.selIndex ? Color.primary.opacity(0.1) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .onTapGesture { store.select(note); ui.overlay = nil; focusEditor() }
                        .onHover { h in
                            if h { hoveredNote = note.id }
                            else if hoveredNote == note.id { hoveredNote = nil }
                        }
                        .contextMenu {
                            Button("Duplicate") { store.newNote(initial: note.text); ui.overlay = nil; focusEditor() }
                            Button("Copy Note") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(note.text, forType: .string)
                            }
                            Divider()
                            Button("Delete", role: .destructive) { store.delete(note) }
                        }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 250)
        }
        .frame(width: 280)
        .overlayChrome()
    }

    var actionsOverlay: some View {
        VStack(spacing: 1) {
            ForEach(Array(currentActions().enumerated()), id: \.element.id) { i, action in
                HStack(spacing: 8) {
                    Image(systemName: action.icon).frame(width: 16)
                    Text(action.id)
                    Spacer()
                    HStack(spacing: 2) { ForEach(action.keys, id: \.self) { kbd($0) } }
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(i == ui.selIndex ? Color.primary.opacity(0.1) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
                .onTapGesture { action.run(); ui.overlay = nil; focusEditor() }
            }
        }
        .padding(6)
        .frame(width: 240)
        .overlayChrome()
    }
}

struct SearchField: View {
    @ObservedObject var ui = UIState.shared
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
            TextField("Search notes…", text: $ui.query)
                .textFieldStyle(.plain)
                .focused($focused)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .onAppear { DispatchQueue.main.async { focused = true } }
    }
}

struct OverlayChrome: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12.5))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(colorScheme == .light ? 0.16 : 0.1)))
            .padding(.horizontal, 6)
            .padding(.bottom, 36) // flush against the action bar, Raycast style
    }
}

extension View {
    func overlayChrome() -> some View { modifier(OverlayChrome()) }
}

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ContentView()
            ResizeHandle()
                .frame(width: 40, height: 40)
        }
            .background {
                ZStack {
                    VisualEffect()
                    // Light glass needs a little body to keep text readable on
                    // pale windows; dark mode keeps the existing HUD look.
                    if colorScheme == .light { Color.white.opacity(0.38) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .light ? 0.16 : 0.12)))
            .ignoresSafeArea()
    }
}

// MARK: - Panel + app

final class NotesPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

final class ShortcutRecorderView: NSView {
    var shortcut: OpeningShortcut? { didSet { needsDisplay = true } }
    var onShortcutChanged: ((OpeningShortcut) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        toolTip = "Press the shortcut you want to use"
        setAccessibilityElement(true)
        setAccessibilityRole(.textField)
        setAccessibilityLabel("Opening shortcut")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == UInt16(kVK_Escape),
           flags.intersection([.command, .option, .control, .shift]).isEmpty {
            onCancel?()
            return
        }
        guard let shortcut = OpeningShortcut.from(event) else {
            NSSound.beep()
            return
        }
        self.shortcut = shortcut
        setAccessibilityValue(shortcut.displayName)
        onShortcutChanged?(shortcut)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75), xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        shape.fill()
        ((window?.firstResponder === self) ? accentNS : NSColor.separatorColor).setStroke()
        shape.lineWidth = window?.firstResponder === self ? 2 : 1
        shape.stroke()

        let text = shortcut?.displayName ?? "Type a shortcut"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attributes)
    }
}

final class ShortcutRecorderController: NSWindowController, NSWindowDelegate {
    private let recorder = ShortcutRecorderView(frame: .zero)
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private let onSave: (OpeningShortcut) -> Bool
    var onClose: (() -> Void)?

    init(current: OpeningShortcut, onSave: @escaping (OpeningShortcut) -> Bool) {
        self.onSave = onSave
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        super.init(window: window)
        window.title = "Opening Shortcut"
        window.isReleasedWhenClosed = false
        window.delegate = self // catches the close button too, not just Cancel/Esc

        let instruction = NSTextField(labelWithString: "Press the shortcut that should open Noot.")
        instruction.font = .systemFont(ofSize: 13, weight: .medium)
        let hint = NSTextField(labelWithString: "Include Command, Option, or Control so normal typing stays available.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        recorder.shortcut = current
        recorder.setAccessibilityValue(current.displayName)
        recorder.onShortcutChanged = { [weak self] _ in self?.saveButton.isEnabled = true }
        recorder.onCancel = { [weak self] in self?.close() }
        recorder.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.keyEquivalent = "\r"
        let buttons = NSStackView(views: [NSView(), cancelButton, saveButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let stack = NSStackView(views: [instruction, recorder, hint, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = NSView()
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -18),
            recorder.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recorder.heightAnchor.constraint(equalToConstant: 56),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        window.initialFirstResponder = recorder
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
        window?.makeFirstResponder(recorder)
    }

    @objc private func cancel() { close() }

    @objc private func save() {
        guard let shortcut = recorder.shortcut, onSave(shortcut) else { return }
        close()
    }

    func windowWillClose(_ notification: Notification) { onClose?() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var panel: NotesPanel!
    var statusItem: NSStatusItem?
    var hotKeyRef: EventHotKeyRef?
    var captureHotKeyRef: EventHotKeyRef?
    var hotKeyHandlerRef: EventHandlerRef?
    var openingShortcut = OpeningShortcut.saved
    var openingShortcutsEnabled = true
    var shortcutRecorderController: ShortcutRecorderController?
    var availableUpdateTitle: String?
    var menuBarShownForShortcutPause = false
    var placed = false
    var lastShiftTap: TimeInterval = 0
    var shiftWasDown = false

    var isMenuBarVisible: Bool { statusItem != nil }

    var prefersMenuBarIcon: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "showInMenuBar") != nil else { return true }
        return defaults.bool(forKey: "showInMenuBar")
    }

    // A double tap has no key, only a modifier, so a fixed list beats a recorder.
    static let doubleTapChoices: [(id: String, label: String, flag: NSEvent.ModifierFlags?)] = [
        ("command", "⌘⌘", .command),
        ("option", "⌥⌥", .option),
        ("control", "⌃⌃", .control),
        ("shift", "⇧⇧", .shift),
        ("off", "Off", nil),
    ]

    var doubleTapChoice: (id: String, label: String, flag: NSEvent.ModifierFlags?) {
        let saved = UserDefaults.standard.string(forKey: "doubleTapModifier") ?? "command"
        return Self.doubleTapChoices.first { $0.id == saved } ?? Self.doubleTapChoices[0]
    }

    var openTitle: String {
        let tap = doubleTapChoice.flag == nil ? "" : "\(doubleTapChoice.label) or "
        return "Open Noot (\(tap)\(openingShortcut.displayName))"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = NotesPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 480, height: 320)
        panel.contentView = NSHostingView(rootView: RootView())
        if panel.setFrameUsingName("NootPanel") { placed = true } // restore last size/position
        panel.setFrameAutosaveName("NootPanel")

        // first bundled launch: enable open-at-login once; the menu item can turn it off
        if Bundle.main.bundleIdentifier != nil, !UserDefaults.standard.bool(forKey: "didAutoLogin") {
            UserDefaults.standard.set(true, forKey: "didAutoLogin")
            try? SMAppService.mainApp.register()
        }

        if prefersMenuBarIcon { setMenuBarVisible(true, persist: false) }
        installEditMenu() // key-equivalents (⌘C/⌘V/⌘Z) need a main menu even in accessory apps
        installHotKeys()
        installDoubleShift()
        // start hidden: the panel is summoned, it doesn't ambush — except the very first run
        if !UserDefaults.standard.bool(forKey: "launchedBefore") {
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            togglePanel()
        }
        checkForUpdates()
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }

    func setMenuBarVisible(_ visible: Bool, persist: Bool = true) {
        if visible {
            if persist { UserDefaults.standard.set(true, forKey: "showInMenuBar") }
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem = item
            let iconName = UserDefaults.standard.string(forKey: "statusIcon") ?? "note.text"
            item.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Noot")
            item.menu = makeStatusMenu()
            return
        }

        guard openingShortcutsEnabled else {
            showAlert(
                title: "Resume opening shortcuts first",
                message: "Keeping the menu-bar icon visible prevents Noot from becoming unreachable while its opening shortcuts are paused.")
            return
        }
        if persist { UserDefaults.standard.set(false, forKey: "showInMenuBar") }
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false // refreshMenu owns isEnabled; auto-validation would undo it

        let toggle = NSMenuItem(
            title: openTitle,
            action: #selector(togglePanel),
            keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let daily = NSMenuItem(title: "Open Daily Note (⇧⌘D)", action: #selector(showDaily), keyEquivalent: "")
        daily.target = self
        menu.addItem(daily)
        let capture = NSMenuItem(title: "Capture Clipboard (⌥⌘C)", action: #selector(quickCapture), keyEquivalent: "")
        capture.target = self
        menu.addItem(capture)
        menu.addItem(.separator())

        let openingShortcuts = NSMenuItem(
            title: "Opening Shortcuts Enabled",
            action: #selector(toggleOpeningShortcuts),
            keyEquivalent: "")
        openingShortcuts.target = self
        openingShortcuts.toolTip = "This pause lasts until Noot quits"
        menu.addItem(openingShortcuts)

        let doubleTapItem = NSMenuItem(title: "Double-Tap to Open", action: nil, keyEquivalent: "")
        let doubleTaps = NSMenu(title: "Double-Tap to Open")
        for choice in Self.doubleTapChoices {
            let item = NSMenuItem(title: choice.label, action: #selector(changeDoubleTap(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.id
            doubleTaps.addItem(item)
        }
        doubleTapItem.submenu = doubleTaps
        menu.addItem(doubleTapItem)

        let shortcut = NSMenuItem(
            title: "Change Opening Shortcut… (\(openingShortcut.displayName))",
            action: #selector(showShortcutRecorder),
            keyEquivalent: "")
        shortcut.target = self
        menu.addItem(shortcut)

        let accessibility = NSMenuItem(
            title: "Enable ⌘⌘ (Accessibility)…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: "")
        accessibility.target = self
        menu.addItem(accessibility)
        menu.addItem(.separator())

        let showMenuBar = NSMenuItem(
            title: "Show in Menu Bar",
            action: #selector(toggleMenuBarItem),
            keyEquivalent: "")
        showMenuBar.target = self
        showMenuBar.toolTip = "You can always reopen this menu by right-clicking Noot’s top toolbar"
        menu.addItem(showMenuBar)

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        login.target = self
        menu.addItem(login)

        let iconItem = NSMenuItem(title: "Icon", action: nil, keyEquivalent: "")
        let icons = NSMenu(title: "Icon")
        for (symbol, label) in [("note.text", "Note"), ("sparkles", "Sparkles"),
                                ("scribble.variable", "Scribble"), ("pencil.and.outline", "Pencil"),
                                ("bolt.fill", "Bolt"), ("leaf.fill", "Leaf"),
                                ("moon.stars.fill", "Moon"), ("flame.fill", "Flame")] {
            let item = NSMenuItem(title: label, action: #selector(changeIcon(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = symbol
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            icons.addItem(item)
        }
        iconItem.submenu = icons
        menu.addItem(iconItem)

        let autoUp = NSMenuItem(title: "Auto-Update", action: #selector(toggleAutoUpdate(_:)), keyEquivalent: "")
        autoUp.target = self
        menu.addItem(autoUp)

        let update = NSMenuItem(
            title: availableUpdateTitle ?? "",
            action: #selector(updateClicked),
            keyEquivalent: "")
        update.target = self
        menu.addItem(update)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self
        refreshMenu(menu)
        return menu
    }

    @objc func toggleMenuBarItem() {
        let shouldShow = !isMenuBarVisible
        // Removing a status item while its menu is tracking is safest on the
        // next run-loop turn. The same path also supports the toolbar menu.
        DispatchQueue.main.async { [weak self] in self?.setMenuBarVisible(shouldShow) }
    }

    func menuItem(in menu: NSMenu, action: Selector) -> NSMenuItem? {
        menu.items.first { $0.action == action }
    }

    func submenu(in menu: NSMenu, titled title: String) -> NSMenu? {
        menu.items.compactMap(\.submenu).first { $0.title == title }
    }

    @objc func changeDoubleTap(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        UserDefaults.standard.set(id, forKey: "doubleTapModifier")
        lastShiftTap = 0 // drop any half-finished tap on the old modifier
        shiftWasDown = false
        sender.menu?.items.forEach { $0.state = ($0.representedObject as? String) == id ? .on : .off }
        updateShortcutMenu()
    }

    func refreshMenu(_ menu: NSMenu) {
        let trusted = AXIsProcessTrusted()
        menuItem(in: menu, action: #selector(togglePanel))?.title = openTitle

        let opening = menuItem(in: menu, action: #selector(toggleOpeningShortcuts))
        opening?.state = openingShortcutsEnabled ? .on : .off

        menuItem(in: menu, action: #selector(showShortcutRecorder))?.title =
            "Change Opening Shortcut… (\(openingShortcut.displayName))"

        let accessibility = menuItem(in: menu, action: #selector(openAccessibilitySettings))
        let tap = doubleTapChoice.flag == nil ? "" : "\(doubleTapChoice.label) "
        accessibility?.title = trusted ? "\(tap)Accessibility ✓" : "Enable \(tap)(Accessibility)…"
        accessibility?.state = trusted ? .on : .off

        let showMenuBar = menuItem(in: menu, action: #selector(toggleMenuBarItem))
        showMenuBar?.state = isMenuBarVisible ? .on : .off
        showMenuBar?.isEnabled = openingShortcutsEnabled

        let login = menuItem(in: menu, action: #selector(toggleLoginItem(_:)))
        login?.isEnabled = Bundle.main.bundleIdentifier != nil
        login?.state =
            (Bundle.main.bundleIdentifier != nil && SMAppService.mainApp.status == .enabled) ? .on : .off

        // scoped by submenu title: both submenus use String representedObjects
        let iconName = UserDefaults.standard.string(forKey: "statusIcon") ?? "note.text"
        submenu(in: menu, titled: "Icon")?.items.forEach {
            $0.state = ($0.representedObject as? String) == iconName ? .on : .off
        }
        let tapID = doubleTapChoice.id
        submenu(in: menu, titled: "Double-Tap to Open")?.items.forEach {
            $0.state = ($0.representedObject as? String) == tapID ? .on : .off
        }

        let update = menuItem(in: menu, action: #selector(updateClicked))
        update?.title = availableUpdateTitle ?? ""
        update?.isHidden = availableUpdateTitle == nil
        menuItem(in: menu, action: #selector(toggleAutoUpdate(_:)))?.state = autoUpdateEnabled ? .on : .off
    }

    var autoUpdateEnabled: Bool {
        UserDefaults.standard.object(forKey: "autoUpdate") as? Bool ?? true
    }

    @objc func toggleAutoUpdate(_ sender: NSMenuItem) {
        UserDefaults.standard.set(!autoUpdateEnabled, forKey: "autoUpdate")
        sender.state = autoUpdateEnabled ? .on : .off
    }

    var installedViaBrew: Bool {
        ["/opt/homebrew/Caskroom/noot", "/usr/local/Caskroom/noot"]
            .contains { FileManager.default.fileExists(atPath: $0) }
    }

    func checkForUpdates() {
        guard let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let url = URL(string: "https://api.github.com/repos/connect-kai/noot/releases/latest")
        else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            if latest.compare(current, options: .numeric) == .orderedDescending {
                DispatchQueue.main.async {
                    guard let self else { return }
                    if self.autoUpdateEnabled {
                        self.autoUpdate(to: latest)
                    } else {
                        self.availableUpdateTitle = self.installedViaBrew
                            ? "Update v\(latest) — copy brew command"
                            : "Update v\(latest) available…"
                        if let menu = self.statusItem?.menu { self.refreshMenu(menu) }
                    }
                }
            }
        }.resume()
    }

    var updating = false

    func autoUpdate(to version: String) {
        guard !updating else { return }
        updating = true
        availableUpdateTitle = "Updating to v\(version)…"
        if let menu = statusItem?.menu { refreshMenu(menu) }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let ok = self.installedViaBrew ? self.brewUpgrade() : self.selfReplace(version)
            DispatchQueue.main.async {
                if ok {
                    self.relaunch()
                } else {
                    self.updating = false
                    self.availableUpdateTitle = self.installedViaBrew
                        ? "Update v\(version) — copy brew command"
                        : "Update v\(version) available…"
                    if let menu = self.statusItem?.menu { self.refreshMenu(menu) }
                }
            }
        }
    }

    func brewUpgrade() -> Bool {
        guard let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first(where: { FileManager.default.fileExists(atPath: $0) }) else { return false }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: brew)
        p.arguments = ["upgrade", "--cask", "connect-kai/tap/noot"]
        guard (try? p.run()) != nil else { return false }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return false }
        // Homebrew 6 quarantines the fresh install; strip it or the relaunch trips Gatekeeper
        let x = Process()
        x.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        x.arguments = ["-dr", "com.apple.quarantine", Bundle.main.bundlePath]
        try? x.run()
        x.waitUntilExit()
        return true
    }

    // manual installs: download the release zip and swap our own bundle
    func selfReplace(_ version: String) -> Bool {
        guard let url = URL(string: "https://github.com/connect-kai/noot/releases/download/v\(version)/Noot-\(version).zip"),
              let data = try? Data(contentsOf: url) else { return false }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("noot-\(version)")
        try? FileManager.default.removeItem(at: tmp)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let zip = tmp.appendingPathComponent("noot.zip")
        guard (try? data.write(to: zip)) != nil else { return false }
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", zip.path, tmp.path]
        guard (try? unzip.run()) != nil else { return false }
        unzip.waitUntilExit()
        let newApp = tmp.appendingPathComponent("Noot.app")
        guard unzip.terminationStatus == 0,
              FileManager.default.fileExists(atPath: newApp.appendingPathComponent("Contents/MacOS/Noot").path)
        else { return false }
        let current = Bundle.main.bundleURL
        do {
            try FileManager.default.trashItem(at: current, resultingItemURL: nil)
            try FileManager.default.moveItem(at: newApp, to: current)
            return true
        } catch { return false }
    }

    func relaunch() {
        let sh = Process()
        sh.executableURL = URL(fileURLWithPath: "/bin/sh")
        sh.arguments = ["-c", "sleep 1; /usr/bin/open \"\(Bundle.main.bundlePath)\""]
        try? sh.run()
        NSApp.terminate(nil)
    }

    @objc func updateClicked() {
        if installedViaBrew {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("brew upgrade --cask connect-kai/tap/noot", forType: .string)
            flashIcon()
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/connect-kai/noot/releases/latest")!)
        }
    }

    @objc func changeIcon(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        UserDefaults.standard.set(symbol, forKey: "statusIcon")
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Noot")
        sender.menu?.items.forEach { $0.state = ($0.representedObject as? String) == symbol ? .on : .off }
        if let menu = statusItem?.menu { refreshMenu(menu) }
    }

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        if let window = shortcutRecorderController?.window, window.isVisible {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    // double-tap command toggles the panel; the global monitor needs Accessibility permission.
    // Never auto-prompt — the per-launch AX dialog is hostile; the menu item handles granting.
    func installDoubleShift() {
        NSLog("accessibility trusted: \(AXIsProcessTrusted())")
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] e in
            self?.handleShiftTap(e)
        }
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] e in
            self?.handleShiftTap(e)
            return e
        }
    }

    func handleShiftTap(_ e: NSEvent) {
        guard openingShortcutsEnabled else {
            lastShiftTap = 0
            shiftWasDown = false
            return
        }
        guard let target = doubleTapChoice.flag else { lastShiftTap = 0; shiftWasDown = false; return }
        guard e.type == .flagsChanged else { lastShiftTap = 0; return } // any real key (⌘C, ⌘D…) cancels the tap
        let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == target {
            if !shiftWasDown {
                if e.timestamp - lastShiftTap < 0.35 {
                    lastShiftTap = 0
                    DispatchQueue.main.async { self.toggle(atMouse: true) }
                } else {
                    lastShiftTap = e.timestamp
                }
            }
            shiftWasDown = true
        } else {
            shiftWasDown = false
            if !flags.isEmpty { lastShiftTap = 0 } // cmd+shift etc. is not a tap
        }
    }

    func installEditMenu() {
        let main = NSMenu()
        let holder = NSMenuItem()
        main.addItem(holder)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        for (title, key, action) in [("Find…", "f", NSFindPanelAction.showFindPanel),
                                     ("Find Next", "g", .next),
                                     ("Find Previous", "G", .previous)] {
            let item = NSMenuItem(title: title, action: #selector(NSTextView.performFindPanelAction(_:)),
                                  keyEquivalent: key)
            item.tag = Int(action.rawValue)
            edit.addItem(item)
        }
        edit.addItem(.separator())
        edit.addItem(withTitle: "Quick Look", action: #selector(NootTextView.quickLookLink(_:)), keyEquivalent: "y")
        holder.submenu = edit
        NSApp.mainMenu = main
    }

    func installHotKeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            DispatchQueue.main.async {
                guard let d = NSApp.delegate as? AppDelegate else { return }
                if hk.id == 2 {
                    d.quickCapture()
                } else if d.openingShortcutsEnabled {
                    d.togglePanel()
                }
            }
            return noErr
        }, 1, &eventType, nil, &hotKeyHandlerRef)

        let openingStatus = registerOpeningHotKey(openingShortcut)
        if openingStatus != noErr {
            NSLog("Could not register opening shortcut \(openingShortcut.displayName): \(openingStatus)")
            openingShortcutsEnabled = false
            // rescue only: don't overwrite a saved "hidden" choice, and put the
            // icon away again once the shortcut is working
            if !isMenuBarVisible {
                setMenuBarVisible(true, persist: false)
                menuBarShownForShortcutPause = true
            }
            updateShortcutMenu()
        }

        let captureID = EventHotKeyID(signature: OSType(0x4E4F4F54), id: 2) // 'NOOT'
        let captureStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(cmdKey | optionKey),
            captureID,
            GetEventDispatcherTarget(),
            0,
            &captureHotKeyRef)
        if captureStatus != noErr {
            NSLog("Could not register clipboard shortcut: \(captureStatus)")
        }
    }

    @discardableResult
    func registerOpeningHotKey(_ shortcut: OpeningShortcut) -> OSStatus {
        let toggleID = EventHotKeyID(signature: OSType(0x4E4F4F54), id: 1) // 'NOOT'
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            toggleID,
            GetEventDispatcherTarget(),
            0,
            &newRef)
        if status == noErr { hotKeyRef = newRef }
        return status
    }

    func unregisterOpeningHotKey() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    func validateOpeningShortcut(_ shortcut: OpeningShortcut) -> OSStatus {
        let toggleID = EventHotKeyID(signature: OSType(0x4E4F4F54), id: 1)
        var temporaryRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            toggleID,
            GetEventDispatcherTarget(),
            0,
            &temporaryRef)
        if let temporaryRef { UnregisterEventHotKey(temporaryRef) }
        return status
    }

    @objc func showShortcutRecorder() {
        // reuse the open window: a second controller would orphan the first one
        if let existing = shortcutRecorderController {
            existing.showWindow(nil)
            return
        }
        let controller = ShortcutRecorderController(current: openingShortcut) { [weak self] shortcut in
            self?.applyOpeningShortcut(shortcut) ?? false
        }
        controller.onClose = { [weak self] in self?.shortcutRecorderController = nil }
        shortcutRecorderController = controller
        controller.showWindow(nil)
    }

    func applyOpeningShortcut(_ shortcut: OpeningShortcut) -> Bool {
        guard shortcut != openingShortcut else { return true }
        let previous = openingShortcut
        let status: OSStatus
        if openingShortcutsEnabled {
            unregisterOpeningHotKey()
            status = registerOpeningHotKey(shortcut)
            if status != noErr { _ = registerOpeningHotKey(previous) }
        } else {
            status = validateOpeningShortcut(shortcut)
        }
        guard status == noErr else {
            showAlert(
                title: "Shortcut unavailable",
                message: "Noot could not register \(shortcut.displayName). It may be reserved by macOS or already used by Noot. Press a different shortcut.")
            return false
        }

        openingShortcut = shortcut
        openingShortcut.save()
        updateShortcutMenu()
        return true
    }

    @objc func toggleOpeningShortcuts() {
        if openingShortcutsEnabled {
            if !isMenuBarVisible {
                // A temporary status item prevents a lockout after the panel is
                // hidden. The user's saved visibility preference stays off.
                setMenuBarVisible(true, persist: false)
                menuBarShownForShortcutPause = true
            }
            openingShortcutsEnabled = false
            unregisterOpeningHotKey()
            lastShiftTap = 0
            shiftWasDown = false
        } else {
            let status = registerOpeningHotKey(openingShortcut)
            guard status == noErr else {
                showAlert(
                    title: "Shortcut unavailable",
                    message: "Noot could not re-register \(openingShortcut.displayName). Choose a different opening shortcut.")
                return
            }
            openingShortcutsEnabled = true
            if menuBarShownForShortcutPause {
                menuBarShownForShortcutPause = false
                DispatchQueue.main.async { [weak self] in
                    self?.setMenuBarVisible(false, persist: false)
                }
            }
        }
        updateShortcutMenu()
    }

    func updateShortcutMenu() {
        if let menu = statusItem?.menu { refreshMenu(menu) }
    }

    @objc func quickCapture() {
        guard let s = NSPasteboard.general.string(forType: .string),
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NotesStore.shared.capture(s)
        flashIcon()
    }

    func flashIcon() {
        statusItem?.button?.image = NSImage(systemSymbolName: "checkmark.circle.fill",
                                            accessibilityDescription: "Captured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            let name = UserDefaults.standard.string(forKey: "statusIcon") ?? "note.text"
            self?.statusItem?.button?.image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: "Noot")
        }
    }

    @objc func showDaily() {
        NotesStore.shared.openDaily()
        if !panel.isVisible { togglePanel() } else { focusEditor() }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu(menu)
    }

    @objc func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc func toggleLoginItem(_ sender: NSMenuItem) {
        guard Bundle.main.bundleIdentifier != nil else { return } // needs the .app bundle
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(title: "Could not update Open at Login", message: error.localizedDescription)
        }
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc func togglePanel() { toggle(atMouse: false) }

    func toggle(atMouse: Bool) {
        if panel.isVisible && panel.isKeyWindow {
            panel.orderOut(nil)
            return
        }
        if atMouse {
            moveToMouse()
            placed = true
        } else if !placed, let screen = NSScreen.main {
            let f = screen.visibleFrame
            let s = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: f.midX - s.width / 2,
                                         y: f.midY - s.height / 2 + f.height * 0.12))
            placed = true
        }
        panel.makeKeyAndOrderFront(nil)
        focusEditor()
    }

    // pop up under the cursor, clamped to that screen's visible area
    func moveToMouse() {
        let m = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(m, $0.frame, false) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        let s = panel.frame.size
        var origin = NSPoint(x: m.x - s.width / 2, y: m.y - s.height + 28)
        origin.x = max(vf.minX + 8, min(origin.x, vf.maxX - s.width - 8))
        origin.y = max(vf.minY + 8, min(origin.y, vf.maxY - s.height - 8))
        panel.setFrameOrigin(origin)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
