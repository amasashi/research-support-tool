import Foundation

final class AppSettings: ObservableObject {
    private enum Keys {
        static let openAIModel = "openAIModel"
    }

    @Published var openAIAPIKey: String {
        didSet {
            try? KeychainService().save(openAIAPIKey, account: KeychainService.openAIAPIKeyAccount)
        }
    }

    @Published var openAIModel: String {
        didSet {
            UserDefaults.standard.set(openAIModel, forKey: Keys.openAIModel)
        }
    }

    init() {
        openAIAPIKey = (try? KeychainService().read(account: KeychainService.openAIAPIKeyAccount)) ?? ""
        openAIModel = UserDefaults.standard.string(forKey: Keys.openAIModel) ?? "gpt-4.1-mini"
    }
}
