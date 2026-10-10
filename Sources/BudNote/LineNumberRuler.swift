import AppKit

final class LineNumberRuler: NSRulerView {
    override var isFlipped: Bool { true }
    weak var textView: NSTextView?
    var lineStarts: [Int] = [0]
    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView; ruleThickness = 30
    }
    required init(coder: NSCoder) { fatalError() }
    private var labelAttributes: [NSAttributedString.Key: Any] {
        let size = max(10, (textView?.font?.pointSize ?? CGFloat(Preferences.shared.fontSize)) - 3)
        return [.font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]
    }
    func updateLines() {
        guard let textView else { return }
        let string = textView.string as NSString
        lineStarts = [0]
        var pos = 0
        while pos < string.length {
            let range = string.lineRange(for: NSRange(location: pos, length: 0))
            pos = NSMaxRange(range)
            if pos <= string.length { lineStarts.append(pos) }
        }
        if let last = lineStarts.last, last == string.length, string.length > 0 {
            let final = string.character(at: string.length - 1)
            if final != 10 && final != 13 { lineStarts.removeLast() }
        }
        // Measure with the same font used for drawing. Fixed per-digit widths
        // clip the left side once Command-wheel zoom makes the labels larger.
        let width = (String(lineStarts.count) as NSString).size(withAttributes: labelAttributes).width
        ruleThickness = max(28, ceil(width) + 14); needsDisplay = true
    }
    override func drawHashMarksAndLabels(in rect: NSRect) {
        Palette.background.setFill(); rect.fill()
        guard let text = textView, let manager = text.layoutManager, let container = text.textContainer,
              let scrollView else { return }
        let visible = text.visibleRect
        let glyphs = manager.glyphRange(forBoundingRect: visible.offsetBy(dx: -text.textContainerOrigin.x, dy: -text.textContainerOrigin.y), in: container)
        let chars = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let attrs = labelAttributes
        // Binary search keeps scrolling independent of the total number of lines.
        var low = 0, high = lineStarts.count
        while low < high { let mid = (low + high) / 2; if lineStarts[mid] < chars.location { low = mid + 1 } else { high = mid } }
        var index = max(0, low - 1)
        while index < lineStarts.count && lineStarts[index] <= NSMaxRange(chars) {
            let start = lineStarts[index]
            let fragment: NSRect
            if start < (text.string as NSString).length {
                let glyph = manager.glyphIndexForCharacter(at: start)
                fragment = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            } else { fragment = manager.extraLineFragmentRect }
            let y = fragment.minY + text.textContainerOrigin.y - scrollView.contentView.bounds.minY
            let label = "\(index + 1)" as NSString
            let size = label.size(withAttributes: attrs)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 7, y: y + max(0, (fragment.height - size.height) / 2)), withAttributes: attrs)
            index += 1
        }
    }
}
