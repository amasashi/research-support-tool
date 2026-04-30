import Foundation

struct QuestionService {
    let openAIClient: OpenAIClient

    func askWholePaper(paper: Paper, question: String) async throws -> QuestionResponse {
        let context = LLMContextBuilder().questionContext(paper: paper, question: question)
        let answer = try await openAIClient.complete(
            system: "Answer in Japanese for a junior researcher. Be precise, cite the provided paper text when useful, and state uncertainty clearly.",
            user: """
            Title: \(paper.title)
            LLM target: \(context.description)

            Context:
            \(context.text)

            Question: \(question)
            """
        )
        return QuestionResponse(answer: answer)
    }

    func askParagraph(paper: Paper, paragraph: PaperParagraph, question: String) async throws -> QuestionResponse {
        let answer = try await openAIClient.complete(
            system: "Answer in Japanese for a junior researcher. Focus on the selected passage and use the whole paper only as context.",
            user: """
            Title: \(paper.title)

            Selected passage:
            \(paragraph.sourceText)

            Japanese translation of selected passage:
            \(paragraph.translatedText)

            Whole paper context:
            \(LLMContextBuilder().questionContext(paper: paper, question: question).text)

            Question: \(question)
            """
        )
        return QuestionResponse(answer: answer)
    }

    func askSection(paper: Paper, section: PaperSection, question: String) async throws -> QuestionResponse {
        let answer = try await openAIClient.complete(
            system: "Answer in Japanese for a junior researcher. Focus on the selected paper section. Be precise and state uncertainty clearly.",
            user: """
            Title: \(paper.title)
            Section: \(section.title)

            Source section:
            \(String(section.sourceText.prefix(LLMContextBuilder.maxQuestionContextCharacters)))

            Japanese translation of section:
            \(String(section.translatedText.prefix(LLMContextBuilder.maxQuestionContextCharacters)))

            Question: \(question)
            """
        )
        return QuestionResponse(answer: answer)
    }

    func generateReadingTemplate(paper: Paper) async throws -> QuestionResponse {
        let prompt = """
        この論文を研究メモとして再利用できるように、以下の観点で日本語のMarkdownとして整理してください。

        ## 論文の目的
        ## 解決課題
        ## 提案手法
        ## 新規性
        ## 実験設定
        ## 結果
        ## 限界
        ## 自分の研究への応用
        """
        let builder = LLMContextBuilder()
        let chunks = builder.templateChunks(for: paper)
        let summaries = try await summarizeChunks(chunks, title: paper.title)
        let answer = try await openAIClient.complete(
            system: "Create concise Japanese research notes from the provided paper. Preserve uncertainty and avoid inventing details.",
            user: """
            Title: \(paper.title)

            Chunk summaries:
            \(summaries.joined(separator: "\n\n---\n\n"))

            Japanese translation:
            \(String(paper.translatedText.prefix(8_000)))

            \(prompt)
            """
        )
        return QuestionResponse(answer: answer)
    }

    private func summarizeChunks(_ chunks: [LLMContext], title: String) async throws -> [String] {
        var summaries: [String] = []
        for chunk in chunks.prefix(8) {
            let summary = try await openAIClient.complete(
                system: "Summarize this paper section in Japanese for later synthesis. Focus on purpose, method, experiment, result, and limitation when present.",
                user: """
                Title: \(title)
                Section: \(chunk.description)

                Text:
                \(chunk.text)
                """
            )
            summaries.append("## \(chunk.description)\n\(summary)")
        }
        return summaries
    }
}
