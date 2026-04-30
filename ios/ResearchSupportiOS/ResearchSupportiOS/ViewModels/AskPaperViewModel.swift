import Foundation

@MainActor
final class AskPaperViewModel: ObservableObject {
    @Published var question = ""
    @Published var items: [QuestionAnswer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var canAsk: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func ask(paper: Paper, openAIClient: OpenAIClient) async {
        guard canAsk else { return }
        let currentQuestion = question
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await QuestionService(openAIClient: openAIClient).askWholePaper(
                paper: paper,
                question: currentQuestion
            )
            items.insert(
                QuestionAnswer(question: currentQuestion, answer: response.answer, scope: .wholePaper),
                at: 0
            )
            question = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
