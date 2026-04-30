import Foundation

struct TranslationService {
    let openAIClient: OpenAIClient

    func translate(title: String, section: PaperTextSection) async throws -> TranslateResponse {
        let context = LLMContextBuilder().translationContext(section: section)
        let output = try await openAIClient.complete(
            system: """
            You translate English research papers into readable Japanese for early-career researchers.
            Preserve technical terms, equations, citations, and section structure.
            Do not rewrite equations. Put display equations on their own lines, surrounded by blank lines.
            Preserve LaTeX commands, code, variable names, table-like rows, and citation markers.
            Return exactly two Markdown sections: '## 日本語訳' and '## 要約'.
            """,
            user: """
            Title: \(title)
            Section: \(section.title)
            LLM target: \(context.description)

            Paper text:
            \(context.text)
            """
        )

        let summaryMarker = "## 要約"
        let translationMarker = "## 日本語訳"
        if let range = output.range(of: summaryMarker) {
            let translated = String(output[..<range.lowerBound])
                .replacingOccurrences(of: translationMarker, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = output[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return TranslateResponse(documentId: nil, translatedText: translated, summary: summary)
        }

        return TranslateResponse(documentId: nil, translatedText: output, summary: "")
    }
}
