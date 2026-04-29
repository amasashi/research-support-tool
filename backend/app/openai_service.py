import base64
from typing import Optional

from openai import OpenAI

from .config import settings


def _client() -> Optional[OpenAI]:
    if not settings.openai_api_key:
        return None
    return OpenAI(api_key=settings.openai_api_key)


def _trim(text: str, limit: int = 18000) -> str:
    return text[:limit]


def translate_paper(title: str, text: str) -> tuple[str, str]:
    client = _client()
    if client is None:
        excerpt = text[:500]
        return (
            "【開発用翻訳】OPENAI_API_KEY を設定すると、この欄に自然な日本語訳が表示されます。\n\n"
            f"対象論文: {title}\n\n原文抜粋:\n{excerpt}",
            "OPENAI_API_KEY 未設定のため、要約は開発用プレースホルダーです。",
        )

    response = client.chat.completions.create(
        model=settings.openai_text_model,
        messages=[
            {
                "role": "system",
                "content": (
                    "You translate English research papers into readable Japanese for early-career "
                    "researchers. Preserve technical terms, equations, citations, and section structure. "
                    "Return exactly two Markdown sections: '## 日本語訳' and '## 要約'."
                ),
            },
            {
                "role": "user",
                "content": f"Title: {title}\n\nPaper text:\n{_trim(text)}",
            },
        ],
    )
    output = response.choices[0].message.content or ""
    summary_marker = "## 要約"
    translation_marker = "## 日本語訳"
    if summary_marker in output:
        translated, summary = output.split(summary_marker, 1)
        translated = translated.replace(translation_marker, "", 1).strip()
        return translated, summary.strip()
    return output.strip(), ""


def answer_question(
    title: str,
    source_text: str,
    translated_text: str,
    question: str,
    selected_text: str = "",
) -> str:
    client = _client()
    if client is None:
        scope = "選択箇所" if selected_text else "論文全体"
        return f"【開発用回答】{scope}への質問「{question}」に回答するには OPENAI_API_KEY を設定してください。"

    selection = f"\n\nSelected passage:\n{selected_text}" if selected_text else ""
    response = client.chat.completions.create(
        model=settings.openai_text_model,
        messages=[
            {
                "role": "system",
                "content": (
                    "Answer in Japanese for a junior researcher. Be precise, cite the relevant part "
                    "of the provided paper text when useful, and state uncertainty clearly."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"Title: {title}\n\nSource text:\n{_trim(source_text)}\n\n"
                    f"Japanese translation:\n{_trim(translated_text)}{selection}\n\nQuestion: {question}"
                ),
            },
        ],
    )
    return (response.choices[0].message.content or "").strip()


def generate_diagram(title: str, source_text: str, translated_text: str, focus: str = "") -> tuple[str, str]:
    prompt = (
        "Create a clean educational concept diagram for a Japanese research reading tool. "
        "Visualize the core method, data flow, and key findings from this paper. "
        "Use simple labeled blocks, arrows, and neutral colors. "
        f"Title: {title}. Focus: {focus or 'paper overview'}. "
        f"Content: {_trim(translated_text or source_text, 2000)}"
    )

    client = _client()
    if client is None:
        svg = (
            "<svg xmlns='http://www.w3.org/2000/svg' width='960' height='540'>"
            "<rect width='100%' height='100%' fill='#f7faf8'/>"
            "<text x='48' y='92' font-size='34' font-family='sans-serif' fill='#18332f'>"
            "開発用イメージ図</text>"
            "<rect x='80' y='180' width='220' height='120' rx='8' fill='#d7eee7'/>"
            "<rect x='370' y='180' width='220' height='120' rx='8' fill='#f7dfb8'/>"
            "<rect x='660' y='180' width='220' height='120' rx='8' fill='#d9e4f5'/>"
            "<text x='128' y='246' font-size='24' font-family='sans-serif'>Paper</text>"
            "<text x='418' y='246' font-size='24' font-family='sans-serif'>Method</text>"
            "<text x='708' y='246' font-size='24' font-family='sans-serif'>Insight</text>"
            "<path d='M310 240 H360 M600 240 H650' stroke='#18332f' stroke-width='5'/>"
            "</svg>"
        )
        encoded = base64.b64encode(svg.encode("utf-8")).decode("utf-8")
        return f"data:image/svg+xml;base64,{encoded}", prompt

    image = client.images.generate(
        model=settings.openai_image_model,
        prompt=prompt,
        size="1024x1024",
    )
    item = image.data[0]
    if item.url:
        return item.url, prompt
    return f"data:image/png;base64,{item.b64_json}", prompt
