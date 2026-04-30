from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import get_connection, init_db
from .openai_service import answer_question, generate_diagram, translate_paper
from .paper_fetcher import PaperFetchError, fetch_paper_text
from .schemas import (
    ImageRequest,
    ImageResponse,
    MarkdownRequest,
    MarkdownResponse,
    PaperInput,
    QuestionRequest,
    QuestionResponse,
    TranslateResponse,
    UrlImportRequest,
    UrlImportResponse,
)

app = FastAPI(title="Research Support Tool API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in settings.cors_origins.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/translate", response_model=TranslateResponse)
def translate(payload: PaperInput) -> TranslateResponse:
    translated_text, summary = translate_paper(payload.title, payload.text)
    with get_connection() as conn:
        cursor = conn.execute(
            """
            INSERT INTO documents (title, source_text, translated_text, summary)
            VALUES (?, ?, ?, ?)
            """,
            (payload.title, payload.text, translated_text, summary),
        )
        document_id = int(cursor.lastrowid)
        conn.execute(
            """
            INSERT INTO interactions (document_id, kind, prompt, response)
            VALUES (?, 'translate', ?, ?)
            """,
            (document_id, payload.text[:1000], translated_text),
        )
    return TranslateResponse(document_id=document_id, translated_text=translated_text, summary=summary)


@app.post("/import-url", response_model=UrlImportResponse)
def import_url(payload: UrlImportRequest) -> UrlImportResponse:
    try:
        title, text, content_type = fetch_paper_text(
            payload.url,
            payload.include_appendix,
            payload.include_references,
        )
    except PaperFetchError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return UrlImportResponse(
        title=title,
        text=text,
        source_url=payload.url,
        content_type=content_type,
        character_count=len(text),
    )


@app.post("/question", response_model=QuestionResponse)
def question(payload: QuestionRequest) -> QuestionResponse:
    answer = answer_question(
        payload.title,
        payload.source_text,
        payload.translated_text,
        payload.question,
        payload.selected_text,
    )
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO interactions (document_id, kind, prompt, response)
            VALUES (?, ?, ?, ?)
            """,
            (
                payload.document_id,
                "selected_question" if payload.selected_text else "global_question",
                payload.question,
                answer,
            ),
        )
    return QuestionResponse(answer=answer)


@app.post("/image", response_model=ImageResponse)
def image(payload: ImageRequest) -> ImageResponse:
    image_url, prompt = generate_diagram(
        payload.title,
        payload.source_text,
        payload.translated_text,
        payload.focus,
    )
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO interactions (document_id, kind, prompt, response)
            VALUES (?, 'image', ?, ?)
            """,
            (payload.document_id, prompt, image_url),
        )
    return ImageResponse(image_url=image_url, prompt=prompt)


@app.post("/markdown", response_model=MarkdownResponse)
def markdown(payload: MarkdownRequest) -> MarkdownResponse:
    body = [
        f"# {payload.title}",
        "",
        "## 要約",
        payload.summary or "未作成",
        "",
        "## 日本語訳",
        payload.translated_text or "未翻訳",
        "",
        "## メモ",
        payload.notes or "なし",
        "",
        "## 原文",
        payload.source_text,
    ]
    return MarkdownResponse(markdown="\n".join(body))
