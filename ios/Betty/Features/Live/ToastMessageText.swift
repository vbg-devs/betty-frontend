import Foundation

/// Parses the web's simple-HTML toast messages — `useNotify` messages are rendered via
/// `v-html` and product copy only ever uses bold (`<strong>`, occasionally `<b>`).
/// Bold segments carry `.stronglyEmphasized` inline intent; tags are stripped. An open
/// tag turns bold ON, a close tag OFF (so an unclosed `<strong>` bolds the remainder and
/// a stray close tag is harmless).
nonisolated enum ToastMessageText {
    static func attributed(_ message: String) -> AttributedString {
        var result = AttributedString()
        var strong = false
        var rest = Substring(message)
        while !rest.isEmpty {
            guard let tag = rest.range(of: "</?(strong|b)>", options: [.regularExpression, .caseInsensitive]) else {
                append(String(rest), strong: strong, to: &result)
                break
            }
            append(String(rest[..<tag.lowerBound]), strong: strong, to: &result)
            strong = !rest[tag].hasPrefix("</")
            rest = rest[tag.upperBound...]
        }
        return result
    }

    private static func append(_ chunk: String, strong: Bool, to result: inout AttributedString) {
        guard !chunk.isEmpty else { return }
        var piece = AttributedString(chunk)
        if strong {
            piece.inlinePresentationIntent = .stronglyEmphasized
        }
        result += piece
    }
}
