import Foundation

struct PaperCharacterService {
    func updateCharacter(for paper: Paper) -> PaperCharacter {
        PaperCharacter(
            domain: inferDomain(for: paper),
            difficulty: inferDifficulty(for: paper),
            nature: inferNature(for: paper),
            evolutionStage: inferEvolutionStage(for: paper),
            understandingScore: understandingScore(for: paper)
        )
    }

    private func inferDomain(for paper: Paper) -> PaperDomain {
        let text = searchableText(for: paper)
        let scores: [(PaperDomain, Int)] = [
            (.vlm, score(text, ["vision-language", "multimodal", "image-text", "clip", "vlm"])),
            (.nlp, score(text, ["language model", "llm", "transformer", "token", "corpus", "nlp"])),
            (.cv, score(text, ["image", "detection", "segmentation", "video", "visual recognition"])),
            (.rag, score(text, ["retrieval", "rag", "knowledge base", "embedding", "vector database"])),
            (.theory, score(text, ["theorem", "proof", "lemma", "bound", "convergence"])),
            (.systems, score(text, ["latency", "throughput", "distributed", "memory", "compiler"])),
            (.ml, score(text, ["machine learning", "neural", "training", "model", "dataset"]))
        ]
        return scores.max { $0.1 < $1.1 }.map { $0.1 > 0 ? $0.0 : .unknown } ?? .unknown
    }

    private func inferDifficulty(for paper: Paper) -> PaperDifficulty {
        let text = searchableText(for: paper)
        var value = 0
        if paper.sourceText.count > 20_000 { value += 2 }
        else if paper.sourceText.count > 10_000 { value += 1 }
        if score(text, ["theorem", "proof", "lemma", "convergence"]) >= 2 { value += 2 }
        if score(text, ["ablation", "benchmark", "dataset", "evaluation"]) >= 3 { value += 1 }
        if text.filter({ "∑∫≤≥=→".contains($0) }).count > 20 { value += 1 }

        if value >= 4 { return .advanced }
        if value >= 2 { return .intermediate }
        return .beginner
    }

    private func inferNature(for paper: Paper) -> PaperNature {
        let text = searchableText(for: paper)
        let theory = score(text, ["theorem", "proof", "lemma", "bound", "convergence"])
        let experiment = score(text, ["experiment", "benchmark", "dataset", "ablation", "evaluation"])
        let practical = score(text, ["system", "deployment", "application", "pipeline", "tool"])
        let survey = score(text, ["survey", "review", "taxonomy", "comprehensive", "overview"])
        let values = [theory, experiment, practical, survey].sorted(by: >)

        if survey >= 2 { return .survey }
        if values.count > 1 && values[0] > 0 && values[0] == values[1] { return .mixed }
        if theory == values.first { return .theoretical }
        if experiment == values.first { return .experimental }
        if practical == values.first { return .practical }
        return .mixed
    }

    private func inferEvolutionStage(for paper: Paper) -> PaperEvolutionStage {
        let paragraphNoteCount = paper.paragraphNotes.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let noteLength = paper.notes.trimmingCharacters(in: .whitespacesAndNewlines).count

        if !paper.readingTemplate.isEmpty && (noteLength >= 200 || paragraphNoteCount >= 3) {
            return .mastered
        }
        if !paper.translatedText.isEmpty || noteLength > 0 || paragraphNoteCount > 0 {
            return .reading
        }
        return .egg
    }

    private func understandingScore(for paper: Paper) -> Int {
        var value = 0
        if !paper.sourceText.isEmpty { value += 15 }
        if !paper.translatedText.isEmpty { value += 25 }
        if !paper.summary.isEmpty { value += 15 }
        if !paper.readingTemplate.isEmpty { value += 20 }
        value += min(15, paper.notes.count / 20)
        value += min(10, paper.paragraphNotes.values.filter { !$0.isEmpty }.count * 3)
        return min(100, value)
    }

    private func searchableText(for paper: Paper) -> String {
        "\(paper.title)\n\(paper.summary)\n\(paper.sourceText.prefix(4000))\n\(paper.readingTemplate)"
            .lowercased()
    }

    private func score(_ text: String, _ keywords: [String]) -> Int {
        keywords.reduce(0) { partial, keyword in
            partial + (text.contains(keyword) ? 1 : 0)
        }
    }
}
