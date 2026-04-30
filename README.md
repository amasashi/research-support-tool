# Research Support Tool

英語論文を日本語で読みやすくするための、自分専用 iPhone アプリです。

現在の構成は **SwiftUI の iPhone アプリ単体** です。Next.js フロントエンドと FastAPI バックエンドは廃止し、翻訳・質問・読み方テンプレート生成は iPhone アプリから OpenAI API を直接呼び出します。

## 機能

- セクション単位の英語論文テキスト翻訳
- 論文 URL からの本文取り込み（PDF / HTML）
- 論文全体 / 選択セクションへのチャット形式質問
- 論文カード一覧
- セクション単位の原文・日本語訳・メモ表示
- 段落単位表示（原文 + 日本語訳）
- 段落ごとのメモ
- 読み方テンプレート生成
- Markdown 出力
- 複数論文比較（簡易版）
- 論文キャラ属性表示
  - 分野
  - 難易度
  - 性質
  - 進化状態
  - 理解度スコア

URL 取り込みでは、既定で引用文献と Appendix を除外します。画面上のオプションで Appendix と引用文献を含められます。

論文カード、メモ、段落メモ、読み方テンプレート、論文キャラ属性はアプリ内のローカル JSON に保存します。OpenAI API Key は iOS Keychain に保存します。

## このアプリでできること

このアプリは、英語論文を iPhone 上で読み、理解し、あとで研究メモとして再利用するための作業場です。

### 論文を取り込む

- 論文 URL を入力して PDF / HTML から本文を取り込めます。
- arXiv の `/abs/` URL は PDF URL に変換して取得します。
- Appendix / References を含めるかどうかを選べます。
- 取り込んだ論文は論文カードとしてローカルに保存されます。
- 本文はアプリ内でセクション分割され、論文詳細画面のセレクトボックスから読むセクションを選べます。

### 日本語で読む

- 原文をセクションごとに選んで OpenAI API で日本語に翻訳できます。
- 選択セクションの原文・日本語訳・要約を論文詳細画面で確認できます。
- 原文と日本語訳を段落単位で並べて読めます。
- 長い論文でも、翻訳時に全文を一度に送る設計ではありません。
- 原文・翻訳結果・回答は MathJax 対応ビューで表示し、LaTeX 数式、表、コード、Markdown 風テキストを読みやすく表示します。

### 質問して理解する

- 論文全体に対してチャット形式で質問できます。
- 選択中のセクションに対してチャット形式で質問できます。
- 段落を対象にして、その箇所だけに質問できます。
- 回答は日本語で表示されます。
- 論文全体への質問では、全文ではなく、要約・読み方テンプレート・質問に関連しそうな段落を優先して OpenAI API に送ります。
- セクション質問では、選択セクションの原文と翻訳を中心に OpenAI API に送ります。

### メモを残す

- 論文全体のメモを書けます。
- セクションごとにメモを書けます。
- 段落ごとにメモを書けます。
- メモはローカル JSON に保存されます。

### 読み方テンプレートを作る

ワンタップで以下の観点を Markdown 形式で整理できます。

- 論文の目的
- 解決課題
- 提案手法
- 新規性
- 実験設定
- 結果
- 限界
- 自分の研究への応用

長い論文では本文をチャンクに分け、各チャンクの要約を作ってから統合します。

### 研究メモとして出力する

- 翻訳、要約、全体メモ、段落メモ、読み方テンプレートを Markdown として出力できます。
- 生成した Markdown は共有メニューから他のアプリへ渡せます。

### 複数論文を比較する

- 保存済み論文を複数選択できます。
- 手法・新規性、結果・限界、メモを簡易テーブルで比較できます。

### 論文コレクションを眺める

- 各論文に分野、難易度、性質、進化状態、理解度スコアが付きます。
- 翻訳、メモ、読み方テンプレート作成などの行動に応じて進化状態が変わります。
- 論文を「どこまで読んだか」「どれくらい整理したか」を軽く可視化できます。

## 実装済みの主要ワークフロー

1. Settings で OpenAI API Key とモデル名を保存する。
2. Home から論文 URL を追加する。
3. PDF / HTML から本文を抽出し、セクション単位で保存する。
4. PaperDetail で読むセクションを選ぶ。
5. 選択セクションの原文を MathJax 対応ビューで読む。
6. 選択セクションだけを翻訳する。
7. 論文全体または選択セクションにチャット形式で質問する。
8. 全体メモ、セクションメモ、段落メモを書く。
9. 読み方テンプレートを生成する。
10. Markdown として研究メモを出力する。

## 改善の余地がある機能

現在の実装は、自分専用で動かすための軽量な SwiftUI アプリとして作っています。以下は今後改善余地があります。

- **PDF / HTML 本文抽出**
  - iOS 標準の `PDFKit` と簡易 HTML タグ除去で実装しています。
  - 論文 PDF の段組み、ヘッダー/フッター、脚注、数式、表は崩れる場合があります。
  - 将来的には PDF 解析品質の改善、手動本文貼り付け、ファイルインポート対応が有効です。

- **セクション分割**
  - 見出し文字列のルールベース検出です。
  - 抽出テキストの改行状態によってはセクションがうまく分かれない場合があります。
  - 将来的にはユーザーによるセクション編集、再分割、統合機能があると便利です。

- **トークン制御**
  - 文字数ベースで OpenAI API に送る量を制限しています。
  - 厳密な token 数計算ではありません。
  - 将来的には tokenizer ベースの見積もり、モデルごとの上限管理、コスト表示を追加できます。

- **数式表示**
  - 翻訳結果や原文の表示は `WKWebView + MathJax CDN` で対応しています。
  - ネットワークがない環境では MathJax の読み込みができない場合があります。
  - 完全オフライン対応には MathJax の同梱が必要です。

- **チャット履歴**
  - 論文全体 / セクション別の質問回答をローカル JSON に保存します。
  - まだ検索、削除、並び替え、エクスポート粒度の調整はありません。

- **ローカル保存**
  - 論文データはローカル JSON 保存です。
  - データ量が増えた場合は SwiftData / SQLite への移行を検討できます。

- **OpenAI API Key 管理**
  - 自分専用利用として Keychain に保存しています。
  - 他人に配布する場合や App Store 公開する場合は、API Key 保護のためサーバー経由構成などへ再設計が必要です。

## 使い方

Xcode で以下のプロジェクトを開きます。

```text
ios/ResearchSupportiOS/ResearchSupportiOS.xcodeproj
```

アプリ起動後、Settings で OpenAI API Key を入力してください。

既定モデルは以下です。

```text
gpt-4.1-mini
```

必要に応じて Settings からモデル名を変更できます。

## ローカル開発

このリポジトリには iPhone アプリのコードだけを残しています。サーバー起動は不要です。

```text
ios/ResearchSupportiOS/
  ResearchSupportiOS.xcodeproj
  ResearchSupportiOS/
    Models/
    Services/
    Utilities/
    ViewModels/
    Views/
```

## 注意

この構成は自分専用利用を前提にしています。

- OpenAI API Key はソースコードに直書きしないでください。
- API Key は Settings から入力し、Keychain に保存します。
- App Store 公開や他人への配布をする場合、この構成は API Key 保護の観点で再設計が必要です。
- PDF / HTML 本文抽出は Swift 側の簡易実装です。論文 PDF の段組みや数式によっては抽出が崩れる場合があります。
- OpenAI API に送る本文量は制限しています。翻訳は選択セクション単位、質問は関連段落中心、テンプレート生成はチャンク要約ベースです。
- iPhone 上には取り込んだ全文を保存しますが、LLM に毎回全文を送るわけではありません。

## 現在の構成

```text
ios/ResearchSupportiOS/
  SwiftUI iPhone app
  OpenAI direct API client
  PDFKit based PDF text extraction
  URLSession based HTML/PDF import
  Local JSON library storage
  Keychain based API key storage
```

## SwiftUI 側の主なファイル

- `Models/Paper.swift`: 論文、段落、質問履歴、論文キャラ属性
- `Services/APIClient.swift`: OpenAI API 直接呼び出し
- `Services/PaperService.swift`: URL / PDF / HTML 取り込み
- `Services/TranslationService.swift`: 翻訳
- `Services/QuestionService.swift`: 質問、段落質問、読み方テンプレート生成
- `Services/MarkdownService.swift`: Markdown 生成
- `Services/LocalLibraryService.swift`: ローカル JSON 保存
- `Services/PaperCharacterService.swift`: 論文キャラ属性と進化状態のルールベース判定
- `Utilities/KeychainService.swift`: OpenAI API Key 保存
- `Views/HomeView.swift`: 論文カード一覧
- `Views/ImportPaperView.swift`: URL 取り込み
- `Views/PaperDetailView.swift`: 原文、翻訳、段落、テンプレート、メモ、Q&A
- `Views/ComparePapersView.swift`: 複数論文比較

## 削除済み

- `frontend/`: Next.js Web フロントエンド
- `backend/`: FastAPI API サーバー
- `docker-compose.yml`: Web/API サーバー起動用 Docker Compose
