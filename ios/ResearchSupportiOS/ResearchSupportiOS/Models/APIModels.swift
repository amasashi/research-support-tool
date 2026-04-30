import Foundation

struct HealthResponse: Decodable {
    let status: String
}

struct UrlImportRequest: Encodable {
    let url: String
    let includeAppendix: Bool
    let includeReferences: Bool
}

struct UrlImportResponse: Decodable {
    let title: String
    let text: String
    let sourceUrl: String
    let contentType: String
    let characterCount: Int

    var paper: Paper {
        Paper(
            id: UUID(),
            documentID: nil,
            title: title,
            sourceText: text,
            translatedText: "",
            summary: "",
            sourceURL: sourceUrl,
            contentType: contentType,
            notes: "",
            updatedAt: Date()
        )
    }
}

struct TranslateRequest: Encodable {
    let title: String
    let text: String
}

struct TranslateResponse: Decodable {
    let documentId: Int?
    let translatedText: String
    let summary: String
}

struct QuestionRequest: Encodable {
    let documentId: Int?
    let title: String
    let sourceText: String
    let translatedText: String
    let question: String
    let selectedText: String
}

struct QuestionResponse: Decodable {
    let answer: String
}

struct MarkdownRequest: Encodable {
    let title: String
    let sourceText: String
    let translatedText: String
    let summary: String
    let notes: String
}

struct MarkdownResponse: Decodable {
    let markdown: String
}
