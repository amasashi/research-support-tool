import Foundation
import PDFKit

struct PaperService {
    func importURL(
        _ url: String,
        includeAppendix: Bool,
        includeReferences: Bool
    ) async throws -> UrlImportResponse {
        let normalizedURL = try normalizeURL(url)
        let (data, response) = try await URLSession.shared.data(from: normalizedURL)
        let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""

        let title: String
        let rawText: String
        let detectedContentType: String

        if contentType.contains("pdf") || normalizedURL.pathExtension.lowercased() == "pdf" {
            title = normalizedURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ")
            rawText = extractPDFText(data: data)
            detectedContentType = "application/pdf"
        } else {
            let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            title = extractHTMLTitle(html) ?? normalizedURL.lastPathComponent.replacingOccurrences(of: "-", with: " ")
            rawText = extractHTMLText(html)
            detectedContentType = "text/html"
        }

        let text = filterSections(cleanText(rawText), includeAppendix: includeAppendix, includeReferences: includeReferences)
        if text.count < 100 {
            throw APIError.httpStatus(422, "本文を十分に抽出できませんでした。PDF URL または本文貼り付けで再試行してください。")
        }

        return UrlImportResponse(
            title: title.isEmpty ? "Imported paper" : title,
            text: text,
            sourceUrl: normalizedURL.absoluteString,
            contentType: detectedContentType,
            characterCount: text.count
        )
    }

    private func normalizeURL(_ value: String) throws -> URL {
        guard var components = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme,
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty
        else {
            throw APIError.invalidURL
        }

        if host == "arxiv.org", components.path.hasPrefix("/abs/") {
            components.path = components.path.replacingOccurrences(of: "/abs/", with: "/pdf/")
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    private func extractPDFText(data: Data) -> String {
        guard let document = PDFDocument(data: data) else {
            return ""
        }
        return (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n\n")
    }

    private func extractHTMLTitle(_ html: String) -> String? {
        guard let range = html.range(of: #"<title[^>]*>(.*?)</title>"#, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        return html[range]
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractHTMLText(_ html: String) -> String {
        html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"</(p|h1|h2|h3|li|section|article|div)>"#, with: "\n\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00}", with: " ")
            .replacingOccurrences(of: #"-\n(?=[a-z])"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func filterSections(_ text: String, includeAppendix: Bool, includeReferences: Bool) -> String {
        var kept: [String] = []
        var inAppendix = false
        var inReferences = false

        for line in text.components(separatedBy: .newlines) {
            let lower = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let section = lower.replacingOccurrences(of: #"^\d+(\.\d+)*\.?\s+"#, with: "", options: .regularExpression)

            if section == "references" || section == "bibliography" {
                inReferences = true
                if includeReferences { kept.append(line) }
                continue
            }

            if section.hasPrefix("appendix") || section.hasPrefix("appendices") {
                inAppendix = true
                inReferences = false
                if includeAppendix { kept.append(line) }
                continue
            }

            if ["abstract", "introduction", "background", "method", "methods", "experiments", "results", "discussion", "conclusion", "limitations"].contains(section) {
                inReferences = false
                if !includeAppendix { inAppendix = false }
            }

            if inReferences && !includeReferences { continue }
            if inAppendix && !includeAppendix { continue }
            kept.append(line)
        }

        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
