import SwiftUI
import AppKit

/// Plain-text editor backed by `NSTextView` (TextKit 2 on current macOS).
/// Milestone 2 will add live Markdown styling on top of this.
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

        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 16, height: 16)

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

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
