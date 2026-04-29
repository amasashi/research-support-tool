# Research Support Tool

英語論文を日本語で読みやすくするための Next.js + FastAPI プロトタイプです。

## 機能

- 英語論文テキストの日本語翻訳
- 論文 URL からの本文取り込み（PDF / HTML）
- 論文全体への質問
- 選択箇所への質問
- 論文内容に基づくイメージ図生成
- 翻訳結果とメモの Markdown 出力
- SQLite による文書と操作履歴の保存

URL 取り込みでは、既定で引用文献と Appendix を除外します。画面上のオプションで Appendix と引用文献を含められます。

## 起動方法（Docker Compose）

```bash
cp backend/.env.example backend/.env
docker compose up --build
```

ブラウザで `http://localhost:3000` を開きます。Backend は `http://localhost:8000` で起動します。

`OPENAI_API_KEY` が未設定の場合、開発用のフォールバック応答で動作します。

## ローカル開発

### Backend

```bash
source venv/bin/activate
pip install -r backend/requirements.txt
cp backend/.env.example backend/.env
uvicorn backend.app.main:app --reload --port 8000
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

ブラウザで `http://localhost:3000` を開きます。

フロントエンドのスタイルは Tailwind CSS で管理しています。

## 環境変数

- `OPENAI_API_KEY`: OpenAI API key
- `OPENAI_TEXT_MODEL`: 翻訳・質問用モデル。既定値は `gpt-4.1-mini`
- `OPENAI_IMAGE_MODEL`: 画像生成用モデル。既定値は `gpt-image-1`
- `DATABASE_URL`: SQLite DB のパス。既定値は `sqlite:///./research_support.db`
