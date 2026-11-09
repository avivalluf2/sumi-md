import Foundation
import Testing
@testable import SumiMD

/// Text covered by spans of one style, in order.
private func texts(_ style: MarkdownStyle, in source: String) -> [String] {
    let ns = source as NSString
    return MarkdownParse(source).allSpans()
        .filter { $0.style == style }
        .sorted { $0.range.location < $1.range.location }
        .map { ns.substring(with: $0.range) }
}

struct SourceMapTests {
    @Test func asciiOffsets() {
        let map = MarkdownSourceMap("ab\ncd")
        #expect(map.offset(line: 1, column: 1) == 0)
        #expect(map.offset(line: 2, column: 2) == 4)
        #expect(map.utf16Length == 5)
    }

    @Test func multibyteOffsets() {
        // "é" is 2 UTF-8 bytes / 1 UTF-16 unit; "😀" is 4 bytes / 2 units; Hebrew letters 2 bytes / 1 unit.
        let text = "é😀x\nשלום **b**"
        let map = MarkdownSourceMap(text)
        #expect(map.offset(line: 1, column: 1 + 2 + 4) == 3)   // "x"
        #expect(map.offset(line: 2, column: 1 + 8 + 1) == 10)  // first "*" after "שלום "
        #expect(map.utf16Length == (text as NSString).length)
    }
}

struct StylerTests {
    @Test func atxHeading() {
        let source = "## Title"
        #expect(texts(.heading(level: 2), in: source) == ["## Title"])
        #expect(texts(.syntax, in: source) == ["## "])
    }

    @Test func setextHeading() {
        let source = "Title\n====="
        #expect(texts(.heading(level: 1), in: source) == ["Title\n====="])
        #expect(texts(.syntax, in: source) == ["====="])
    }

    @Test func inlineMarkers() {
        let source = "a **bold** _it_ ~~gone~~ `code`"
        #expect(texts(.strong, in: source) == ["**bold**"])
        #expect(texts(.emphasis, in: source) == ["_it_"])
        #expect(texts(.strikethrough, in: source) == ["~~gone~~"])
        #expect(texts(.inlineCode, in: source) == ["`code`"])
        #expect(texts(.syntax, in: source) == ["**", "**", "_", "_", "~~", "~~", "`", "`"])
    }

    @Test func markersAfterEmojiAndHebrew() {
        let source = "😀 שלום **b**"
        #expect(texts(.strong, in: source) == ["**b**"])
        #expect(texts(.syntax, in: source) == ["**", "**"])
    }

    @Test func link() {
        let source = "see [site](https://example.com) now"
        #expect(texts(.link, in: source) == ["site"])
        #expect(texts(.syntax, in: source) == ["[", "](https://example.com)"])
    }

    @Test func fencedCodeBlock() {
        let source = "```swift\nlet x = 1\n```\n\nafter"
        #expect(texts(.codeBlock, in: source).first?.contains("let x = 1") == true)
        #expect(texts(.syntax, in: source) == ["```swift", "```"])
    }

    @Test func unclosedFenceRunsToEnd() {
        let source = "```\ncode\nmore"
        #expect(texts(.syntax, in: source) == ["```"])
        #expect(texts(.codeBlock, in: source).first?.hasSuffix("more") == true)
    }

    @Test func listsAndTasks() {
        let source = "- one\n- [ ] task\n1. num"
        #expect(texts(.syntax, in: source) == ["- ", "- [ ] ", "1. "])
    }

    @Test func blockQuote() {
        let source = "> quoted\n> more"
        #expect(texts(.blockQuote, in: source) == ["> quoted\n> more"])
        #expect(texts(.syntax, in: source) == [">", ">"])
    }

    @Test func plainTextHasNoSpans() {
        #expect(MarkdownParse("just words").allSpans().isEmpty)
    }
}

struct HighlighterTests {
    /// Applies an edit and returns the dirty text.
    private func dirtyText(from old: String, to new: String, editedRange: NSRange) -> String {
        var highlighter = MarkdownHighlighter()
        _ = highlighter.restyleAll(old)
        let change = (new as NSString).length - (old as NSString).length
        let update = highlighter.update(new, editedRange: editedRange, changeInLength: change)
        return (new as NSString).substring(with: update.dirtyRange)
    }

    @Test func typingInParagraphOnlyTouchesThatParagraph() {
        let old = "first\n\nsecond\n\nthird"
        let new = "first\n\nsecondX\n\nthird"
        let dirty = dirtyText(from: old, to: new, editedRange: NSRange(location: 13, length: 1))
        #expect(dirty.contains("secondX"))
        #expect(!dirty.contains("first"))
        #expect(!dirty.contains("third"))
    }

    @Test func openingFenceRestylesToEnd() {
        let old = "a\n\nb\n\nc"
        let new = "```\na\n\nb\n\nc"
        let dirty = dirtyText(from: old, to: new, editedRange: NSRange(location: 0, length: 4))
        #expect(dirty == new)
    }

    @Test func closingFenceRestylesFollowingBlocks() {
        let old = "```\ncode\n\nafter\n\nend"
        let new = "```\ncode\n```\n\nafter\n\nend"
        let dirty = dirtyText(from: old, to: new, editedRange: NSRange(location: 9, length: 4))
        #expect(dirty.hasSuffix("end"))
    }

    @Test func setextUnderlineRestylesParagraphAbove() {
        let old = "Title\n\nnext"
        let new = "Title\n===\n\nnext"
        let dirty = dirtyText(from: old, to: new, editedRange: NSRange(location: 6, length: 4))
        #expect(dirty.hasPrefix("Title"))
        #expect(!dirty.contains("next"))
    }

    @Test func spansAreClippedToDirtyRange() {
        var highlighter = MarkdownHighlighter()
        _ = highlighter.restyleAll("# A\n\n**b**")
        let update = highlighter.update("# A\n\n**bc**", editedRange: NSRange(location: 8, length: 1), changeInLength: 1)
        for span in update.spans {
            #expect(NSIntersectionRange(span.range, update.dirtyRange) == span.range)
        }
        #expect(!update.spans.contains { $0.style == .heading(level: 1) })
    }

    @Test func largeDocumentUpdateIsFast() {
        let block = "## Heading\n\nSome **bold** text with `code` and a [link](https://x.y).\n\n- item\n- item\n\n"
        let text = String(repeating: block, count: 5_000) // ~400 KB
        var highlighter = MarkdownHighlighter()
        _ = highlighter.restyleAll(text)
        let edited = text.replacingOccurrences(of: "Some", with: "Sone", options: [], range: text.range(of: "Some"))
        let clock = ContinuousClock()
        var update: MarkdownHighlighter.Update?
        let elapsed = clock.measure {
            update = highlighter.update(edited, editedRange: NSRange(location: 14, length: 1), changeInLength: 0)
        }
        print("update on \((text as NSString).length) chars took \(elapsed)")
        #expect((update?.dirtyRange.length ?? .max) < 200)
        #expect(elapsed < .milliseconds(500))
    }
}
