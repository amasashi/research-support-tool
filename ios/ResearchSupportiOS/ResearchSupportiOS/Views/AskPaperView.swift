import SwiftUI

struct AskPaperView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel = AskPaperViewModel()
    let paper: Paper

    var body: some View {
        List {
            Section("質問") {
                TextEditor(text: $viewModel.question)
                    .frame(minHeight: 120)

                Button {
                    Task {
                        await viewModel.ask(paper: paper, openAIClient: openAIClient)
                    }
                } label: {
                    Label("質問する", systemImage: "paperplane")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.canAsk)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }

            Section("回答") {
                if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "回答はまだありません",
                        systemImage: "message",
                        description: Text("論文全体について質問してください。")
                    )
                } else {
                    ForEach(viewModel.items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.question)
                                .font(.headline)
                            Text(item.scope.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.answer)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("論文に質問")
        .loadingOverlay(viewModel.isLoading)
    }

    private var openAIClient: OpenAIClient {
        OpenAIClient(apiKey: appSettings.openAIAPIKey, model: appSettings.openAIModel)
    }
}
