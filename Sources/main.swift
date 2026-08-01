import SwiftUI
import Carbon.HIToolbox
import ApplicationServices
import ServiceManagement

let accent = Color(red: 1, green: 0.39, blue: 0.39) // raycast-ish #FF6363
let accentNS = NSColor(red: 1, green: 0.39, blue: 0.39, alpha: 1)
weak var gTextView: NSTextView?

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
        // Documents so notes are user-visible and covered by iCloud/Time Machine backups;
        // first access triggers the macOS "allow access to Documents" prompt
        dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Noot")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacyDirs = [
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FloatNotes"),
            docs.appendingPathComponent("FloatNotes"),
        ]
        for legacy in legacyDirs {
            guard let old = try? FileManager.default.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil) else { continue }
            for f in old where f.pathExtension == "md" {
                try? FileManager.default.moveItem(at: f, to: dir.appendingPathComponent(f.lastPathComponent))
            }
        }
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { $0.pathExtension == "md" }
        notes = files.map {
            let mod = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return Note(url: $0, text: (try? String(contentsOf: $0, encoding: .utf8)) ?? "", lastEdited: mod)
        }.sorted { $0.lastEdited > $1.lastEdited }
        if notes.isEmpty {
            newNote(initial: "# Welcome\n\nFloating notes, Raycast style.\n\n- **⌥⌘N** toggle window, `esc` hides\n- **⌘N** new note, **⌘P** search notes, **⌘K** actions\n- **⌘=** / **⌘-** zoom\n\n- [ ] click a checkbox to toggle it\n- [x] like this one\n\nFiles live in `~/Documents/Noot`.")
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

    func delete(_ note: Note) {
        try? FileManager.default.trashItem(at: note.url, resultingItemURL: nil)
        notes.removeAll { $0.id == note.id }
        if notes.isEmpty { newNote() }
        currentIndex = min(currentIndex, notes.count - 1)
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
        ActionItem(id: "Daily Note", icon: "calendar", keys: ["⌘", "D"]) { s.openDaily() },
        ActionItem(id: "Duplicate Note", icon: "plus.square.on.square", keys: []) {
            s.newNote(initial: s.current?.text ?? "")
        },
        ActionItem(id: "Copy Note", icon: "doc.on.doc", keys: []) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(s.current?.text ?? "", forType: .string)
        },
        ActionItem(id: "Delete Note", icon: "trash", keys: ["⌘", "⌫"]) {
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
}

// MARK: - Markdown editor (NSTextView + regex highlighting)

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let tv = scroll.documentView as! NSTextView
        tv.delegate = context.coordinator
        tv.layoutManager?.delegate = context.coordinator // forces TextKit 1; needed to hide syntax glyphs
        tv.isRichText = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        scroll.drawsBackground = false
        tv.textContainerInset = NSSize(width: 18, height: 16)
        tv.insertionPointColor = accentNS
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.linkTextAttributes = [.cursor: NSCursor.pointingHand]
        tv.string = text
        gTextView = tv
        context.coordinator.highlight(tv)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        let tv = scroll.documentView as! NSTextView
        let size = NotesStore.shared.fontSize
        if tv.string != text {
            tv.string = text
            context.coordinator.highlight(tv)
        } else if context.coordinator.lastFontSize != size {
            context.coordinator.highlight(tv)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSLayoutManagerDelegate {
        var parent: MarkdownEditor
        var lastFontSize: CGFloat = 0
        var hiddenIndexes = IndexSet() // syntax-marker chars rendered as no glyph
        var lastPara = NSRange(location: NSNotFound, length: 0)
        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ n: Notification) {
            guard let tv = n.object as? NSTextView else { return }
            autoConvert(tv)
            parent.text = tv.string
            highlight(tv)
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
            if caretLines(tv).location != lastPara.location {
                DispatchQueue.main.async { [weak self, weak tv] in
                    guard let self, let tv else { return }
                    self.highlight(tv)
                }
            }
        }

        func caretLines(_ tv: NSTextView) -> NSRange {
            let ns = tv.string as NSString
            guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
            var sel = tv.selectedRange()
            sel.location = min(sel.location, ns.length)
            sel.length = min(sel.length, ns.length - sel.location)
            return ns.lineRange(for: sel)
        }

        func layoutManager(_ lm: NSLayoutManager,
                           shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                           properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
                           characterIndexes: UnsafePointer<Int>,
                           font: NSFont,
                           forGlyphRange glyphRange: NSRange) -> Int {
            guard !hiddenIndexes.isEmpty else { return 0 }
            var props = Array(UnsafeBufferPointer(start: properties, count: glyphRange.length))
            var changed = false
            for i in 0 ..< glyphRange.length where hiddenIndexes.contains(characterIndexes[i]) {
                props[i] = .null
                changed = true
            }
            guard changed else { return 0 }
            lm.setGlyphs(glyphs, properties: props, characterIndexes: characterIndexes,
                         font: font, forGlyphRange: glyphRange)
            return glyphRange.length
        }

        // esc hides the window; enter continues lists/checkboxes
        func textView(_ tv: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.cancelOperation(_:)) || sel == NSSelectorFromString("complete:") {
                tv.window?.orderOut(nil)
                return true
            }
            if sel == #selector(NSResponder.insertNewline(_:)) { return continueList(tv) }
            return false
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

        // ponytail: regexes recompiled per keystroke; fine at note size, cache if it ever lags
        func highlight(_ tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let str = tv.string
            let ns = str as NSString
            let full = NSRange(location: 0, length: ns.length)
            let size = NotesStore.shared.fontSize
            lastFontSize = size
            let dim = NSColor.tertiaryLabelColor
            let base: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: size),
                .foregroundColor: NSColor.labelColor,
            ]
            storage.beginEditing()
            storage.setAttributes(base, range: full)

            func re(_ p: String, _ o: NSRegularExpression.Options = [.anchorsMatchLines],
                    _ f: @escaping (NSTextCheckingResult) -> Void) {
                guard let r = try? NSRegularExpression(pattern: p, options: o) else { return }
                r.enumerateMatches(in: str, range: full) { m, _, _ in if let m { f(m) } }
            }
            func add(_ r: NSRange, _ a: [NSAttributedString.Key: Any]) {
                if r.location != NSNotFound { storage.addAttributes(a, range: r) }
            }

            var hide: [NSRange] = [] // marker ranges to render glyph-less ("converted" look)

            // headers: big font, hidden # marker
            for (i, hSize) in [(1, size + 11), (2, size + 6), (3, size + 2)] {
                let weight: NSFont.Weight = i == 3 ? .semibold : .bold
                re("^(#{\(i)} )(.*)$") { m in
                    add(m.range, [.font: NSFont.systemFont(ofSize: hSize, weight: weight)])
                    add(m.range(at: 1), [.foregroundColor: dim])
                    hide.append(m.range(at: 1))
                }
            }
            // bold / italic / strikethrough with hidden markers
            re("(\\*\\*)([^*\\n]+)(\\*\\*)") { m in
                add(m.range(at: 2), [.font: NSFont.systemFont(ofSize: size, weight: .bold)])
                add(m.range(at: 1), [.foregroundColor: dim])
                add(m.range(at: 3), [.foregroundColor: dim])
                hide.append(m.range(at: 1)); hide.append(m.range(at: 3))
            }
            let italic = NSFontManager.shared.convert(NSFont.systemFont(ofSize: size), toHaveTrait: .italicFontMask)
            re("(?<![\\w*])(\\*)([^*\\n]+)(\\*)(?![\\w*])") { m in
                add(m.range(at: 2), [.font: italic])
                add(m.range(at: 1), [.foregroundColor: dim])
                add(m.range(at: 3), [.foregroundColor: dim])
                hide.append(m.range(at: 1)); hide.append(m.range(at: 3))
            }
            re("(~~)([^~\\n]+)(~~)") { m in
                add(m.range(at: 2), [.strikethroughStyle: NSUnderlineStyle.single.rawValue])
                add(m.range(at: 1), [.foregroundColor: dim])
                add(m.range(at: 3), [.foregroundColor: dim])
                hide.append(m.range(at: 1)); hide.append(m.range(at: 3))
            }
            // list markers
            re("^\\s*(?:[-*+]|\\d+\\.)(?= )") { m in add(m.range, [.foregroundColor: accentNS]) }
            // checkboxes (with or without a leading bullet): accent marker, clickable via fake link
            re("^(\\s*(?:[-*+] )?)(\\[[ x]\\])(?= )") { m in
                let box = m.range(at: 2)
                add(box, [.foregroundColor: accentNS,
                          .link: URL(string: "fncheck://\(box.location)")!])
            }
            re("^\\s*(?:[-*+] )?\\[x\\] (.*)$") { m in
                add(m.range(at: 1), [.foregroundColor: NSColor.secondaryLabelColor,
                                     .strikethroughStyle: NSUnderlineStyle.single.rawValue])
            }
            // quotes
            re("^> .*$") { m in add(m.range, [.foregroundColor: NSColor.secondaryLabelColor]) }
            // links: [text](url) and bare urls; brackets + url hidden
            re("(\\[)([^\\]\\n]+)(\\]\\()([^)\\n]+)(\\))") { m in
                add(m.range, [.foregroundColor: dim])
                add(m.range(at: 2), [.foregroundColor: accentNS,
                                     .underlineStyle: NSUnderlineStyle.single.rawValue])
                if let url = URL(string: ns.substring(with: m.range(at: 4))) {
                    add(m.range(at: 2), [.link: url])
                }
                for i in [1, 3, 4, 5] { hide.append(m.range(at: i)) }
            }
            re("(?<![(\\]])https?://[^\\s)]+") { m in
                if let url = URL(string: ns.substring(with: m.range)) {
                    add(m.range, [.foregroundColor: accentNS,
                                  .underlineStyle: NSUnderlineStyle.single.rawValue, .link: url])
                }
            }
            // inline code, then fenced blocks on top; backticks hidden
            re("(`)([^`\\n]+)(`)") { m in
                add(m.range, [.font: NSFont.monospacedSystemFont(ofSize: size - 1.5, weight: .regular),
                              .foregroundColor: accentNS,
                              .backgroundColor: NSColor.labelColor.withAlphaComponent(0.06)])
                hide.append(m.range(at: 1)); hide.append(m.range(at: 3))
            }
            re("(```[a-zA-Z]*)([\\s\\S]*?)(```)", []) { m in
                add(m.range, [.font: NSFont.monospacedSystemFont(ofSize: size - 1.5, weight: .regular),
                              .foregroundColor: NSColor.labelColor,
                              .backgroundColor: NSColor.labelColor.withAlphaComponent(0.06)])
                hide.append(m.range(at: 1)); hide.append(m.range(at: 3))
            }
            storage.endEditing()
            tv.typingAttributes = base

            // hide syntax everywhere except the line(s) the caret is on
            let reveal = caretLines(tv)
            lastPara = reveal
            let old = hiddenIndexes
            hiddenIndexes = IndexSet()
            for r in hide where r.location != NSNotFound && NSIntersectionRange(r, reveal).length == 0 {
                hiddenIndexes.insert(integersIn: r.location ..< NSMaxRange(r))
            }
            // invalidate only where hidden-state changed — full-range invalidation
            // every keystroke is what made typing glitch
            if let lm = tv.layoutManager {
                for chunk in old.symmetricDifference(hiddenIndexes).rangeView {
                    guard chunk.lowerBound < ns.length else { continue }
                    let r = NSRange(location: chunk.lowerBound,
                                    length: min(chunk.count, ns.length - chunk.lowerBound))
                    lm.invalidateGlyphs(forCharacterRange: r, changeInLength: 0, actualCharacterRange: nil)
                    lm.invalidateLayout(forCharacterRange: r, actualCharacterRange: nil)
                }
            }
        }
    }
}

// MARK: - UI

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_: NSVisualEffectView, context: Context) {}
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
            tb("link", "Link  ⌘⇧L") { Fmt.link() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
            Text("\(store.current?.text.count ?? 0) characters")
                .font(.caption).foregroundStyle(.tertiary)
            Button { toggleOverlay(.actions) } label: {
                HStack(spacing: 4) { Text("Actions"); kbd("⌘"); kbd("K") }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
            hiddenShortcuts
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    var hiddenShortcuts: some View {
        Group {
            Button("") { store.newNote(); ui.overlay = nil; focusEditor() }
                .keyboardShortcut("n", modifiers: .command)
            Button("") { store.openDaily(); ui.overlay = nil; focusEditor() }
                .keyboardShortcut("d", modifiers: .command)
            Button("") { if let n = store.current { store.delete(n) } }
                .keyboardShortcut(.delete, modifiers: .command)
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
                        }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(i == ui.selIndex ? Color.primary.opacity(0.1) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .onTapGesture { store.select(note); ui.overlay = nil; focusEditor() }
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

extension View {
    func overlayChrome() -> some View {
        self
            .font(.system(size: 12.5))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.1)))
            .padding(.horizontal, 10)
            .padding(.bottom, 42)
    }
}

struct RootView: View {
    var body: some View {
        ContentView()
            .background(VisualEffect())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.12)))
            .ignoresSafeArea()
    }
}

// MARK: - Panel + app

final class NotesPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NotesPanel!
    var statusItem: NSStatusItem!
    var iconMenu: NSMenu!
    var hotKeyRef: EventHotKeyRef?
    var hotKeyRef2: EventHotKeyRef?
    var placed = false
    var lastShiftTap: TimeInterval = 0
    var shiftWasDown = false

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
        panel.contentView = NSHostingView(rootView: RootView())

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let iconName = UserDefaults.standard.string(forKey: "statusIcon") ?? "note.text"
        statusItem.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Noot")
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Toggle Noot (⇧⇧ or ⌥⌘N)", action: #selector(togglePanel), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let daily = NSMenuItem(title: "Open Daily Note (⌘D)", action: #selector(showDaily), keyEquivalent: "")
        daily.target = self
        menu.addItem(daily)
        let capture = NSMenuItem(title: "Capture Clipboard (⌥⌘C)", action: #selector(quickCapture), keyEquivalent: "")
        capture.target = self
        menu.addItem(capture)
        let iconItem = NSMenuItem(title: "Icon", action: nil, keyEquivalent: "")
        iconMenu = NSMenu(title: "Icon")
        for (symbol, label) in [("note.text", "Note"), ("sparkles", "Sparkles"),
                                ("scribble.variable", "Scribble"), ("pencil.and.outline", "Pencil"),
                                ("bolt.fill", "Bolt"), ("leaf.fill", "Leaf"),
                                ("moon.stars.fill", "Moon"), ("flame.fill", "Flame")] {
            let item = NSMenuItem(title: label, action: #selector(changeIcon(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = symbol
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            item.state = symbol == iconName ? .on : .off
            iconMenu.addItem(item)
        }
        iconItem.submenu = iconMenu
        menu.addItem(iconItem)
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        login.target = self
        login.isEnabled = Bundle.main.bundleIdentifier != nil
        login.state = (Bundle.main.bundleIdentifier != nil && SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        // first bundled launch: enable launch-at-login once; the menu item can turn it off
        if Bundle.main.bundleIdentifier != nil, !UserDefaults.standard.bool(forKey: "didAutoLogin") {
            UserDefaults.standard.set(true, forKey: "didAutoLogin")
            try? SMAppService.mainApp.register()
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }

        installEditMenu() // key-equivalents (⌘C/⌘V/⌘Z) need a main menu even in accessory apps
        registerHotKey()
        installDoubleShift()
        togglePanel()
    }

    @objc func changeIcon(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        UserDefaults.standard.set(symbol, forKey: "statusIcon")
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Noot")
        iconMenu.items.forEach { $0.state = ($0.representedObject as? String) == symbol ? .on : .off }
    }

    // double-tap shift toggles the panel; the global monitor needs Accessibility permission
    func installDoubleShift() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSLog("accessibility trusted: \(trusted)")
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] e in
            self?.handleShiftTap(e)
        }
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] e in
            self?.handleShiftTap(e)
            return e
        }
    }

    func handleShiftTap(_ e: NSEvent) {
        guard e.type == .flagsChanged else { lastShiftTap = 0; return } // any real key resets
        let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .shift {
            if !shiftWasDown {
                if e.timestamp - lastShiftTap < 0.35 {
                    lastShiftTap = 0
                    DispatchQueue.main.async { self.togglePanel() }
                } else {
                    lastShiftTap = e.timestamp
                }
            }
            shiftWasDown = true
        } else {
            shiftWasDown = false
            if !flags.isEmpty { lastShiftTap = 0 } // shift+cmd etc. is not a tap
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
        holder.submenu = edit
        NSApp.mainMenu = main
    }

    func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            DispatchQueue.main.async {
                guard let d = NSApp.delegate as? AppDelegate else { return }
                if hk.id == 2 { d.quickCapture() } else { d.togglePanel() }
            }
            return noErr
        }, 1, &eventType, nil, nil)
        let toggleID = EventHotKeyID(signature: OSType(0x464C4E54), id: 1) // 'FLNT'
        RegisterEventHotKey(UInt32(kVK_ANSI_N), UInt32(cmdKey | optionKey), toggleID,
                            GetEventDispatcherTarget(), 0, &hotKeyRef)
        let captureID = EventHotKeyID(signature: OSType(0x464C4E54), id: 2)
        RegisterEventHotKey(UInt32(kVK_ANSI_C), UInt32(cmdKey | optionKey), captureID,
                            GetEventDispatcherTarget(), 0, &hotKeyRef2)
    }

    @objc func quickCapture() {
        guard let s = NSPasteboard.general.string(forType: .string),
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NotesStore.shared.capture(s)
        flashIcon()
    }

    func flashIcon() {
        statusItem.button?.image = NSImage(systemSymbolName: "checkmark.circle.fill",
                                           accessibilityDescription: "Captured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let name = UserDefaults.standard.string(forKey: "statusIcon") ?? "note.text"
            self.statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Noot")
        }
    }

    @objc func showDaily() {
        NotesStore.shared.openDaily()
        if !panel.isVisible { togglePanel() } else { focusEditor() }
    }

    @objc func toggleLoginItem(_ sender: NSMenuItem) {
        guard Bundle.main.bundleIdentifier != nil else { return } // needs the .app bundle
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        } else {
            try? SMAppService.mainApp.register()
        }
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc func togglePanel() {
        if panel.isVisible && panel.isKeyWindow {
            panel.orderOut(nil)
        } else {
            if !placed, let screen = NSScreen.main {
                let f = screen.visibleFrame
                let s = panel.frame.size
                panel.setFrameOrigin(NSPoint(x: f.midX - s.width / 2,
                                             y: f.midY - s.height / 2 + f.height * 0.12))
                placed = true
            }
            panel.makeKeyAndOrderFront(nil)
            focusEditor()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
