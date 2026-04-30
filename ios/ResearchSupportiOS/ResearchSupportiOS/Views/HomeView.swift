import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var isSettingsPresented = false
    @State private var isComparePresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ImportPaperView()
                    } label: {
                        Label("論文 URL から追加", systemImage: "plus.circle.fill")
                    }
                }

                Section("保存済み論文") {
                    if viewModel.papers.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView(
                            "保存済み論文はまだありません",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("URL から本文を取り込み、翻訳すると一覧に表示されます。")
                        )
                    } else {
                        ForEach(viewModel.papers) { paper in
                            NavigationLink {
                                PaperDetailView(paper: paper)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(paper.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    if !paper.summary.isEmpty {
                                        Text(paper.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Text("更新: \(paper.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Research Support")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isComparePresented = true
                    } label: {
                        Image(systemName: "tablecells")
                    }
                    .accessibilityLabel("論文比較")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
            .onAppear {
                Task {
                    await viewModel.load()
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(isPresented: $isComparePresented) {
                NavigationStack {
                    ComparePapersView(papers: viewModel.papers)
                }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding()
                }
            }
        }
    }
}
