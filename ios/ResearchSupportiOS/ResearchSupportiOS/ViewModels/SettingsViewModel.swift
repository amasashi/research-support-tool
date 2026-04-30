import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var statusMessage = ""
    @Published var isChecking = false

    func checkConnection(apiKey: String, model: String) async {
        isChecking = true
        statusMessage = ""
        defer { isChecking = false }

        do {
            _ = try await OpenAIClient(apiKey: apiKey, model: model).complete(
                system: "Reply with exactly: ok",
                user: "connection test"
            )
            statusMessage = "OpenAI API に接続できました。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
