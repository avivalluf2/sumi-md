import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Markdown files (.md, .markdown). Declared as an imported type so it also
    /// resolves on systems where no app has registered it.
    nonisolated static let markdown = UTType(
        importedAs: "net.daringfireball.markdown",
        conformingTo: .plainText
    )
}

/// A Markdown file on disk. The text is kept exactly as typed (UTF-8, no conversion).
nonisolated struct MarkdownDocument: FileDocument {
    var text: String

    init(text: String = "") {
        self.text = text
    }

    // The first type is used for new documents; .plainText lets you open .txt files too.
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
