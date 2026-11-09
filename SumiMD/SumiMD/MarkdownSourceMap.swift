import Foundation
import Markdown

/// Converts swift-markdown source locations (1-based line, 1-based UTF-8 byte column)
/// into UTF-16 offsets, which is what `NSString`, `NSRange` and `NSTextStorage` use.
nonisolated struct MarkdownSourceMap {
    private let bytes: ContiguousArray<UInt8>
    /// UTF-8 offset where each line starts.
    private var utf8LineStarts: [Int] = [0]
    /// UTF-16 offset where each line starts.
    private var utf16LineStarts: [Int] = [0]
    /// Lines that are pure ASCII, where a byte column equals a UTF-16 column.
    private var asciiLines: [Bool] = []
    /// Total UTF-16 length of the text.
    let utf16Length: Int

    init(_ text: String) {
        bytes = ContiguousArray(text.utf8)
        var utf16 = 0
        var lineIsASCII = true
        for (offset, byte) in bytes.enumerated() {
            utf16 += Self.utf16Units(forLeadByte: byte)
            if byte >= 0x80 { lineIsASCII = false }
            if byte == 0x0A {
                asciiLines.append(lineIsASCII)
                lineIsASCII = true
                utf8LineStarts.append(offset + 1)
                utf16LineStarts.append(utf16)
            }
        }
        asciiLines.append(lineIsASCII)
        utf16Length = utf16
    }

    /// UTF-16 code units contributed by a UTF-8 byte (counted on the lead byte only).
    private static func utf16Units(forLeadByte byte: UInt8) -> Int {
        switch byte {
        case 0x00..<0x80: 1        // ASCII
        case 0x80..<0xC0: 0        // continuation byte
        case 0xC0..<0xF0: 1        // 2- and 3-byte sequences: one UTF-16 unit
        default: 2                 // 4-byte sequence: surrogate pair
        }
    }

    var lineCount: Int { utf8LineStarts.count }

    /// UTF-16 offset of a 1-based line and 1-based UTF-8 column, clamped to the text.
    func offset(line: Int, column: Int) -> Int {
        let index = min(max(line - 1, 0), lineCount - 1)
        let lineStart16 = utf16LineStarts[index]
        let byteColumn = max(column - 1, 0)
        if asciiLines[index] {
            return min(lineStart16 + byteColumn, utf16Length)
        }
        let start = utf8LineStarts[index]
        let end = min(start + byteColumn, bytes.count)
        var utf16 = lineStart16
        var i = start
        while i < end {
            utf16 += Self.utf16Units(forLeadByte: bytes[i])
            i += 1
        }
        return min(utf16, utf16Length)
    }

    func offset(_ location: SourceLocation) -> Int {
        offset(line: location.line, column: location.column)
    }

    func nsRange(_ range: SourceRange) -> NSRange {
        let start = offset(range.lowerBound)
        let end = max(offset(range.upperBound), start)
        return NSRange(location: start, length: end - start)
    }

    /// UTF-16 range of a whole 1-based line, without its trailing newline.
    func lineRange(_ line: Int) -> NSRange {
        let index = min(max(line - 1, 0), lineCount - 1)
        let start = utf16LineStarts[index]
        let end = index + 1 < lineCount ? utf16LineStarts[index + 1] - 1 : utf16Length
        return NSRange(location: start, length: max(end - start, 0))
    }
}
