import SwiftUI

struct ImportPaperView: View {
    @StateObject private var viewModel = ImportPaperViewModel()

    var body: some View {
        Form {
            Section("論文 URL") {
                TextField("https://arxiv.org/abs/... または PDF URL", text: $viewModel.url, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }

            Section("取り込みオプション") {
                Toggle("Appendix も含める", isOn: $viewModel.includeAppendix)
                Toggle("引用文献も含める", isOn: $viewModel.includeReferences)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }

            Section {
                Button {
                    Task {
                        await viewModel.importPaper()
                    }
                } label: {
                    Label("本文を取り込む", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.canImport)
            }

            if let importedPaper = viewModel.importedPaper {
                Section("取り込み結果") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(importedPaper.title)
                            .font(.headline)
                        Text("\(importedPaper.sourceText.count.formatted()) 文字")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink {
                        PaperDetailView(paper: importedPaper)
                    } label: {
                        Label("詳細を開く", systemImage: "doc.text")
                    }
                }
            }
        }
        .navigationTitle("論文を追加")
        .loadingOverlay(viewModel.isLoading)
    }
}
