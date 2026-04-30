import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section("OpenAI") {
                SecureField("OpenAI API Key", text: $appSettings.openAIAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Model", text: $appSettings.openAIModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task {
                        await viewModel.checkConnection(apiKey: appSettings.openAIAPIKey, model: appSettings.openAIModel)
                    }
                } label: {
                    Label("接続確認", systemImage: "checkmark.circle")
                }
                .disabled(viewModel.isChecking)

                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("API Key は iOS Keychain に保存されます。自分専用利用を前提にした設定です。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("設定")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完了") {
                    dismiss()
                }
            }
        }
    }
}
