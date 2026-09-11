import AppKit

// Code-mode gutter: one number per logical line (a wrapped line keeps one number).
final class LineNumberRuler: NSRulerView {
    init(textView: NSTextView, scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 36
    }

    required init(coder: NSCoder) { fatalError() }

    // Size the gutter to the digit count; called whenever the text changes.
    func refresh() {
        guard let textView = clientView as? NSTextView else { return }
        let lines = max(1, textView.string.reduce(1) { $1 == "\n" ? $0 + 1 : $0 })
        ruleThickness = max(36, 16 + 8 * CGFloat(String(lines).count))
        needsDisplay = true
    }

    // No super.draw: the ruler's default opaque background would cover the frosted panel.
    override func draw(_ dirtyRect: NSRect) { drawHashMarksAndLabels(in: dirtyRect) }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }
        let ns = textView.string as NSString
        let inset = textView.textContainerInset
        let font = (textView.font ?? NSFont.systemFont(ofSize: 13)).pointSize
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: max(9, font - 3), weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        var visible = textView.visibleRect
        visible.origin.y -= inset.height
        let glyphs = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let chars = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)

        func draw(_ number: Int, at fragment: NSRect) {
            let label = String(number) as NSString
            let size = label.size(withAttributes: attributes)
            let y = convert(NSPoint(x: 0, y: fragment.minY + inset.height), from: textView).y
            label.draw(at: NSPoint(x: ruleThickness - size.width - 6,
                                   y: y + (fragment.height - size.height) / 2),
                       withAttributes: attributes)
        }

        // ponytail: counts newlines from the top on every draw; notes are small.
        var number = 1
        var index = 0
        while index < chars.location {
            let line = ns.lineRange(for: NSRange(location: index, length: 0))
            index = NSMaxRange(line)
            number += 1
        }
        index = chars.location
        while index < NSMaxRange(chars) {
            let line = ns.lineRange(for: NSRange(location: index, length: 0))
            let glyph = layoutManager.glyphIndexForCharacter(at: line.location)
            draw(number, at: layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil))
            number += 1
            index = NSMaxRange(line)
            if line.length == 0 { break }
        }
        // the empty last line after a trailing newline, or an empty note
        if index == ns.length, ns.length == 0 || ns.character(at: ns.length - 1) == 10 {
            draw(number, at: layoutManager.extraLineFragmentRect)
        }
    }
}
