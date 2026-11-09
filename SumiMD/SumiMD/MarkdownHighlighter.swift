import Foundation

/// Decides which part of the text needs restyling after an edit and produces the spans for it.
///
/// The whole document is reparsed (cmark is fast), but styles are only re-applied to the
/// dirty region: the top-level blocks around the edit, extended forward until the block
/// layout matches the previous parse again. Typing inside a paragraph touches only that
/// paragraph; opening a code fence restyles everything below it.
nonisolated struct MarkdownHighlighter {
    private(set) var blockRanges: [NSRange] = []

    struct Update {
        /// Range (in the new text) whose attributes must be reset and re-applied.
        var dirtyRange: NSRange
        var spans: [StyledSpan]
    }

    /// Restyle everything, e.g. when a document is loaded.
    mutating func restyleAll(_ text: String) -> Update {
        let parse = MarkdownParse(text)
        blockRanges = parse.blockRanges
        let all = NSRange(location: 0, length: parse.text.length)
        return Update(dirtyRange: all, spans: parse.spans(in: all))
    }

    /// - Parameters:
    ///   - editedRange: the changed range in the new text (as reported by `NSTextStorage`).
    ///   - changeInLength: new length minus old length.
    mutating func update(_ text: String, editedRange: NSRange, changeInLength: Int) -> Update {
        let parse = MarkdownParse(text)
        let dirty = Self.dirtyRange(
            oldBlocks: blockRanges,
            newBlocks: parse.blockRanges,
            editedRange: editedRange,
            changeInLength: changeInLength,
            text: parse.text
        )
        blockRanges = parse.blockRanges
        return Update(dirtyRange: dirty, spans: parse.spans(in: dirty))
    }

    static func dirtyRange(
        oldBlocks: [NSRange],
        newBlocks: [NSRange],
        editedRange: NSRange,
        changeInLength: Int,
        text: NSString
    ) -> NSRange {
        let length = text.length
        let editStart = min(editedRange.location, length)
        let editEnd = min(NSMaxRange(editedRange), length)

        // Always cover the full lines that were edited.
        let editLines = text.lineRange(for: NSRange(location: editStart, length: editEnd - editStart))
        var start = editLines.location
        var end = NSMaxRange(editLines)

        // Extend back to the start of any block that reaches the edit.
        for block in newBlocks where NSMaxRange(block) >= editStart && block.location < start {
            start = block.location
            break
        }

        // Old blocks after the edit, moved to where they sit in the new text.
        let oldEditEnd = NSMaxRange(editedRange) - changeInLength
        let shiftedOld = Set(oldBlocks.lazy
            .filter { $0.location >= oldEditEnd }
            .map { NSRange(location: $0.location + changeInLength, length: $0.length) }
            .map(RangeKey.init))

        // Extend forward through every block until one is unchanged from before.
        var stable = false
        for block in newBlocks where NSMaxRange(block) >= editStart {
            if block.location >= editEnd, shiftedOld.contains(RangeKey(block)) {
                end = max(end, min(block.location, length))
                stable = true
                break
            }
            end = max(end, NSMaxRange(block))
        }
        if !stable { end = length }

        start = max(0, min(start, length))
        end = max(start, min(end, length))
        return NSRange(location: start, length: end - start)
    }

    private struct RangeKey: Hashable {
        let location: Int
        let length: Int
        init(_ range: NSRange) {
            location = range.location
            length = range.length
        }
    }
}
