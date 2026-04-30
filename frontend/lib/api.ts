const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8000";

async function postJson<TResponse, TPayload>(path: string, payload: TPayload): Promise<TResponse> {
  const response = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed: ${response.status}`);
  }

  return response.json() as Promise<TResponse>;
}

export type TranslateResponse = {
  document_id: number;
  translated_text: string;
  summary: string;
};

export type UrlImportResponse = {
  title: string;
  text: string;
  source_url: string;
  content_type: string;
  character_count: number;
};

export type QuestionResponse = {
  answer: string;
};

export type ImageResponse = {
  image_url: string;
  prompt: string;
};

export type MarkdownResponse = {
  markdown: string;
};

export const api = {
  importUrl: (payload: { url: string; include_appendix: boolean; include_references: boolean }) =>
    postJson<UrlImportResponse, typeof payload>("/import-url", payload),
  translate: (payload: { title: string; text: string }) =>
    postJson<TranslateResponse, typeof payload>("/translate", payload),
  question: (payload: {
    document_id: number | null;
    title: string;
    source_text: string;
    translated_text: string;
    question: string;
    selected_text?: string;
  }) => postJson<QuestionResponse, typeof payload>("/question", payload),
  image: (payload: {
    document_id: number | null;
    title: string;
    source_text: string;
    translated_text: string;
    focus: string;
  }) => postJson<ImageResponse, typeof payload>("/image", payload),
  markdown: (payload: {
    title: string;
    source_text: string;
    translated_text: string;
    summary: string;
    notes: string;
  }) => postJson<MarkdownResponse, typeof payload>("/markdown", payload),
};
