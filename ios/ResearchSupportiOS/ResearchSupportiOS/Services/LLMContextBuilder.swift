import Foundation

struct PaperTextSection: Identifiable, Hashable {
    var id: Int { index }
    let index: Int
    let title: String
    let text: String

    var characterCount: Int {
        text.count
    }
}

struct LLMContext {
    let text: String
    let description: String
}

struct LLMContextBuilder {
    static let maxTranslationCharacters = 12_000
    static let maxQuestionContextCharacters = 16_000
    static let maxTemplateChunkCharacters = 10_000

    func paperSections(from text: String) -> [PaperSection] {
        sections(from: text).map { section in
            PaperSection(
                id: UUID(),
                index: section.index,
                title: section.title,
                sourceText: section.text,
                translatedText: "",
                summary: "",
                note: ""
            )
        }
    }

    func sections(from text: String) -> [PaperTextSection] {
        let lines = text.components(separatedBy: .newlines)
        var sections: [PaperTextSection] = []
        var currentTitle = "冒頭"
        var currentLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isHeading(trimmed), !currentLines.isEmpty {
                sections.append(
                    PaperTextSection(
                        index: sections.count,
                        title: currentTitle,
                        text: currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
                currentTitle = trimmed
                currentLines = [line]
            } else {
                if isHeading(trimmed), currentLines.isEmpty {
                    currentTitle = trimmed
                }
                currentLines.append(line)
            }
        }

        let finalText = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalText.isEmpty {
            sections.append(PaperTextSection(index: sections.count, title: currentTitle, text: finalText))
        }

        if sections.isEmpty {
            return [PaperTextSection(index: 0, title: "本文", text: text)]
        }
        return sections
    }

    func translationContext(section: PaperTextSection) -> LLMContext {
        let limited = String(section.text.prefix(Self.maxTranslationCharacters))
        let description = section.text.count > limited.count
            ? "\(section.title): \(limited.count.formatted()) / \(section.text.count.formatted()) 文字"
            : "\(section.title): \(limited.count.formatted()) 文字"
        return LLMContext(text: limited, description: description)
    }

    func questionContext(paper: Paper, question: String) -> LLMContext {
        let paragraphs = splitParagraphs(paper.sourceText)
        let related = relatedParagraphs(paragraphs, question: question)
        let selected = related.isEmpty ? Array(paragraphs.prefix(8)) : related
        var parts: [String] = []

        if !paper.summary.isEmpty {
            parts.append("Summary:\n\(paper.summary)")
        }
        if !paper.readingTemplate.isEmpty {
            parts.append("Reading notes:\n\(paper.readingTemplate)")
        }
        parts.append("Relevant passages:\n\(selected.joined(separator: "\n\n"))")

        let text = String(parts.joined(separator: "\n\n").prefix(Self.maxQuestionContextCharacters))
        return LLMContext(
            text: text,
            description: related.isEmpty
                ? "冒頭段落 + 要約/テンプレート"
                : "質問に関連する段落 \(selected.count) 件 + 要約/テンプレート"
        )
    }

    func templateChunks(for paper: Paper) -> [LLMContext] {
        let sections = sections(from: paper.sourceText)
        var chunks: [LLMContext] = []

        for section in sections {
            let text = section.text
            if text.count <= Self.maxTemplateChunkCharacters {
                chunks.append(LLMContext(text: text, description: section.title))
            } else {
                var start = text.startIndex
                var number = 1
                while start < text.endIndex {
                    let end = text.index(start, offsetBy: Self.maxTemplateChunkCharacters, limitedBy: text.endIndex) ?? text.endIndex
                    let chunk = String(text[start..<end])
                    chunks.append(LLMContext(text: chunk, description: "\(section.title) part \(number)"))
                    start = end
                    number += 1
                }
            }
        }

        return chunks
    }

    private func isHeading(_ line: String) -> Bool {
        guard (3...80).contains(line.count) else { return false }
        let lower = line.lowercased()
        let normalized = lower.replacingOccurrences(of: #"^\d+(\.\d+)*\.?\s+"#, with: "", options: .regularExpression)
        let headings = [
            "abstract", "introduction", "background", "related work", "method", "methods",
            "methodology", "experiment", "experiments", "experimental setup", "results",
            "discussion", "limitations", "conclusion", "acknowledgements"
        ]
        return headings.contains(normalized) || normalized.hasPrefix("appendix")
    }

    private func splitParagraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func relatedParagraphs(_ paragraphs: [String], question: String) -> [String] {
        let words = question.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }
        let keywords = Set(words)
        guard !keywords.isEmpty else { return [] }

        var scoredParagraphs: [(paragraph: String, score: Int)] = []
        for paragraph in paragraphs {
            let lower = paragraph.lowercased()
            var score = 0
            for keyword in keywords where lower.contains(keyword) {
                score += 1
            }
            if score > 0 {
                scoredParagraphs.append((paragraph: paragraph, score: score))
            }
        }

        let sortedParagraphs = scoredParagraphs.sorted { left, right in
            left.score > right.score
        }
        return sortedParagraphs.prefix(8).map { $0.paragraph }
    }
}
