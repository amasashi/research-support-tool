import Foundation

@MainActor
final class PaperDetailViewModel: ObservableObject {
    @Published var paper: Paper
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var generatedMarkdown = ""
    @Published var isMarkdownPresented = false
    @Published var paragraphQuestion = ""
    @Published var paragraphAnswer = ""
    @Published var paragraphAnswerIndex: Int?
    @Published var selectedSectionIndex = 0
    @Published var llmTargetDescription = ""
    @Published var chatQuestion = ""
    @Published var chatScope: ChatScope = .section

    init(paper: Paper) {
        self.paper = paper
        ensureSections()
    }

    var paragraphs: [PaperParagraph] {
        let sourceParagraphs = splitParagraphs(paper.sourceText)
        let translatedParagraphs = splitParagraphs(paper.translatedText)
        return sourceParagraphs.enumerated().map { index, source in
            PaperParagraph(
                index: index,
                sourceText: source,
                translatedText: translatedParagraphs.indices.contains(index) ? translatedParagraphs[index] : "",
                note: paper.paragraphNotes[index] ?? ""
            )
        }
    }

    var translationSections: [PaperTextSection] {
        paper.sections.map { $0.textSection }
    }

    var selectedSection: PaperSection? {
        if paper.sections.indices.contains(selectedSectionIndex) {
            return paper.sections[selectedSectionIndex]
        }
        return paper.sections.first
    }

    var selectedSectionBindingIndex: Int {
        min(selectedSectionIndex, max(0, paper.sections.count - 1))
    }

    var selectedSectionMessages: [PaperChatMessage] {
        guard let selectedSection else { return paper.chatMessages }
        return paper.chatMessages.filter { message in
            message.scope == .wholePaper || message.sectionID == selectedSection.id
        }
    }

    func savePaper() async {
        ensureSections()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            paper.character = PaperCharacterService().updateCharacter(for: paper)
            try LocalLibraryService().savePaper(paper)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func translateSelectedSection(openAIClient: OpenAIClient) async {
        guard let section = selectedTranslationSection else {
            errorMessage = "翻訳対象セクションがありません。"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            llmTargetDescription = LLMContextBuilder().translationContext(section: section.textSection).description
            let response = try await TranslationService(openAIClient: openAIClient).translate(
                title: paper.title,
                section: section.textSection
            )
            if let index = paper.sections.firstIndex(where: { $0.id == section.id }) {
                paper.sections[index].translatedText = response.translatedText
                paper.sections[index].summary = response.summary
            }
            rebuildAggregates()
            paper.character = PaperCharacterService().updateCharacter(for: paper)
            try LocalLibraryService().savePaper(paper)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveNotes() async {
        await savePaper()
    }

    func updateParagraphNote(index: Int, note: String) async {
        paper.paragraphNotes[index] = note
        await saveNotes()
    }

    func updateSelectedSectionNote(_ note: String) async {
        guard let section = selectedSection,
              let index = paper.sections.firstIndex(where: { $0.id == section.id })
        else { return }
        paper.sections[index].note = note
        await savePaper()
    }

    func askParagraph(_ paragraph: PaperParagraph, openAIClient: OpenAIClient) async {
        let question = paragraphQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            errorMessage = "段落に対する質問を入力してください。"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await QuestionService(openAIClient: openAIClient).askParagraph(
                paper: paper,
                paragraph: paragraph,
                question: question
            )
            paragraphAnswer = response.answer
            paragraphAnswerIndex = paragraph.index
            paragraphQuestion = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateReadingTemplate(openAIClient: OpenAIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await QuestionService(openAIClient: openAIClient).generateReadingTemplate(paper: paper)
            paper.readingTemplate = response.answer
            paper.character = PaperCharacterService().updateCharacter(for: paper)
            try LocalLibraryService().savePaper(paper)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func askChat(openAIClient: OpenAIClient) async {
        let question = chatQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            errorMessage = "質問を入力してください。"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: QuestionResponse
            let sectionID: UUID?
            if chatScope == .section, let selectedSection {
                response = try await QuestionService(openAIClient: openAIClient).askSection(
                    paper: paper,
                    section: selectedSection,
                    question: question
                )
                sectionID = selectedSection.id
            } else {
                response = try await QuestionService(openAIClient: openAIClient).askWholePaper(
                    paper: paper,
                    question: question
                )
                sectionID = nil
            }
            paper.chatMessages.append(
                PaperChatMessage(
                    scope: chatScope,
                    sectionID: sectionID,
                    question: question,
                    answer: response.answer
                )
            )
            chatQuestion = ""
            try LocalLibraryService().savePaper(paper)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportMarkdown() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        generatedMarkdown = MarkdownService().exportMarkdown(paper: paper).markdown
        isMarkdownPresented = true
    }

    private func splitParagraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var selectedTranslationSection: PaperSection? {
        selectedSection
    }

    private func ensureSections() {
        if paper.sections.isEmpty, !paper.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            paper.sections = LLMContextBuilder().paperSections(from: paper.sourceText)
        }
        if selectedSectionIndex >= paper.sections.count {
            selectedSectionIndex = max(0, paper.sections.count - 1)
        }
    }

    private func rebuildAggregates() {
        paper.translatedText = paper.sections
            .filter { !$0.translatedText.isEmpty }
            .map { "## \($0.title)\n\($0.translatedText)" }
            .joined(separator: "\n\n")
        paper.summary = paper.sections
            .filter { !$0.summary.isEmpty }
            .map { "### \($0.title)\n\($0.summary)" }
            .joined(separator: "\n\n")
    }
}
