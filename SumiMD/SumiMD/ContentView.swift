import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument

    var body: some View {
        MarkdownTextView(text: $document.text)
            .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView(document: .constant(MarkdownDocument(text: "# Hello Sumi\n\nSome **markdown** text.")))
}
