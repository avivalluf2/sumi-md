import AppKit
import SwiftUI
import Testing
@testable import SumiMD

@MainActor
struct EditorStylingTests {
    private func makeStorage() -> (NSTextStorage, MarkdownTextView.Coordinator) {
        let coordinator = MarkdownTextView.Coordinator(MarkdownTextView(text: .constant("")))
        let storage = NSTextStorage()
        storage.delegate = coordinator
        return (storage, coordinator)
    }

    private func font(_ storage: NSTextStorage, at index: Int) -> NSFont? {
        storage.attribute(.font, at: index, effectiveRange: nil) as? NSFont
    }

    private func color(_ storage: NSTextStorage, at index: Int) -> NSColor? {
        storage.attribute(.foregroundColor, at: index, effectiveRange: nil) as? NSColor
    }

    @Test func stylesWhileTypingWithoutChangingText() {
        let (storage, _) = makeStorage()
        let typed = "# Title\n\nSome **bold** \"quotes\" -- and `code`"
        // Type one character at a time, like a user.
        for (i, ch) in typed.utf16.enumerated() {
            storage.replaceCharacters(in: NSRange(location: i, length: 0), with: String(utf16CodeUnits: [ch], count: 1))
        }
        #expect(storage.string == typed)

        let ns = typed as NSString
        let body = MarkdownTheme().fontSize
        #expect((font(storage, at: 2)?.pointSize ?? 0) > body)                     // heading text is larger
        #expect(color(storage, at: 0) == .tertiaryLabelColor)                      // "#" is dimmed
        let bold = ns.range(of: "bold").location
        #expect(font(storage, at: bold)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect(color(storage, at: bold - 1) == .tertiaryLabelColor)               // "**" dimmed
        let code = ns.range(of: "code").location
        #expect(font(storage, at: code)?.isFixedPitch == true)
        #expect(font(storage, at: ns.range(of: "Some").location)?.fontDescriptor.symbolicTraits.contains(.bold) == false)
    }

    @Test func deletingMarkersRemovesStyle() {
        let (storage, _) = makeStorage()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "a **b** c")
        #expect(font(storage, at: 4)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        storage.replaceCharacters(in: NSRange(location: 2, length: 2), with: "")   // remove opening **
        #expect(storage.string == "a b** c")
        #expect(font(storage, at: 2)?.fontDescriptor.symbolicTraits.contains(.bold) == false)
    }
}
