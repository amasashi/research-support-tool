"use client";

import {
  BookOpen,
  Clipboard,
  Download,
  FileText,
  Globe2,
  Image as ImageIcon,
  Languages,
  MessageSquareText,
  MousePointer2,
  PlusCircle,
  Send,
} from "lucide-react";
import Image from "next/image";
import { useMemo, useState } from "react";
import { api } from "@/lib/api";

type QaItem = {
  question: string;
  answer: string;
  scope: "全体" | "選択";
};

const sampleText =
  "論文URLから本文を取り込むか、英語論文の abstract / introduction / full text をここに貼り付けてください。";

const buttonBase =
  "inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-transparent px-3.5 font-bold disabled:cursor-not-allowed disabled:opacity-55";
const primaryButton = `${buttonBase} bg-paper-green text-white`;
const secondaryButton = `${buttonBase} border-paper-line bg-white text-paper-ink`;
const blueButton = `${buttonBase} bg-paper-blue text-white`;
const panelClass = "min-w-0 overflow-hidden rounded-lg border border-paper-line bg-paper-panel";
const panelHeaderClass =
  "flex min-h-[58px] items-center justify-between gap-3 border-b border-paper-line px-3.5 py-3 max-sm:items-start max-sm:flex-col";
const panelTitleClass = "flex items-center gap-2 font-extrabold";
const panelBodyClass = "grid gap-3 p-3.5";
const fieldClass = "grid gap-1.5";
const labelClass = "text-[13px] font-bold text-paper-muted";
const inputClass =
  "w-full rounded-lg border border-paper-line bg-[#fbfcfb] px-3 py-2.5 text-paper-ink outline-none";
const textareaClass = `${inputClass} min-h-[180px] resize-y leading-relaxed`;

export default function Home() {
  const [title, setTitle] = useState("Untitled paper");
  const [paperUrl, setPaperUrl] = useState("");
  const [includeAppendix, setIncludeAppendix] = useState(false);
  const [includeReferences, setIncludeReferences] = useState(false);
  const [sourceText, setSourceText] = useState(sampleText);
  const [translatedText, setTranslatedText] = useState("");
  const [summary, setSummary] = useState("");
  const [documentId, setDocumentId] = useState<number | null>(null);
  const [question, setQuestion] = useState("");
  const [selectedText, setSelectedText] = useState("");
  const [notes, setNotes] = useState("");
  const [qaItems, setQaItems] = useState<QaItem[]>([]);
  const [imageUrl, setImageUrl] = useState("");
  const [markdown, setMarkdown] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState("");

  const status = useMemo(() => {
    if (busy) return "処理中";
    if (translatedText) return "翻訳済み";
    if (sourceText && sourceText !== sampleText) return "本文準備済み";
    return "準備完了";
  }, [busy, sourceText, translatedText]);

  const sourceStats = useMemo(() => {
    const words = sourceText.trim() ? sourceText.trim().split(/\s+/).length : 0;
    return `${sourceText.length.toLocaleString()} chars / ${words.toLocaleString()} words`;
  }, [sourceText]);

  async function run<T>(label: string, task: () => Promise<T>) {
    setBusy(label);
    setError("");
    try {
      return await task();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unexpected error");
      return null;
    } finally {
      setBusy(null);
    }
  }

  function captureSelection() {
    const selection = window.getSelection()?.toString().trim() ?? "";
    setSelectedText(selection);
  }

  async function translate() {
    const result = await run("translate", () => api.translate({ title, text: sourceText }));
    if (!result) return;
    setTranslatedText(result.translated_text);
    setSummary(result.summary);
    setDocumentId(result.document_id);
  }

  async function importFromUrl() {
    const result = await run("import-url", () =>
      api.importUrl({
        url: paperUrl,
        include_appendix: includeAppendix,
        include_references: includeReferences,
      }),
    );
    if (!result) return;
    setTitle(result.title);
    setSourceText(result.text);
    setTranslatedText("");
    setSummary("");
    setDocumentId(null);
    setSelectedText("");
    setQaItems([]);
    setMarkdown("");
  }

  async function ask(scope: "全体" | "選択") {
    const textForSelection = scope === "選択" ? selectedText : "";
    const result = await run("question", () =>
      api.question({
        document_id: documentId,
        title,
        source_text: sourceText,
        translated_text: translatedText,
        question,
        selected_text: textForSelection,
      }),
    );
    if (!result) return;
    setQaItems([{ question, answer: result.answer, scope }, ...qaItems]);
    setQuestion("");
  }

  async function createImage() {
    const result = await run("image", () =>
      api.image({
        document_id: documentId,
        title,
        source_text: sourceText,
        translated_text: translatedText,
        focus: selectedText || question,
      }),
    );
    if (!result) return;
    setImageUrl(result.image_url);
  }

  async function exportMarkdown() {
    const result = await run("markdown", () =>
      api.markdown({
        title,
        source_text: sourceText,
        translated_text: translatedText,
        summary,
        notes,
      }),
    );
    if (!result) return;
    setMarkdown(result.markdown);
  }

  return (
    <main className="min-h-screen bg-paper-bg text-paper-ink">
      <header className="flex items-center justify-between gap-5 border-b border-paper-line px-7 py-[18px] max-sm:items-start max-sm:flex-col max-sm:p-4">
        <div>
          <h1 className="m-0 text-[22px] leading-tight font-extrabold">Research Support Tool</h1>
          <p className="mt-1 text-paper-muted">英語論文を日本語で読み、質問し、図解し、Markdown に残す作業台</p>
        </div>
        <div className="whitespace-nowrap rounded-full bg-paper-softGreen px-3 py-2 text-[13px] font-bold text-paper-greenStrong">
          {status}
        </div>
      </header>

      <section className="grid grid-cols-[minmax(360px,0.95fr)_minmax(420px,1.2fr)_minmax(330px,0.85fr)] gap-[18px] px-7 pb-7 pt-5 max-[1180px]:grid-cols-1 max-sm:p-3.5">
        <aside className={panelClass}>
          <div className={panelHeaderClass}>
            <div className={panelTitleClass}>
              <FileText size={19} />
              原文
            </div>
            <button className={primaryButton} disabled={busy !== null || !sourceText.trim()} onClick={translate}>
              <Languages size={18} />
              翻訳
            </button>
          </div>
          <div className={panelBodyClass}>
            <div className="rounded-lg border border-paper-line bg-paper-softGreen/55 p-3">
              <div className="mb-2 flex items-center gap-2 text-sm font-extrabold text-paper-greenStrong">
                <Globe2 size={17} />
                URLから本文取得
              </div>
              <div className="flex gap-2 max-sm:flex-col">
                <input
                  className={inputClass}
                  inputMode="url"
                  placeholder="https://arxiv.org/abs/... または PDF URL"
                  value={paperUrl}
                  onChange={(event) => setPaperUrl(event.target.value)}
                />
                <button className={primaryButton} disabled={busy !== null || !paperUrl.trim()} onClick={importFromUrl}>
                  <PlusCircle size={18} />
                  取得
                </button>
              </div>
              <div className="mt-2 grid grid-cols-2 gap-2 text-[13px] text-paper-ink max-sm:grid-cols-1">
                <label className="flex items-center gap-2 rounded-md border border-paper-line bg-white px-2.5 py-2 font-bold">
                  <input
                    type="checkbox"
                    checked={includeAppendix}
                    onChange={(event) => setIncludeAppendix(event.target.checked)}
                  />
                  Appendixも含める
                </label>
                <label className="flex items-center gap-2 rounded-md border border-paper-line bg-white px-2.5 py-2 font-bold">
                  <input
                    type="checkbox"
                    checked={includeReferences}
                    onChange={(event) => setIncludeReferences(event.target.checked)}
                  />
                  引用文献も含める
                </label>
              </div>
            </div>
            <div className={fieldClass}>
              <div className="flex items-center justify-between gap-3">
                <label className={labelClass} htmlFor="title">タイトル</label>
                <span className="text-xs font-bold text-paper-muted">{sourceStats}</span>
              </div>
              <input id="title" className={inputClass} value={title} onChange={(event) => setTitle(event.target.value)} />
            </div>
            <div className={fieldClass}>
              <div className="flex items-center justify-between gap-3">
                <label className={labelClass} htmlFor="source">英語論文テキスト</label>
                <span className="text-xs font-bold text-paper-muted">
                  {includeAppendix ? "Appendix含む" : "Appendix除外"} / {includeReferences ? "引用含む" : "引用除外"}
                </span>
              </div>
              <textarea
                id="source"
                className={`${textareaClass} min-h-[520px] max-[1180px]:min-h-[360px]`}
                value={sourceText}
                onChange={(event) => setSourceText(event.target.value)}
                onMouseUp={captureSelection}
                onKeyUp={captureSelection}
              />
            </div>
          </div>
        </aside>

        <section className={panelClass}>
          <div className={panelHeaderClass}>
            <div className={panelTitleClass}>
              <BookOpen size={19} />
              日本語リーディング
            </div>
            <button className={secondaryButton} onClick={captureSelection}>
              <MousePointer2 size={18} />
              選択取得
            </button>
          </div>
          <div className={panelBodyClass}>
            {summary ? (
              <div className="whitespace-pre-wrap rounded-lg border-l-4 border-paper-amber bg-paper-softAmber p-3 leading-7">
                {summary}
              </div>
            ) : null}
            <div
              className="min-h-[520px] overflow-auto whitespace-pre-wrap rounded-lg border border-paper-line bg-[#fbfcfb] p-3.5 leading-8 max-[1180px]:min-h-[360px]"
              onMouseUp={captureSelection}
            >
              {translatedText || "翻訳結果がここに表示されます。"}
            </div>
            {selectedText ? (
              <div className="whitespace-pre-wrap rounded-lg border-l-4 border-paper-amber bg-paper-softAmber p-3 leading-7">
                <b>選択中</b>
                <br />
                {selectedText}
              </div>
            ) : null}
          </div>
        </section>

        <aside className={panelClass}>
          <div className={panelHeaderClass}>
            <div className={panelTitleClass}>
              <MessageSquareText size={19} />
              調査アクション
            </div>
          </div>
          <div className={panelBodyClass}>
            {error ? (
              <div className="rounded-lg border border-[#f0b8b1] bg-[#fff1f0] px-3 py-2.5 leading-relaxed text-[#8a2d22]">
                {error}
              </div>
            ) : null}
            <div className={fieldClass}>
              <label className={labelClass} htmlFor="question">質問</label>
              <textarea
                id="question"
                className={textareaClass}
                value={question}
                onChange={(event) => setQuestion(event.target.value)}
                placeholder="例: この手法の新規性は何ですか？"
              />
            </div>
            <div className="flex flex-wrap gap-2">
              <button className={primaryButton} disabled={busy !== null || !question.trim()} onClick={() => ask("全体")}>
                <Send size={18} />
                全体質問
              </button>
              <button
                className={secondaryButton}
                disabled={busy !== null || !question.trim() || !selectedText}
                onClick={() => ask("選択")}
              >
                <Clipboard size={18} />
                選択質問
              </button>
              <button className={blueButton} disabled={busy !== null} onClick={createImage}>
                <ImageIcon size={18} />
                図生成
              </button>
            </div>

            <div className={fieldClass}>
              <label className={labelClass} htmlFor="notes">Markdown 用メモ</label>
              <textarea id="notes" className={textareaClass} value={notes} onChange={(event) => setNotes(event.target.value)} />
            </div>
            <button className={secondaryButton} disabled={busy !== null} onClick={exportMarkdown}>
              <Download size={18} />
              Markdown 出力
            </button>

            <div className="flex min-h-[240px] items-center justify-center overflow-hidden rounded-lg border border-[#c9d8ec] bg-paper-softBlue">
              {imageUrl ? (
                <Image
                  src={imageUrl}
                  alt="Generated paper diagram"
                  width={640}
                  height={640}
                  unoptimized
                  className="block h-auto max-w-full"
                />
              ) : (
                <div className="p-3.5 text-center leading-7 text-paper-muted">図解プレビュー</div>
              )}
            </div>

            <div className="grid gap-2.5">
              {qaItems.map((item, index) => (
                <div className="rounded-lg border border-paper-line bg-[#fbfcfb] p-2.5" key={`${item.scope}-${index}`}>
                  <b className="mb-1.5 block">{item.scope}: {item.question}</b>
                  <div>{item.answer}</div>
                </div>
              ))}
            </div>

            {markdown ? (
              <div className={fieldClass}>
                <label className={labelClass} htmlFor="markdown">Markdown</label>
                <textarea id="markdown" className={textareaClass} value={markdown} readOnly />
              </div>
            ) : null}
          </div>
        </aside>
      </section>
    </main>
  );
}
