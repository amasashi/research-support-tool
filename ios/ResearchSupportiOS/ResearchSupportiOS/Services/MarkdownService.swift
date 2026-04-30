import Foundation

struct MarkdownService {
    func exportMarkdown(paper: Paper) -> MarkdownResponse {
        MarkdownResponse(
            markdown: [
                "# \(paper.title)",
                "",
                "## 論文キャラ",
                "- 分野: \(paper.character.domain.label)",
                "- 難易度: \(paper.character.difficulty.label)",
                "- 性質: \(paper.character.nature.label)",
                "- 状態: \(paper.character.evolutionStage.label)",
                "- 理解度: \(paper.character.understandingScore)%",
                "",
                "## 要約",
                paper.summary.isEmpty ? "未作成" : paper.summary,
                "",
                "## 日本語訳",
                paper.translatedText.isEmpty ? "未翻訳" : paper.translatedText,
                "",
                "## メモ",
                combinedNotes(for: paper).isEmpty ? "なし" : combinedNotes(for: paper),
                "",
                "## 原文",
                paper.sourceText
            ].joined(separator: "\n")
        )
    }

    private func combinedNotes(for paper: Paper) -> String {
        var sections: [String] = []
        if !paper.notes.isEmpty {
            sections.append(paper.notes)
        }
        if !paper.readingTemplate.isEmpty {
            sections.append("## 読み方テンプレート\n\(paper.readingTemplate)")
        }

        let paragraphNotes = paper.paragraphNotes
            .filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.key < $1.key }
            .map { "### 段落 \($0.key + 1)\n\($0.value)" }

        if !paragraphNotes.isEmpty {
            sections.append("## 段落メモ\n" + paragraphNotes.joined(separator: "\n\n"))
        }

        let sectionNotes = paper.sections
            .filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "### \($0.title)\n\($0.note)" }

        if !sectionNotes.isEmpty {
            sections.append("## セクションメモ\n" + sectionNotes.joined(separator: "\n\n"))
        }

        return sections.joined(separator: "\n\n")
    }
}
