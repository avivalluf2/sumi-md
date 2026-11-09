import AppKit

/// Turns `MarkdownStyle` spans into text attributes. Only attributes change; the string never does.
/// Colors are system colors, so light and dark mode follow automatically.
struct MarkdownTheme {
    var fontSize: CGFloat = 14

    var bodyFont: NSFont { .systemFont(ofSize: fontSize) }
    var codeFont: NSFont { .monospacedSystemFont(ofSize: fontSize * 0.95, weight: .regular) }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: NSColor.textColor]
    }

    /// Resets `range` to the body style, then applies `spans` (already clipped to `range`).
    func apply(_ spans: [StyledSpan], in range: NSRange, to storage: NSTextStorage) {
        guard range.length > 0 else { return }
        storage.setAttributes(baseAttributes, range: range)

        // Order matters: block fonts first, then traits layered on top, then colors.
        for span in spans.sorted(by: { Self.order($0.style) < Self.order($1.style) }) {
            apply(span, to: storage)
        }
    }

    private func apply(_ span: StyledSpan, to storage: NSTextStorage) {
        let range = span.range
        switch span.style {
        case .heading(let level):
            let scale: CGFloat = switch level {
            case 1: 1.6
            case 2: 1.4
            case 3: 1.2
            default: 1.0
            }
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize * scale, weight: .bold), range: range)
        case .codeBlock:
            storage.addAttribute(.font, value: codeFont, range: range)
            storage.addAttribute(.backgroundColor, value: NSColor.quaternarySystemFill, range: range)
        case .inlineCode:
            storage.addAttribute(.font, value: codeFont, range: range)
            storage.addAttribute(.backgroundColor, value: NSColor.quaternarySystemFill, range: range)
        case .strong:
            addTraits(.bold, in: range, of: storage)
        case .emphasis:
            addTraits(.italic, in: range, of: storage)
        case .strikethrough:
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .blockQuote:
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
        case .link:
            // Colored only: not clickable while editing.
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
        case .syntax:
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
        }
    }

    /// Adds bold/italic to whatever font is already there (so bold works inside headings too).
    private func addTraits(_ traits: NSFontDescriptor.SymbolicTraits, in range: NSRange, of storage: NSTextStorage) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = (value as? NSFont) ?? bodyFont
            let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits))
            let converted = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
            storage.addAttribute(.font, value: converted, range: subrange)
        }
    }

    private static func order(_ style: MarkdownStyle) -> Int {
        switch style {
        case .heading, .codeBlock, .inlineCode: 0
        case .strong, .emphasis: 1
        case .strikethrough, .blockQuote, .link: 2
        case .syntax: 3
        }
    }
}
