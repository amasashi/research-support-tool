import Foundation

@MainActor
final class ImportPaperViewModel: ObservableObject {
    @Published var url = ""
    @Published var includeAppendix = false
    @Published var includeReferences = false
    @Published var importedPaper: Paper?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var canImport: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func importPaper() async {
        guard canImport else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await PaperService().importURL(
                url,
                includeAppendix: includeAppendix,
                includeReferences: includeReferences
            )
            var paper = response.paper
            paper.sections = LLMContextBuilder().paperSections(from: paper.sourceText)
            paper.character = PaperCharacterService().updateCharacter(for: paper)
            importedPaper = paper
            try LocalLibraryService().savePaper(paper)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
