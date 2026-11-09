import SwiftUI
import AppKit

/// Markdown editor backed by `NSTextView` (TextKit 2 on current macOS), with live styling.
/// Styling only changes text attributes; the string stays exactly as typed.
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator

        // Plain text only: Markdown must stay exactly as typed.
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true

        // Smart substitutions would silently rewrite Markdown syntax.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Built-in find bar (Cmd+F, and find & replace).
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        let theme = context.coordinator.theme
        textView.font = theme.bodyFont
        textView.typingAttributes = theme.baseAttributes
        textView.textContainerInset = NSSize(width: 16, height: 16)

        // Restyle after every edit (typing, paste, undo, or a new string from the document).
        textView.textStorage?.delegate = context.coordinator

        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Keep the coordinator pointing at the current binding.
        context.coordinator.parent = self

        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only push text in when it changed from outside (e.g. file reverted).
        // While typing, the strings are already equal, so this is a no-op.
        if textView.string != text {
            let oldLocation = textView.selectedRange().location
            textView.string = text
            let newLength = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(oldLocation, newLength), length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: MarkdownTextView
        let theme = MarkdownTheme()
        private var highlighter = MarkdownHighlighter()

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            // Only character edits matter; our own attribute changes land here too.
            guard editedMask.contains(.editedCharacters) else { return }
            let update = highlighter.update(textStorage.string, editedRange: editedRange, changeInLength: delta)
            theme.apply(update.spans, in: update.dirtyRange, to: textStorage)
        }
    }
}
