import Foundation

// VS Code-style whole-line edits as pure functions (UTF-16 offsets), so they
// are testable without a text view. Each returns the replacement to apply.
enum LineOps {
    struct Edit: Equatable {
        let range: NSRange       // characters to replace
        let text: String         // replacement
        let selection: NSRange   // selection after the edit
    }

    // The full lines covered by `sel`. A selection ending exactly at a line
    // start does not pull in that next line.
    static func lines(_ ns: NSString, _ sel: NSRange) -> NSRange {
        var s = sel
        if s.length > 0, ns.character(at: NSMaxRange(s) - 1) == 10 { s.length -= 1 }
        return ns.lineRange(for: s)
    }

    static func move(_ text: String, _ sel: NSRange, up: Bool) -> Edit? {
        let ns = text as NSString
        let block = lines(ns, sel)
        var b = ns.substring(with: block)
        if up {
            guard block.location > 0 else { return nil }
            let prev = ns.lineRange(for: NSRange(location: block.location - 1, length: 0))
            var p = ns.substring(with: prev)
            if !b.hasSuffix("\n") { b += "\n"; p.removeLast() } // block was the last line
            return Edit(range: NSUnionRange(prev, block), text: b + p,
                        selection: NSRange(location: sel.location - prev.length, length: sel.length))
        }
        guard NSMaxRange(block) < ns.length else { return nil }
        let next = ns.lineRange(for: NSRange(location: NSMaxRange(block), length: 0))
        var n = ns.substring(with: next)
        if !n.hasSuffix("\n") { n += "\n"; b.removeLast() } // next was the last line
        let shift = (n as NSString).length
        return Edit(range: NSUnionRange(block, next), text: n + b,
                    selection: NSRange(location: sel.location + shift,
                                       length: min(sel.length, (b as NSString).length)))
    }

    static func copy(_ text: String, _ sel: NSRange, up: Bool) -> Edit {
        let ns = text as NSString
        let block = lines(ns, sel)
        var b = ns.substring(with: block)
        if !b.hasSuffix("\n") { b = up ? b + "\n" : "\n" + b } // last line has no newline
        let at = up ? block.location : NSMaxRange(block)
        let shift = up ? 0 : (b as NSString).length
        return Edit(range: NSRange(location: at, length: 0), text: b,
                    selection: NSRange(location: sel.location + shift, length: sel.length))
    }

    static func delete(_ text: String, _ sel: NSRange) -> Edit {
        let ns = text as NSString
        var block = lines(ns, sel)
        if block.location > 0, NSMaxRange(block) == ns.length,
           ns.character(at: block.location - 1) == 10 {
            // last line: eat the newline before it too
            block = NSRange(location: block.location - 1, length: block.length + 1)
        }
        return Edit(range: block, text: "", selection: NSRange(location: block.location, length: 0))
    }

    // ⌘L: select the caret's line; repeated presses grow the selection a line at a time
    static func selectLine(_ text: String, _ sel: NSRange) -> NSRange {
        let ns = text as NSString
        let grown = NSRange(location: sel.location,
                            length: min(sel.length + (sel.length > 0 ? 1 : 0), ns.length - sel.location))
        return ns.lineRange(for: grown)
    }

    // ⌃J: join the selected lines (or the caret line with the next) with single spaces
    static func join(_ text: String, _ sel: NSRange) -> Edit? {
        let ns = text as NSString
        var block = lines(ns, sel)
        if !ns.substring(with: block).dropLast(ns.substring(with: block).hasSuffix("\n") ? 1 : 0).contains("\n") {
            guard NSMaxRange(block) < ns.length else { return nil }
            block = NSUnionRange(block, ns.lineRange(for: NSRange(location: NSMaxRange(block), length: 0)))
        }
        var raw = ns.substring(with: block)
        let newline = raw.hasSuffix("\n")
        if newline { raw.removeLast() }
        let parts = raw.components(separatedBy: "\n")
        var joined = parts[0].replacingOccurrences(of: "[ \\t]+$", with: "", options: .regularExpression)
        let firstLength = (joined as NSString).length
        for part in parts.dropFirst() {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { joined += (joined.isEmpty ? "" : " ") + trimmed }
        }
        return Edit(range: block, text: joined + (newline ? "\n" : ""),
                    selection: NSRange(location: block.location + firstLength, length: 0))
    }

    // Sort the selected lines; with no selection, the whole note.
    static func sort(_ text: String, _ sel: NSRange, descending: Bool) -> Edit {
        let ns = text as NSString
        let block = sel.length == 0 ? NSRange(location: 0, length: ns.length) : lines(ns, sel)
        var raw = ns.substring(with: block)
        let newline = raw.hasSuffix("\n")
        if newline { raw.removeLast() }
        let sorted = raw.components(separatedBy: "\n").sorted {
            let order = $0.localizedCaseInsensitiveCompare($1)
            return descending ? order == .orderedDescending : order == .orderedAscending
        }
        let out = sorted.joined(separator: "\n") + (newline ? "\n" : "")
        return Edit(range: block, text: out,
                    selection: NSRange(location: block.location,
                                       length: sel.length == 0 ? 0 : (out as NSString).length - (newline ? 1 : 0)))
    }

    // ⌘/: `<!-- … -->` per line in Markdown, `// ` in code mode; all commented → uncomment
    static func toggleComment(_ text: String, _ sel: NSRange, code: Bool) -> Edit {
        let (open, close) = code ? ("// ", "") : ("<!-- ", " -->")
        let ns = text as NSString
        let block = lines(ns, sel)
        var raw = ns.substring(with: block)
        let newline = raw.hasSuffix("\n")
        if newline { raw.removeLast() }
        var lines = raw.components(separatedBy: "\n")
        let bodies = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let bare = (open.trimmingCharacters(in: .whitespaces), close.trimmingCharacters(in: .whitespaces))
        let allCommented = !bodies.isEmpty && bodies.allSatisfy { $0.hasPrefix(bare.0) && $0.hasSuffix(bare.1) }
        for index in lines.indices {
            let indent = lines[index].prefix { $0 == " " || $0 == "\t" }
            var body = String(lines[index].dropFirst(indent.count))
            if body.isEmpty { continue }
            if allCommented {
                body.removeFirst(body.hasPrefix(open) ? open.count : bare.0.count)
                if !bare.1.isEmpty { body.removeLast(body.hasSuffix(close) ? close.count : bare.1.count) }
            } else {
                body = open + body + close
            }
            lines[index] = indent + body
        }
        let out = lines.joined(separator: "\n") + (newline ? "\n" : "")
        let selection: NSRange
        if sel.length > 0 {
            selection = NSRange(location: block.location, length: (out as NSString).length - (newline ? 1 : 0))
        } else {
            let shift = (allCommented ? -1 : 1) * (open as NSString).length
            selection = NSRange(location: min(max(block.location, sel.location + shift),
                                              block.location + (out as NSString).length), length: 0)
        }
        return Edit(range: block, text: out, selection: selection)
    }

    static func indent(ofLineAt location: Int, in text: String) -> String {
        let ns = text as NSString
        let line = ns.substring(with: ns.lineRange(for: NSRange(location: min(location, ns.length), length: 0)))
        return String(line.prefix { $0 == " " || $0 == "\t" })
    }
}
