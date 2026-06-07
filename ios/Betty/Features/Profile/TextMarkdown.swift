import SwiftUI

extension Text {
    /// Inline markdown (bold + links) with a plain-string fallback.
    init(bettyMarkdown string: String) {
        if let attributed = try? AttributedString(
            markdown: string,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            self = Text(attributed)
        } else {
            self = Text(string)
        }
    }
}
