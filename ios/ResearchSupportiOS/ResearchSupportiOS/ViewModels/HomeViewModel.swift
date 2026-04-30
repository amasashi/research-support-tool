import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var papers: [Paper] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            papers = try LocalLibraryService().loadPapers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
