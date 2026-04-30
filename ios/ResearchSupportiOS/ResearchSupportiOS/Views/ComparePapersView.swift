import SwiftUI

struct ComparePapersView: View {
    let papers: [Paper]
    @State private var selectedPaperIDs: Set<UUID> = []

    private var selectedPapers: [Paper] {
        papers.filter { selectedPaperIDs.contains($0.id) }
    }

    var body: some View {
        List {
            Section("比較する論文") {
                if papers.isEmpty {
                    ContentUnavailableView(
                        "論文がありません",
                        systemImage: "doc.text",
                        description: Text("先に論文 URL から追加してください。")
                    )
                } else {
                    ForEach(papers) { paper in
                        Button {
                            toggle(paper)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(paper.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(paper.summary.isEmpty ? "要約なし" : paper.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: selectedPaperIDs.contains(paper.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedPaperIDs.contains(paper.id) ? .blue : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("簡易比較") {
                if selectedPapers.count < 2 {
                    ContentUnavailableView(
                        "2本以上選択してください",
                        systemImage: "tablecells",
                        description: Text("MVP では生成済みテンプレート、要約、メモを並べます。")
                    )
                } else {
                    ScrollView(.horizontal) {
                        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow {
                                tableHeader("論文")
                                tableHeader("手法・新規性")
                                tableHeader("結果・限界")
                                tableHeader("メモ")
                            }

                            ForEach(selectedPapers) { paper in
                                GridRow {
                                    tableCell(paper.title, width: 180)
                                    tableCell(extractTemplateText(from: paper, headings: ["提案手法", "新規性"]), width: 220)
                                    tableCell(extractTemplateText(from: paper, headings: ["結果", "限界"]), width: 220)
                                    tableCell(paper.notes.isEmpty ? "なし" : paper.notes, width: 220)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("論文比較")
    }

    private func toggle(_ paper: Paper) {
        if selectedPaperIDs.contains(paper.id) {
            selectedPaperIDs.remove(paper.id)
        } else {
            selectedPaperIDs.insert(paper.id)
        }
    }

    private func tableHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .frame(width: 180, alignment: .leading)
            .padding(8)
            .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func tableCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption)
            .textSelection(.enabled)
            .frame(width: width, alignment: .topLeading)
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private func extractTemplateText(from paper: Paper, headings: [String]) -> String {
        guard !paper.readingTemplate.isEmpty else {
            return paper.summary.isEmpty ? "未生成" : paper.summary
        }

        let lines = paper.readingTemplate.components(separatedBy: .newlines)
        var chunks: [String] = []
        var shouldCollect = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("## ") {
                shouldCollect = headings.contains { trimmed.contains($0) }
                if shouldCollect {
                    chunks.append(trimmed.replacingOccurrences(of: "## ", with: ""))
                }
                continue
            }
            if shouldCollect && !trimmed.isEmpty {
                chunks.append(trimmed)
            }
        }

        return chunks.isEmpty ? paper.readingTemplate : chunks.joined(separator: "\n")
    }
}
