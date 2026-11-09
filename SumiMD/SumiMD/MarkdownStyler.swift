import Foundation
import Markdown

/// What a range of Markdown source should look like. Purely semantic; `MarkdownTheme`
/// turns these into fonts and colors.
nonisolated enum MarkdownStyle: Hashable, Sendable {
    case heading(level: Int)
    case strong
    case emphasis
    case strikethrough
    case inlineCode
    case codeBlock
    case link
    case blockQuote
    /// Markup characters such as `#`, `**`, backticks, list bullets and link brackets.
    case syntax
}

nonisolated struct StyledSpan: Hashable, Sendable {
    var range: NSRange
    var style: MarkdownStyle
}

/// A parsed document: its top-level blocks (as UTF-16 ranges) and a way to get styles.
nonisolated struct MarkdownParse {
    let text: NSString
    let map: MarkdownSourceMap
    let document: Document
    /// UTF-16 range of each top-level block, in document order.
    let blockRanges: [NSRange]

    init(_ string: String) {
        text = string as NSString
        map = MarkdownSourceMap(string)
        document = Document(parsing: string)
        var ranges: [NSRange] = []
        for child in document.children {
            if let range = child.range { ranges.append(map.nsRange(range)) }
        }
        blockRanges = ranges
    }

    /// Style spans for every top-level block that touches `range`, clipped to `range`.
    func spans(in range: NSRange) -> [StyledSpan] {
        var styler = MarkdownStyler(text: text, map: map)
        for child in document.children {
            guard let source = child.range else { continue }
            let block = map.nsRange(source)
            if block.location > NSMaxRange(range) { break }
            if NSMaxRange(block) < range.location { continue }
            styler.visit(child)
        }
        return styler.spans.compactMap { span in
            let clipped = NSIntersectionRange(span.range, range)
            return clipped.length > 0 ? StyledSpan(range: clipped, style: span.style) : nil
        }
    }

    /// Style spans for the whole document.
    func allSpans() -> [StyledSpan] {
        spans(in: NSRange(location: 0, length: text.length))
    }
}

/// Walks the syntax tree and records style spans. Marker ranges are derived from the gap
/// between a node's range and its children's ranges, so no text is ever rewritten.
nonisolated struct MarkdownStyler {
    let text: NSString
    let map: MarkdownSourceMap
    private(set) var spans: [StyledSpan] = []

    init(text: NSString, map: MarkdownSourceMap) {
        self.text = text
        self.map = map
    }

    mutating func visit(_ markup: Markup) {
        guard let source = markup.range else {
            visitChildren(markup)
            return
        }
        let range = map.nsRange(source)

        switch markup {
        case let heading as Heading:
            add(range, .heading(level: heading.level))
            if character(at: range.location) == "#" {
                addOuterMarkers(of: markup, in: range)
            } else {
                // Setext heading: the underline (=== or ---) is the marker.
                add(map.lineRange(source.upperBound.line), .syntax)
            }
        case is Strong:
            add(range, .strong)
            addOuterMarkers(of: markup, in: range)
        case is Emphasis:
            add(range, .emphasis)
            addOuterMarkers(of: markup, in: range)
        case is Strikethrough:
            add(range, .strikethrough)
            addOuterMarkers(of: markup, in: range)
        case is InlineCode:
            add(range, .inlineCode)
            addBacktickMarkers(in: range)
        case is CodeBlock:
            add(range, .codeBlock)
            addFenceMarkers(from: source)
        case is Link, is Image:
            let inner = childrenRange(of: markup)
            if let inner {
                add(inner, .link)
            }
            addOuterMarkers(of: markup, in: range)
        case is BlockQuote:
            add(range, .blockQuote)
            addQuoteMarkers(from: source)
        case is ListItem:
            addLeadingMarker(of: markup, in: range)
        case is ThematicBreak, is HTMLBlock, is InlineHTML:
            add(range, .syntax)
        default:
            break
        }
        visitChildren(markup)
    }

    private mutating func visitChildren(_ markup: Markup) {
        for child in markup.children { visit(child) }
    }

    // MARK: - Markers

    private func childrenRange(of markup: Markup) -> NSRange? {
        var lower: Int?
        var upper: Int?
        for child in markup.children {
            guard let source = child.range else { continue }
            let range = map.nsRange(source)
            lower = min(lower ?? range.location, range.location)
            upper = max(upper ?? NSMaxRange(range), NSMaxRange(range))
        }
        guard let lower, let upper else { return nil }
        return NSRange(location: lower, length: upper - lower)
    }

    /// Marks text before the first child and after the last child (e.g. `**`, `# `, `](url)`).
    private mutating func addOuterMarkers(of markup: Markup, in range: NSRange) {
        guard let inner = childrenRange(of: markup) else {
            add(range, .syntax)
            return
        }
        add(NSRange(location: range.location, length: inner.location - range.location), .syntax)
        add(NSRange(location: NSMaxRange(inner), length: NSMaxRange(range) - NSMaxRange(inner)), .syntax)
    }

    /// Marks text before the first child only (list bullets, numbers and task checkboxes).
    private mutating func addLeadingMarker(of markup: Markup, in range: NSRange) {
        guard let inner = childrenRange(of: markup) else { return }
        // Only the marker on the item's first line, not indentation of later lines.
        let firstLineEnd = text.lineRange(for: NSRange(location: range.location, length: 0))
        let end = min(inner.location, NSMaxRange(firstLineEnd))
        add(NSRange(location: range.location, length: end - range.location), .syntax)
    }

    private mutating func addBacktickMarkers(in range: NSRange) {
        var leading = 0
        while leading < range.length, character(at: range.location + leading) == "`" { leading += 1 }
        var trailing = 0
        while trailing < range.length - leading, character(at: NSMaxRange(range) - 1 - trailing) == "`" { trailing += 1 }
        add(NSRange(location: range.location, length: leading), .syntax)
        add(NSRange(location: NSMaxRange(range) - trailing, length: trailing), .syntax)
    }

    /// Marks the opening and closing fence lines of a fenced code block.
    private mutating func addFenceMarkers(from source: SourceRange) {
        let first = map.lineRange(source.lowerBound.line)
        guard isFence(first) else { return }
        add(first, .syntax)
        let lastLine = lastContentLine(of: source)
        if lastLine > source.lowerBound.line {
            let last = map.lineRange(lastLine)
            if isFence(last) { add(last, .syntax) }
        }
    }

    private mutating func addQuoteMarkers(from source: SourceRange) {
        for line in source.lowerBound.line...lastContentLine(of: source) {
            let lineRange = map.lineRange(line)
            var i = lineRange.location
            var markerEnd = i
            while i < NSMaxRange(lineRange) {
                let c = character(at: i)
                if c == ">" { markerEnd = i + 1 } else if c != " " && c != "\t" { break }
                i += 1
            }
            add(NSRange(location: lineRange.location, length: markerEnd - lineRange.location), .syntax)
        }
    }

    // MARK: - Helpers

    /// The last line holding content. A range ending at column 1 stops before that line.
    private func lastContentLine(of source: SourceRange) -> Int {
        let end = source.upperBound
        return end.column <= 1 && end.line > source.lowerBound.line ? end.line - 1 : end.line
    }

    private func isFence(_ line: NSRange) -> Bool {
        let content = text.substring(with: line).trimmingCharacters(in: .whitespaces)
        return content.hasPrefix("```") || content.hasPrefix("~~~")
    }

    private func character(at index: Int) -> Character? {
        guard index >= 0, index < text.length else { return nil }
        guard let scalar = Unicode.Scalar(text.character(at: index)) else { return nil }
        return Character(scalar)
    }

    private mutating func add(_ range: NSRange, _ style: MarkdownStyle) {
        guard range.length > 0 else { return }
        spans.append(StyledSpan(range: range, style: style))
    }
}
