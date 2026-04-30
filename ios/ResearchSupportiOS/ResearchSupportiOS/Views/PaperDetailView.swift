import SwiftUI
import WebKit

struct PaperDetailView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel: PaperDetailViewModel
    @State private var selectedTab: PaperDetailTab = .source

    init(paper: Paper) {
        _viewModel = StateObject(wrappedValue: PaperDetailViewModel(paper: paper))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("表示", selection: $selectedTab) {
                ForEach(PaperDetailTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    header
                    sectionSelector

                    switch selectedTab {
                    case .source:
                        sourceSection
                    case .translation:
                        translationSection
                    case .paragraphs:
                        paragraphsSection
                    case .template:
                        templateSection
                    case .notes:
                        notesSection
                    case .qa:
                        qaSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle("論文詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.exportMarkdown()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Markdown 出力")
            }
        }
        .sheet(isPresented: $viewModel.isMarkdownPresented) {
            NavigationStack {
                MarkdownPreviewView(markdown: viewModel.generatedMarkdown)
            }
        }
        .loadingOverlay(viewModel.isLoading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("タイトル", text: $viewModel.paper.title, axis: .vertical)
                .font(.title3.bold())
            Button {
                Task {
                    await viewModel.savePaper()
                }
            } label: {
                Label("タイトルと本文を保存", systemImage: "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            HStack {
                if let documentID = viewModel.paper.documentID {
                    Label("ID: \(documentID)", systemImage: "number")
                } else {
                    Label("未保存", systemImage: "tray")
                }
                Spacer()
                Text("\(viewModel.paper.sourceText.count.formatted()) 文字")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            CharacterBadgeView(character: viewModel.paper.character)
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("選択セクションの原文", systemImage: "doc.text")
                .font(.headline)
            if let section = viewModel.selectedSection {
                MathPaperTextView(text: section.sourceText)
            } else {
                ContentUnavailableView("セクションがありません", systemImage: "doc.text")
            }
            Button {
                Task {
                    await viewModel.savePaper()
                }
            } label: {
                Label("原文を保存", systemImage: "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var sectionSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("読むセクション", systemImage: "list.bullet")
                .font(.headline)
            Picker("読むセクション", selection: $viewModel.selectedSectionIndex) {
                ForEach(viewModel.paper.sections) { section in
                    Text("\(section.title) (\(section.characterCount.formatted())文字)")
                        .tag(section.index)
                }
            }
            .pickerStyle(.menu)

            if let section = viewModel.selectedSection {
                HStack {
                    Label("\(section.characterCount.formatted())文字", systemImage: "textformat.size")
                    Spacer()
                    if section.translatedText.isEmpty {
                        Label("未翻訳", systemImage: "circle")
                    } else {
                        Label("翻訳済み", systemImage: "checkmark.circle.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Label("翻訳対象セクション", systemImage: "scope")
                    .font(.headline)
                if let section = viewModel.selectedSection {
                    Text(section.title)
                        .font(.headline)
                    Text("\(section.characterCount.formatted())文字")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("翻訳は全文ではなく、上で選択したセクションのみをOpenAI APIへ送信します。長いセクションは最大 \(LLMContextBuilder.maxTranslationCharacters.formatted()) 文字までです。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !viewModel.llmTargetDescription.isEmpty {
                    Text("直近のLLM対象: \(viewModel.llmTargetDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await viewModel.translateSelectedSection(openAIClient: openAIClient)
                    }
                } label: {
                    Label("選択セクションを翻訳", systemImage: "translate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            if !viewModel.paper.summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("要約", systemImage: "text.quote")
                        .font(.headline)
                    Text(viewModel.paper.summary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("日本語訳", systemImage: "book")
                    .font(.headline)
                if viewModel.selectedSection?.translatedText.isEmpty ?? true {
                    ContentUnavailableView(
                        "翻訳はまだありません",
                        systemImage: "translate",
                        description: Text("選択セクションを翻訳してください。")
                    )
                } else {
                    MathPaperTextView(text: viewModel.selectedSection?.translatedText ?? "")
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("メモ", systemImage: "pencil")
                .font(.headline)
            TextEditor(text: $viewModel.paper.notes)
                .frame(minHeight: 320)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            Label("選択セクションのメモ", systemImage: "note.text")
                .font(.headline)
            TextEditor(
                text: Binding(
                    get: { viewModel.selectedSection?.note ?? "" },
                    set: { newValue in
                        if let section = viewModel.selectedSection,
                           let index = viewModel.paper.sections.firstIndex(where: { $0.id == section.id }) {
                            viewModel.paper.sections[index].note = newValue
                        }
                    }
                )
            )
            .frame(minHeight: 180)
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            Button {
                Task {
                    await viewModel.saveNotes()
                }
            } label: {
                Label("メモを保存", systemImage: "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var paragraphsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("段落単位リーディング", systemImage: "text.alignleft")
                .font(.headline)

            if viewModel.paragraphs.isEmpty {
                ContentUnavailableView(
                    "段落がありません",
                    systemImage: "paragraphsign",
                    description: Text("原文を取り込むと段落単位で表示できます。")
                )
            } else {
                ForEach(viewModel.paragraphs) { paragraph in
                    ParagraphCardView(
                        paragraph: paragraph,
                        question: $viewModel.paragraphQuestion,
                        answer: viewModel.paragraphAnswerIndex == paragraph.index ? viewModel.paragraphAnswer : "",
                        onSaveNote: { note in
                            Task {
                                await viewModel.updateParagraphNote(index: paragraph.index, note: note)
                            }
                        },
                        onAsk: {
                            Task {
                                await viewModel.askParagraph(paragraph, openAIClient: openAIClient)
                            }
                        }
                    )
                }
            }
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("読み方テンプレート", systemImage: "list.bullet.rectangle")
                .font(.headline)

            Button {
                Task {
                    await viewModel.generateReadingTemplate(openAIClient: openAIClient)
                }
            } label: {
                Label("テンプレートを生成", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if viewModel.paper.readingTemplate.isEmpty {
                ContentUnavailableView(
                    "テンプレートはまだありません",
                    systemImage: "doc.badge.plus",
                    description: Text("論文の目的、手法、新規性、限界などをワンタップで整理します。")
                )
            } else {
                Text(viewModel.paper.readingTemplate)
                    .textSelection(.enabled)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var qaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("質問範囲", selection: $viewModel.chatScope) {
                ForEach(ChatScope.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            Text(viewModel.chatScope == .section
                 ? "選択セクションに対して質問します。"
                 : "論文全体への質問では、全文をそのまま送らず、要約・テンプレート・質問に関連する段落を優先してOpenAI APIへ送信します。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(viewModel.selectedSectionMessages) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(item.scope.label, systemImage: item.scope == .section ? "doc.text.magnifyingglass" : "message")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(item.question)
                            .font(.headline)
                        MathPaperTextView(text: item.answer)
                    }
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            TextEditor(text: $viewModel.chatQuestion)
                .frame(minHeight: 90)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            Button {
                Task {
                    await viewModel.askChat(openAIClient: openAIClient)
                }
            } label: {
                Label("質問する", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.chatQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var openAIClient: OpenAIClient {
        OpenAIClient(apiKey: appSettings.openAIAPIKey, model: appSettings.openAIModel)
    }
}

private enum PaperDetailTab: String, CaseIterable, Identifiable {
    case source
    case translation
    case paragraphs
    case template
    case notes
    case qa

    var id: String { rawValue }

    var title: String {
        switch self {
        case .source:
            return "原文"
        case .translation:
            return "翻訳"
        case .paragraphs:
            return "段落"
        case .template:
            return "型"
        case .notes:
            return "メモ"
        case .qa:
            return "Q&A"
        }
    }
}

private struct CharacterBadgeView: View {
    let character: PaperCharacter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(character.domain.label, systemImage: character.domain.systemImage)
                Text(character.difficulty.label)
                Text(character.nature.label)
                Spacer(minLength: 0)
                Text(character.evolutionStage.label)
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            HStack(spacing: 8) {
                ProgressView(value: character.evolutionStage.progress)
                Text("\(character.understandingScore)%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("論文属性 \(character.domain.label)、\(character.difficulty.label)、\(character.nature.label)、\(character.evolutionStage.label)、理解度 \(character.understandingScore) パーセント")
    }
}

private struct MathPaperTextView: View {
    let text: String
    @State private var contentHeight: CGFloat = 480

    var body: some View {
        MathMarkdownWebView(markdown: text, contentHeight: $contentHeight)
            .frame(minHeight: max(480, contentHeight))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MathMarkdownWebView: UIViewRepresentable {
    let markdown: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "height")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html(from: markdown), baseURL: nil)
    }

    private func html(from markdown: String) -> String {
        let body = markdownToHTML(markdown)
        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
          <script>
            window.MathJax = {
              tex: {
                inlineMath: [['\\\\(', '\\\\)'], ['$', '$']],
                displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']],
                processEscapes: true
              },
              svg: { fontCache: 'global' }
            };
          </script>
          <script async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js"></script>
          <style>
            :root {
              color-scheme: light dark;
              font: -apple-system-body;
            }
            body {
              margin: 0;
              padding: 0;
              font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
              font-size: 17px;
              line-height: 1.72;
              color: CanvasText;
              background: transparent;
              word-break: break-word;
            }
            h1, h2, h3 {
              line-height: 1.32;
              margin: 1.1em 0 0.45em;
              font-weight: 700;
            }
            h1 { font-size: 1.28em; }
            h2 { font-size: 1.18em; }
            h3 { font-size: 1.08em; }
            p { margin: 0.72em 0; }
            ul, ol { padding-left: 1.35em; }
            li { margin: 0.32em 0; }
            pre, table, .math-display {
              overflow-x: auto;
              -webkit-overflow-scrolling: touch;
            }
            pre {
              padding: 0.75em;
              border-radius: 8px;
              background: rgba(127, 127, 127, 0.13);
              font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
              font-size: 0.9em;
              white-space: pre;
            }
            code {
              font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
              background: rgba(127, 127, 127, 0.13);
              border-radius: 4px;
              padding: 0.1em 0.25em;
            }
            pre code {
              background: transparent;
              padding: 0;
            }
            table {
              border-collapse: collapse;
              display: block;
              width: max-content;
              max-width: 100%;
              margin: 0.9em 0;
            }
            th, td {
              border: 1px solid rgba(127, 127, 127, 0.35);
              padding: 0.35em 0.55em;
              vertical-align: top;
            }
            blockquote {
              margin: 0.8em 0;
              padding-left: 0.85em;
              border-left: 4px solid rgba(127, 127, 127, 0.35);
              color: rgba(127, 127, 127, 0.95);
            }
            mjx-container[jax="SVG"] {
              overflow-x: auto;
              overflow-y: hidden;
              max-width: 100%;
              padding: 0.2em 0;
            }
            a { color: -apple-system-link; }
          </style>
        </head>
        <body>
          \(body)
          <script>
            function reportHeight() {
              const height = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
              window.webkit.messageHandlers.height.postMessage(height);
            }
            window.addEventListener('load', function() {
              if (window.MathJax && MathJax.typesetPromise) {
                MathJax.typesetPromise().then(reportHeight);
              } else {
                reportHeight();
              }
            });
            setTimeout(reportHeight, 700);
            setTimeout(reportHeight, 1600);
          </script>
        </body>
        </html>
        """
    }

    private func markdownToHTML(_ markdown: String) -> String {
        var blocks: [String] = []
        var lines = markdown.components(separatedBy: .newlines)
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                var codeLines: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                index += 1
                blocks.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
                continue
            }

            if trimmed.hasPrefix("$$") || trimmed.hasPrefix("\\[") {
                var mathLines = [trimmed]
                index += 1
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    mathLines.append(current)
                    index += 1
                    if current.hasSuffix("$$") || current.hasSuffix("\\]") {
                        break
                    }
                }
                blocks.append("<div class=\"math-display\">\(escapeHTML(mathLines.joined(separator: "\n")))</div>")
                continue
            }

            if let heading = headingHTML(trimmed) {
                blocks.append(heading)
                index += 1
                continue
            }

            if isTableStart(lines, at: index) {
                var tableLines: [String] = []
                while index < lines.count, lines[index].contains("|") {
                    tableLines.append(lines[index])
                    index += 1
                }
                blocks.append(tableHTML(tableLines))
                continue
            }

            if isListLine(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard isListLine(current) else { break }
                    items.append(cleanListMarker(current))
                    index += 1
                }
                blocks.append("<ul>\(items.map { "<li>\(inlineHTML($0))</li>" }.joined())</ul>")
                continue
            }

            var paragraphLines = [trimmed]
            index += 1
            while index < lines.count {
                let current = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if current.isEmpty || current.hasPrefix("#") || current.hasPrefix("```") || current.hasPrefix("$$") || current.hasPrefix("\\[") || isListLine(current) || current.contains("|") {
                    break
                }
                paragraphLines.append(current)
                index += 1
            }
            blocks.append("<p>\(inlineHTML(paragraphLines.joined(separator: " ")))</p>")
        }

        return blocks.joined(separator: "\n")
    }

    private func headingHTML(_ line: String) -> String? {
        let level = line.prefix { $0 == "#" }.count
        guard (1...3).contains(level) else { return nil }
        let title = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        return "<h\(level)>\(inlineHTML(String(title)))</h\(level)>"
    }

    private func tableHTML(_ lines: [String]) -> String {
        let rows = lines
            .filter { !$0.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "-: ")).isEmpty }
            .map { line in
                let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                return "<tr>\(cells.map { "<td>\(inlineHTML(String($0)))</td>" }.joined())</tr>"
            }
        return "<table>\(rows.joined())</table>"
    }

    private func isTableStart(_ lines: [String], at index: Int) -> Bool {
        guard index + 1 < lines.count else { return false }
        return lines[index].contains("|") && lines[index + 1].contains("|") && lines[index + 1].contains("-")
    }

    private func isListLine(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil
    }

    private func cleanListMarker(_ line: String) -> String {
        line.replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\d+\.\s+"#, with: "", options: .regularExpression)
    }

    private func inlineHTML(_ text: String) -> String {
        var escaped = escapeHTML(text)
        escaped = escaped.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: #"<strong>$1</strong>"#, options: .regularExpression)
        escaped = escaped.replacingOccurrences(of: #"`([^`]+)`"#, with: #"<code>$1</code>"#, options: .regularExpression)
        return escaped
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var contentHeight: CGFloat

        init(contentHeight: Binding<CGFloat>) {
            _contentHeight = contentHeight
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "height" else { return }
            if let height = message.body as? CGFloat {
                contentHeight = height
            } else if let number = message.body as? NSNumber {
                contentHeight = CGFloat(truncating: number)
            }
        }
    }
}

private struct ReadablePaperTextView: View {
    let text: String

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                switch block.kind {
                case .heading:
                    Text(block.displayText)
                        .font(block.headingLevel == 1 ? .title3.bold() : .headline)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .math:
                    horizontalBlock(block.displayText, label: "式")
                case .code:
                    horizontalBlock(block.displayText, label: "コード")
                case .table:
                    horizontalBlock(block.displayText, label: "表")
                case .list:
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(block.text.components(separatedBy: .newlines).indices, id: \.self) { index in
                            let line = block.text.components(separatedBy: .newlines)[index]
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                readableText(cleanListMarker(line))
                            }
                        }
                    }
                case .body:
                    readableText(block.text)
                }
            }
        }
    }

    private var blocks: [ReadableBlock] {
        parseBlocks(text)
            .enumerated()
            .map { index, parsed in
                ReadableBlock(id: index, text: parsed.text, kind: parsed.kind)
            }
    }

    private func parseBlocks(_ text: String) -> [(text: String, kind: ReadableBlock.Kind)] {
        var result: [(text: String, kind: ReadableBlock.Kind)] = []
        var current: [String] = []
        var inFence = false
        var fenceKind: ReadableBlock.Kind = .code

        func flushCurrent() {
            let raw = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty {
                result.append((text: raw, kind: kind(for: raw)))
            }
            current.removeAll()
        }

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") {
                if inFence {
                    result.append((text: current.joined(separator: "\n"), kind: fenceKind))
                    current.removeAll()
                    inFence = false
                } else {
                    flushCurrent()
                    inFence = true
                    fenceKind = trimmed.lowercased().contains("math") ? .math : .code
                }
                continue
            }

            if inFence {
                current.append(line)
                continue
            }

            if trimmed.isEmpty {
                flushCurrent()
            } else {
                current.append(line)
            }
        }

        if inFence {
            result.append((text: current.joined(separator: "\n"), kind: fenceKind))
        } else {
            flushCurrent()
        }
        return result
    }

    private func horizontalBlock(_ text: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: true) {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func readableText(_ text: String) -> some View {
        Group {
            if let attributed = try? AttributedString(markdown: text) {
                Text(attributed)
            } else {
                Text(text)
            }
        }
        .textSelection(.enabled)
        .lineSpacing(6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cleanListMarker(_ line: String) -> String {
        line.replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\d+\.\s+"#, with: "", options: .regularExpression)
    }

    private func oldBlocks() -> [ReadableBlock] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, raw in
                ReadableBlock(id: index, text: raw, kind: kind(for: raw))
            }
    }

    private func kind(for block: String) -> ReadableBlock.Kind {
        if block.hasPrefix("#") {
            return .heading
        }
        if isTable(block) {
            return .table
        }
        if isList(block) {
            return .list
        }
        if looksLikeMath(block) {
            return .math
        }
        return .body
    }

    private func looksLikeMath(_ text: String) -> Bool {
        let mathTokens = ["$$", "\\(", "\\)", "\\[", "\\]", "\\frac", "\\sum", "\\int", "\\theta", "\\lambda", "\\math", "≤", "≥", "∑", "∫", "→"]
        if mathTokens.contains(where: { text.contains($0) }) {
            return true
        }
        let symbolCount = text.filter { "=+-*/^_{}[]|<>".contains($0) }.count
        return text.count < 500 && symbolCount >= 8
    }

    private func isTable(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let pipeLines = lines.filter { $0.contains("|") }
        return pipeLines.count >= 2
    }

    private func isList(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let listLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil
        }
        return !listLines.isEmpty && listLines.count == lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}

private struct ReadableBlock: Identifiable {
    enum Kind {
        case heading
        case body
        case math
        case code
        case table
        case list
    }

    let id: Int
    let text: String
    let kind: Kind

    var displayText: String {
        if kind == .heading {
            return text.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
        }
        if kind == .math {
            return text
                .replacingOccurrences(of: "$$", with: "")
                .replacingOccurrences(of: "\\[", with: "")
                .replacingOccurrences(of: "\\]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    var headingLevel: Int {
        guard kind == .heading else { return 0 }
        return text.prefix { $0 == "#" }.count
    }
}

private struct ParagraphCardView: View {
    let paragraph: PaperParagraph
    @Binding var question: String
    let answer: String
    let onSaveNote: (String) -> Void
    let onAsk: () -> Void
    @State private var note: String

    init(
        paragraph: PaperParagraph,
        question: Binding<String>,
        answer: String,
        onSaveNote: @escaping (String) -> Void,
        onAsk: @escaping () -> Void
    ) {
        self.paragraph = paragraph
        _question = question
        self.answer = answer
        self.onSaveNote = onSaveNote
        self.onAsk = onAsk
        _note = State(initialValue: paragraph.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("段落 \(paragraph.index + 1)")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("原文")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(paragraph.sourceText)
                    .textSelection(.enabled)

                if !paragraph.translatedText.isEmpty {
                    Divider()
                    Text("日本語")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(paragraph.translatedText)
                        .textSelection(.enabled)
                }
            }

            TextEditor(text: $note)
                .frame(minHeight: 80)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Button {
                    onSaveNote(note)
                } label: {
                    Label("メモ保存", systemImage: "tray.and.arrow.down")
                }

                Spacer()

                Button {
                    onAsk()
                } label: {
                    Label("この段落に質問", systemImage: "message")
                }
            }
            .font(.callout)

            TextField("段落への質問", text: $question, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            if !answer.isEmpty {
                Text(answer)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MarkdownPreviewView: View {
    let markdown: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            TextEditor(text: .constant(markdown))
                .font(.body.monospaced())
                .padding()
        }
        .navigationTitle("Markdown")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: markdown) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}
