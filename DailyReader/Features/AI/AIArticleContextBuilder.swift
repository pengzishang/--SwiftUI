import Foundation

struct AIArticleContextBuilder {
    static let maximumCharacters = 24_000

    static func make(
        id: Int,
        title: String,
        html: String,
        sourceURL: String?,
        focusedSelection: String? = nil
    ) -> AIArticleContext {
        make(
            id: id,
            title: title,
            plainText: extractText(from: html),
            sourceURL: sourceURL,
            focusedSelection: focusedSelection
        )
    }

    static func make(
        id: Int,
        title: String,
        plainText: String,
        sourceURL: String?,
        focusedSelection: String? = nil
    ) -> AIArticleContext {
        let normalizedText = normalize(plainText)
        let normalizedSelection = focusedSelection.map(normalize).flatMap { $0.isEmpty ? nil : $0 }
        let budgeted = truncate(normalizedText, preserving: normalizedSelection, limit: maximumCharacters)
        return AIArticleContext(
            id: id,
            title: title,
            text: budgeted.text,
            sourceURL: sourceURL,
            focusedSelection: normalizedSelection,
            isTruncated: budgeted.isTruncated
        )
    }

    static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n[\\n ]+", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractText(from html: String) -> String {
        var value = html
        value = value.replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: "<(br|/p|/div|/li|/h[1-6]|/blockquote)[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&ldquo;", "“"), ("&rdquo;", "”"),
            ("&hellip;", "…"), ("&mdash;", "—")
        ]
        for (entity, replacement) in entities {
            value = value.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        return value
    }

    static func truncate(_ text: String, preserving selection: String?, limit: Int) -> (text: String, isTruncated: Bool) {
        guard text.count > limit else { return (text, false) }
        let headCount = limit * 45 / 100
        let tailCount = limit * 25 / 100
        let focusCount = limit - headCount - tailCount
        let head = String(text.prefix(headCount))
        let tail = String(text.suffix(tailCount))
        var focus = ""
        if let selection, let range = text.range(of: selection) {
            let center = text.distance(from: text.startIndex, to: range.lowerBound)
            let startOffset = max(0, center - focusCount / 2)
            let start = text.index(text.startIndex, offsetBy: startOffset)
            let end = text.index(start, offsetBy: min(focusCount, text.distance(from: start, to: text.endIndex)))
            focus = String(text[start..<end])
        }
        let sections = [head, focus, tail].filter { !$0.isEmpty }
        return (sections.joined(separator: "\n\n[…文章上下文已压缩…]\n\n"), true)
    }
}
