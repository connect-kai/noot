import AppKit
import Markdown

// MARK: - Markdown presentation model

enum NootMarkdownRole {
    case heading(Int)
    case strong
    case emphasis
    case strikethrough
    case inlineCode
    case codeBlock
    case blockQuote
    case link(URL?)
    case listMarker
    case checkbox(checked: Bool, location: Int)
    case checkedContent
}

struct NootMarkdownSpan {
    let range: NSRange
    let role: NootMarkdownRole
}

struct NootMarkdownPresentation {
    var spans: [NootMarkdownSpan] = []
    var syntaxRanges: [NSRange] = []
    var dimmedSyntaxRanges: [NSRange] = []
    var dividerRanges: [NSRange] = []
}

/// Converts swift-markdown's 1-based UTF-8 source locations to TextKit's
/// UTF-16 ranges. Keeping this conversion in one place is important for notes
/// that mix Markdown with CJK text or emoji.
private struct NootSourceMapper {
    let source: String
    private let lineStarts: [String.Index]
    private let lineStartUTF16Offsets: [Int]

    init(_ source: String) {
        self.source = source
        var starts = [source.startIndex]
        var offsets = [0]
        var utf16Offset = 0
        for character in source {
            utf16Offset += String(character).utf16.count
            if character == "\n" {
                let index = source.utf16.index(source.utf16.startIndex, offsetBy: utf16Offset)
                    .samePosition(in: source) ?? source.endIndex
                starts.append(index)
                offsets.append(utf16Offset)
            }
        }
        lineStarts = starts
        lineStartUTF16Offsets = offsets
    }

    func offset(for location: SourceLocation) -> Int? {
        let lineIndex = location.line - 1
        guard lineIndex >= 0, lineIndex < lineStarts.count else { return nil }
        let start = lineStarts[lineIndex]
        let end: String.Index
        if lineIndex + 1 < lineStarts.count {
            end = lineStarts[lineIndex + 1]
        } else {
            end = source.endIndex
        }
        let line = String(source[start ..< end])
        let byteOffset = max(0, location.column - 1)
        guard byteOffset <= line.utf8.count,
              let utf8Index = line.utf8.index(line.utf8.startIndex,
                                              offsetBy: byteOffset,
                                              limitedBy: line.utf8.endIndex),
              let stringIndex = utf8Index.samePosition(in: line),
              let utf16Index = stringIndex.samePosition(in: line.utf16)
        else { return nil }
        return lineStartUTF16Offsets[lineIndex]
            + line.utf16.distance(from: line.utf16.startIndex, to: utf16Index)
    }

    func range(for range: SourceRange?) -> NSRange? {
        guard let range,
              let lower = offset(for: range.lowerBound),
              let upper = offset(for: range.upperBound),
              lower <= upper
        else { return nil }
        return NSRange(location: lower, length: upper - lower)
    }
}

private struct NootMarkdownWalker: MarkupWalker {
    let source: String
    let ns: NSString
    let mapper: NootSourceMapper
    var presentation = NootMarkdownPresentation()

    init(source: String) {
        self.source = source
        ns = source as NSString
        mapper = NootSourceMapper(source)
    }

    mutating func visitHeading(_ heading: Heading) {
        if heading.level <= 3, let range = mapper.range(for: heading.range) {
            presentation.spans.append(.init(range: range, role: .heading(heading.level)))
            if let firstChild = heading.children.compactMap({ mapper.range(for: $0.range) }).first,
               firstChild.location > range.location {
                addSyntax(NSRange(location: range.location,
                                  length: firstChild.location - range.location))
            }
        }
        descendInto(heading)
    }

    mutating func visitStrong(_ strong: Strong) {
        addContainer(strong, role: .strong)
        descendInto(strong)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        addContainer(emphasis, role: .emphasis)
        descendInto(emphasis)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        addContainer(strikethrough, role: .strikethrough)
        descendInto(strikethrough)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        guard let range = mapper.range(for: inlineCode.range), range.length > 1 else { return }
        presentation.spans.append(.init(range: range, role: .inlineCode))
        let raw = ns.substring(with: range) as NSString
        var opening = 0
        while opening < raw.length, raw.character(at: opening) == 96 { opening += 1 }
        var closing = 0
        while closing < raw.length - opening,
              raw.character(at: raw.length - closing - 1) == 96 { closing += 1 }
        if opening > 0 {
            addSyntax(NSRange(location: range.location, length: opening), dimWhenRevealed: false)
        }
        if closing > 0 {
            addSyntax(NSRange(location: NSMaxRange(range) - closing, length: closing),
                      dimWhenRevealed: false)
        }
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        guard let range = mapper.range(for: codeBlock.range) else { return }
        presentation.spans.append(.init(range: range, role: .codeBlock))
        let raw = ns.substring(with: range) as NSString
        guard raw.length >= 3 else { return }
        let firstLine = raw.lineRange(for: NSRange(location: 0, length: 0))
        let firstText = raw.substring(with: firstLine)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard firstText.hasPrefix("```") || firstText.hasPrefix("~~~") else { return }
        addSyntax(NSRange(location: range.location + firstLine.location,
                          length: firstLine.length),
                  dimWhenRevealed: false)
        var tail = raw.length
        while tail > 0, CharacterSet.newlines.contains(UnicodeScalar(raw.character(at: tail - 1))!) {
            tail -= 1
        }
        guard tail > 0 else { return }
        let lastLine = raw.lineRange(for: NSRange(location: tail - 1, length: 0))
        if lastLine.location != firstLine.location {
            addSyntax(NSRange(location: range.location + lastLine.location,
                              length: min(lastLine.length, tail - lastLine.location)),
                      dimWhenRevealed: false)
        }
    }

    mutating func visitLink(_ link: Link) {
        addLinkedContainer(link, destination: link.destination)
        descendInto(link)
    }

    // Images intentionally remain Markdown text. Their alt label behaves like
    // an attachment link, matching Noot's released editor rather than drawing
    // an image into the text system.
    mutating func visitImage(_ image: Image) {
        addLinkedContainer(image, destination: image.source)
        descendInto(image)
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        if let range = mapper.range(for: blockQuote.range) {
            presentation.spans.append(.init(range: range, role: .blockQuote))
        }
        descendInto(blockQuote)
    }

    mutating func visitListItem(_ listItem: ListItem) {
        if let range = mapper.range(for: listItem.range), range.length > 0 {
            let line = ns.lineRange(for: NSRange(location: range.location, length: 0))
            let bounded = NSIntersectionRange(line, range)
            let text = ns.substring(with: bounded)
            if let marker = firstMatch("^[ \\t]*(?:[-*+]|\\d+\\.)(?= )", in: text) {
                let markerRange = NSRange(location: bounded.location + marker.location,
                                          length: marker.length)
                presentation.spans.append(.init(range: markerRange, role: .listMarker))
            }
            if let checkbox = listItem.checkbox,
               let box = firstMatch("\\[[ xX]\\]", in: text) {
                let boxRange = NSRange(location: bounded.location + box.location,
                                       length: box.length)
                let checked: Bool
                switch checkbox {
                case .checked: checked = true
                case .unchecked: checked = false
                }
                presentation.spans.append(.init(
                    range: boxRange,
                    role: .checkbox(checked: checked, location: boxRange.location)
                ))
                if checked {
                    var contentStart = NSMaxRange(boxRange)
                    if contentStart < NSMaxRange(bounded), ns.character(at: contentStart) == 32 {
                        contentStart += 1
                    }
                    if contentStart < NSMaxRange(bounded) {
                        presentation.spans.append(.init(
                            range: NSRange(location: contentStart,
                                           length: NSMaxRange(bounded) - contentStart),
                            role: .checkedContent
                        ))
                    }
                }
            }
        }
        descendInto(listItem)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        guard let range = mapper.range(for: thematicBreak.range) else { return }
        let marker = ns.substring(with: range)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard marker == "---" else { return }
        presentation.dividerRanges.append(range)
    }

    private mutating func addContainer(_ markup: Markup, role: NootMarkdownRole) {
        guard let range = mapper.range(for: markup.range) else { return }
        let childRanges = markup.children.compactMap { mapper.range(for: $0.range) }
            .sorted { $0.location < $1.location }
        if let first = childRanges.first, let last = childRanges.last {
            presentation.spans.append(.init(
                range: NSRange(location: first.location,
                               length: NSMaxRange(last) - first.location),
                role: role
            ))
        }
        addContainerSyntax(markup, within: range)
    }

    private mutating func addLinkedContainer(_ markup: Markup, destination: String?) {
        guard let range = mapper.range(for: markup.range) else { return }
        let childRanges = markup.children.compactMap { mapper.range(for: $0.range) }
            .sorted { $0.location < $1.location }
        if let first = childRanges.first, let last = childRanges.last {
            let visible = NSRange(location: first.location,
                                  length: NSMaxRange(last) - first.location)
            presentation.spans.append(.init(range: visible,
                                            role: .link(destination.flatMap(linkURL))))
        }
        addContainerSyntax(markup, within: range)
    }

    private mutating func addContainerSyntax(_ markup: Markup, within range: NSRange) {
        let children = markup.children.compactMap { mapper.range(for: $0.range) }
            .filter { NSIntersectionRange($0, range).length > 0 }
            .sorted { $0.location < $1.location }
        var cursor = range.location
        for child in children {
            let start = max(range.location, child.location)
            if cursor < start {
                addSyntax(NSRange(location: cursor, length: start - cursor))
            }
            cursor = max(cursor, min(NSMaxRange(range), NSMaxRange(child)))
        }
        if cursor < NSMaxRange(range) {
            addSyntax(NSRange(location: cursor, length: NSMaxRange(range) - cursor))
        }
    }

    private mutating func addSyntax(_ range: NSRange, dimWhenRevealed: Bool = true) {
        guard range.location != NSNotFound, range.length > 0 else { return }
        var start: Int?
        for offset in range.location ..< NSMaxRange(range) {
            let isNewline = CharacterSet.newlines.contains(UnicodeScalar(ns.character(at: offset))!)
            if isNewline {
                if let start {
                    let chunk = NSRange(location: start, length: offset - start)
                    presentation.syntaxRanges.append(chunk)
                    if dimWhenRevealed { presentation.dimmedSyntaxRanges.append(chunk) }
                }
                start = nil
            } else if start == nil {
                start = offset
            }
        }
        if let start {
            let chunk = NSRange(location: start, length: NSMaxRange(range) - start)
            presentation.syntaxRanges.append(chunk)
            if dimWhenRevealed { presentation.dimmedSyntaxRanges.append(chunk) }
        }
    }

    private func firstMatch(_ pattern: String, in text: String) -> NSRange? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text,
                                           range: NSRange(location: 0,
                                                          length: (text as NSString).length))
        else { return nil }
        return match.range
    }
}

// MARK: - TextKit stack

final class NootMarkdownTextStorage: NSTextStorage {
    private let backingStore = NSMutableAttributedString()
    private(set) var presentation = NootMarkdownPresentation()
    private(set) var fontSize: CGFloat = 0

    override var string: String { backingStore.string }

    override func attributes(at location: Int,
                             effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range,
               changeInLength: (str as NSString).length - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    func refreshPresentation(fontSize: CGFloat) {
        let source = string
        let full = NSRange(location: 0, length: (source as NSString).length)
        var walker = NootMarkdownWalker(source: source)
        walker.visit(Document(parsing: source))
        presentation = walker.presentation
        preserveStandaloneNootDividers(in: source, fullRange: full)
        self.fontSize = fontSize

        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.labelColor,
        ]
        beginEditing()
        backingStore.setAttributes(base, range: full)
        applySemanticAttributes(fontSize: fontSize)
        for range in presentation.dimmedSyntaxRanges where valid(range) {
            backingStore.addAttribute(.foregroundColor,
                                      value: NSColor.tertiaryLabelColor,
                                      range: range)
        }
        applyTagsAndBareLinks(in: source)
        edited(.editedAttributes, range: full, changeInLength: 0)
        endEditing()
    }

    var baseTypingAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.labelColor,
        ]
    }

    private func applySemanticAttributes(fontSize: CGFloat) {
        let spans = presentation.spans
        for span in spans {
            guard valid(span.range) else { continue }
            if case let .heading(level) = span.role {
                let headingSize: CGFloat = level == 1 ? fontSize + 11 : level == 2 ? fontSize + 6 : fontSize + 2
                let weight: NSFont.Weight = level == 3 ? .semibold : .bold
                backingStore.addAttribute(.font,
                                          value: NSFont.systemFont(ofSize: headingSize, weight: weight),
                                          range: span.range)
            }
        }
        for span in spans where valid(span.range) {
            switch span.role {
            case .strong:
                addFontTrait(.boldFontMask, to: span.range)
            case .emphasis:
                addFontTrait(.italicFontMask, to: span.range)
            case .strikethrough:
                backingStore.addAttribute(.strikethroughStyle,
                                          value: NSUnderlineStyle.single.rawValue,
                                          range: span.range)
            case .blockQuote:
                backingStore.addAttribute(.foregroundColor,
                                          value: NSColor.secondaryLabelColor,
                                          range: span.range)
            case let .link(url):
                backingStore.addAttributes([
                    .foregroundColor: accentNS,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ], range: span.range)
                if let url { backingStore.addAttribute(.link, value: url, range: span.range) }
            case .listMarker:
                backingStore.addAttribute(.foregroundColor, value: accentNS, range: span.range)
            case let .checkbox(_, location):
                backingStore.addAttributes([
                    .foregroundColor: accentNS,
                    .link: URL(string: "fncheck://\(location)")!,
                ], range: span.range)
            case .checkedContent:
                backingStore.addAttributes([
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                ], range: span.range)
            case .inlineCode:
                backingStore.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: fontSize - 1.5, weight: .regular),
                    .foregroundColor: accentNS,
                    .backgroundColor: NSColor.labelColor.withAlphaComponent(0.06),
                ], range: span.range)
            case .codeBlock:
                backingStore.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: fontSize - 1.5, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .backgroundColor: NSColor.labelColor.withAlphaComponent(0.06),
                ], range: span.range)
            case .heading:
                break
            }
        }
    }

    // Noot has always treated an exact standalone `---` as a divider, even
    // where CommonMark would interpret it as a setext heading underline.
    // Preserve that product behavior while using the AST for everything else.
    private func preserveStandaloneNootDividers(in source: String, fullRange: NSRange) {
        guard let regex = try? NSRegularExpression(pattern: "^[ \\t]*---[ \\t]*$",
                                                   options: [.anchorsMatchLines]) else { return }
        var ranges: [NSRange] = []
        regex.enumerateMatches(in: source, range: fullRange) { match, _, _ in
            if let match { ranges.append(match.range) }
        }
        guard !ranges.isEmpty else { return }
        presentation.spans.removeAll { span in
            guard case .heading = span.role else { return false }
            return ranges.contains { NSIntersectionRange($0, span.range).length > 0 }
        }
        presentation.syntaxRanges.removeAll { syntax in
            ranges.contains { NSIntersectionRange($0, syntax).length > 0 }
        }
        presentation.dimmedSyntaxRanges.removeAll { syntax in
            ranges.contains { NSIntersectionRange($0, syntax).length > 0 }
        }
        for range in ranges {
            if !presentation.dividerRanges.contains(where: { $0 == range }) {
                presentation.dividerRanges.append(range)
            }
        }
    }

    private func addFontTrait(_ trait: NSFontTraitMask, to range: NSRange) {
        var segments: [(NSRange, NSFont)] = []
        backingStore.enumerateAttribute(.font, in: range) { value, subrange, _ in
            if let font = value as? NSFont { segments.append((subrange, font)) }
        }
        for (subrange, font) in segments {
            backingStore.addAttribute(.font,
                                      value: NSFontManager.shared.convert(font, toHaveTrait: trait),
                                      range: subrange)
        }
    }

    // Tags and plain URLs are application affordances rather than Markdown AST
    // nodes, so these deliberately remain small, isolated regex passes.
    private func applyTagsAndBareLinks(in source: String) {
        let full = NSRange(location: 0, length: (source as NSString).length)
        let ns = source as NSString
        enumerate("(?<![\\w#])#[\\p{L}\\d_][\\p{L}\\d_\\-]*", in: source, range: full) { range in
            var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: accentNS]
            let tag = String(ns.substring(with: range).dropFirst())
            if let encoded = tag.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
               let url = URL(string: "noottag://\(encoded)") {
                attrs[.link] = url
            }
            backingStore.addAttributes(attrs, range: range)
        }
        enumerate("(?<![(\\]])https?://[^\\s)]+", in: source, range: full) { range in
            guard backingStore.attribute(.link, at: range.location, effectiveRange: nil) == nil,
                  let url = URL(string: ns.substring(with: range))
            else { return }
            backingStore.addAttributes([
                .foregroundColor: accentNS,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: url,
            ], range: range)
        }
    }

    private func enumerate(_ pattern: String, in source: String, range: NSRange,
                           body: (NSRange) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: [.anchorsMatchLines]) else { return }
        regex.enumerateMatches(in: source, range: range) { match, _, _ in
            if let match { body(match.range) }
        }
    }

    private func valid(_ range: NSRange) -> Bool {
        range.location != NSNotFound && range.location >= 0 && NSMaxRange(range) <= backingStore.length
    }
}

final class NootMarkdownLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    private var hiddenIndexes = IndexSet()
    private(set) var dividerRanges: [NSRange] = []
    private let minimumDividerBlockHeight: CGFloat = 30

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    func updatePresentation(_ presentation: NootMarkdownPresentation,
                            revealing revealRange: NSRange,
                            selection: NSRange,
                            textLength: Int) {
        let old = hiddenIndexes
        var next = IndexSet()
        for range in presentation.syntaxRanges
            where range.location != NSNotFound
                && NSIntersectionRange(range, revealRange).length == 0 {
            next.insert(integersIn: range.location ..< NSMaxRange(range))
        }
        let ns = textStorage?.string as NSString?
        let visibleDividers = presentation.dividerRanges.filter { divider in
            let end = NSMaxRange(divider)
            guard let ns, end < ns.length,
                  CharacterSet.newlines.contains(UnicodeScalar(ns.character(at: end))!)
            else { return false }
            guard selection.length == 0 else { return true }
            return selection.location < divider.location || selection.location > end
        }
        for range in visibleDividers where range.location != NSNotFound {
            next.insert(integersIn: range.location ..< NSMaxRange(range))
        }
        hiddenIndexes = next
        dividerRanges = visibleDividers

        for chunk in old.symmetricDifference(next).rangeView {
            guard chunk.lowerBound < textLength else { continue }
            let range = NSRange(location: chunk.lowerBound,
                                length: min(chunk.count, textLength - chunk.lowerBound))
            invalidateGlyphs(forCharacterRange: range,
                             changeInLength: 0,
                             actualCharacterRange: nil)
            invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        }
        invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textLength))
    }

    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
                       lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
                       baselineOffset: UnsafeMutablePointer<CGFloat>,
                       in textContainer: NSTextContainer,
                       forGlyphRange glyphRange: NSRange) -> Bool {
        guard dividerRange(intersectingGlyphRange: glyphRange) != nil else { return false }
        let originalHeight = lineFragmentRect.pointee.height
        let fontHeight: CGFloat
        if let textStorage,
           glyphRange.location < numberOfGlyphs {
            let character = characterIndexForGlyph(at: glyphRange.location)
            let font = textStorage.attribute(.font,
                                             at: min(character, max(textStorage.length - 1, 0)),
                                             effectiveRange: nil) as? NSFont
            fontHeight = font.map(defaultLineHeight(for:)) ?? originalHeight
        } else {
            fontHeight = originalHeight
        }
        let blockHeight = max(minimumDividerBlockHeight, fontHeight + 12)
        lineFragmentRect.pointee.size.height = blockHeight
        lineFragmentUsedRect.pointee = NSRect(x: lineFragmentRect.pointee.minX,
                                              y: lineFragmentRect.pointee.minY,
                                              width: lineFragmentRect.pointee.width,
                                              height: blockHeight)
        baselineOffset.pointee += (blockHeight - originalHeight) / 2
        return true
    }

    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes: UnsafePointer<Int>,
                       font: NSFont,
                       forGlyphRange glyphRange: NSRange) -> Int {
        guard !hiddenIndexes.isEmpty else { return 0 }
        var updated = Array(UnsafeBufferPointer(start: properties, count: glyphRange.length))
        var changed = false
        for index in 0 ..< glyphRange.length where hiddenIndexes.contains(characterIndexes[index]) {
            updated[index] = .null
            changed = true
        }
        guard changed else { return 0 }
        setGlyphs(glyphs,
                  properties: updated,
                  characterIndexes: characterIndexes,
                  font: font,
                  forGlyphRange: glyphRange)
        return glyphRange.length
    }

    func divider(at point: NSPoint) -> NSRange? {
        dividerRanges.first { range in
            guard let rect = blockRect(for: range) else { return false }
            return rect.contains(point)
        }
    }

    func blockRect(for divider: NSRange) -> NSRect? {
        guard divider.location != NSNotFound,
              NSMaxRange(divider) < textStorage?.length ?? 0 else { return nil }
        let glyph = glyphIndexForCharacter(at: NSMaxRange(divider))
        guard glyph < numberOfGlyphs else { return nil }
        return lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
    }

    private func dividerRange(intersectingGlyphRange glyphRange: NSRange) -> NSRange? {
        guard glyphRange.location < numberOfGlyphs else { return nil }
        let characterRange = self.characterRange(forGlyphRange: glyphRange,
                                                 actualGlyphRange: nil)
        return dividerRanges.first {
            NSLocationInRange(NSMaxRange($0), characterRange)
        }
    }

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let textStorage, !dividerRanges.isEmpty,
              let textContainer = textContainers.first else { return }
        let scale = textContainer.textView?.window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        NSColor.separatorColor.withAlphaComponent(0.7).setStroke()
        for range in dividerRanges where range.location < textStorage.length {
            let anchorGlyph = glyphIndexForCharacter(at: NSMaxRange(range))
            guard NSLocationInRange(anchorGlyph, glyphsToShow),
                  let block = blockRect(for: range) else { continue }
            let fragment = block.offsetBy(dx: origin.x, dy: origin.y)
            let y = (fragment.midY * scale).rounded() / scale
            let line = NSBezierPath()
            line.lineWidth = 1 / scale
            line.move(to: NSPoint(x: origin.x, y: y))
            line.line(to: NSPoint(x: origin.x + textContainer.containerSize.width, y: y))
            line.stroke()
        }
    }
}

final class NootMarkdownTextContainer: NSTextContainer {}
