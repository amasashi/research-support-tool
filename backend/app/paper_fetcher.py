import re
from io import BytesIO
from typing import List, Tuple
from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup
from pypdf import PdfReader


class PaperFetchError(RuntimeError):
    pass


SECTION_RE = re.compile(
    r"^\s*(?:\d+(?:\.\d+)*\.?\s+)?(abstract|introduction|background|methods?|methodology|experiments?|"
    r"results?|discussion|conclusion|limitations?|appendix|appendices|acknowledg(?:e)?ments?|references|"
    r"bibliography)\s*$",
    re.IGNORECASE,
)
APPENDIX_RE = re.compile(r"^\s*(?:\d+(?:\.\d+)*\.?\s+)?(?:appendix|appendices)\b", re.IGNORECASE)
REFERENCES_RE = re.compile(r"^\s*(?:\d+(?:\.\d+)*\.?\s+)?(?:references|bibliography)\s*$", re.IGNORECASE)


def fetch_paper_text(url: str, include_appendix: bool, include_references: bool) -> Tuple[str, str, str]:
    normalized_url = _normalize_url(url)
    response = _download(normalized_url)
    content_type = response.headers.get("content-type", "").split(";")[0].strip().lower()

    if _is_pdf(normalized_url, content_type, response.content):
        title, text = _extract_pdf(response.content)
        content_type = "application/pdf"
    else:
        title, text = _extract_html(response.text, normalized_url)
        content_type = content_type or "text/html"

    text = _clean_text(text)
    text = _drop_permission_preamble(text, title)
    text = _filter_sections(text, include_appendix, include_references)
    if len(text) < 300:
        raise PaperFetchError("本文を十分に抽出できませんでした。PDF の直接 URL で再試行してください。")

    return title or _title_from_url(normalized_url), text, content_type


def _normalize_url(url: str) -> str:
    parsed = urlparse(url.strip())
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise PaperFetchError("http または https の論文 URL を入力してください。")

    if parsed.netloc == "arxiv.org" and parsed.path.startswith("/abs/"):
        paper_id = parsed.path.replace("/abs/", "", 1)
        return f"https://arxiv.org/pdf/{paper_id}"

    return url.strip()


def _download(url: str) -> httpx.Response:
    try:
        with httpx.Client(follow_redirects=True, timeout=30.0) as client:
            response = client.get(
                url,
                headers={
                    "User-Agent": "ResearchSupportTool/0.1 (+https://localhost)",
                    "Accept": "application/pdf,text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
                },
            )
    except httpx.HTTPError as exc:
        raise PaperFetchError(f"URL の取得に失敗しました: {exc}") from exc

    if response.status_code >= 400:
        raise PaperFetchError(f"URL の取得に失敗しました: HTTP {response.status_code}")
    return response


def _is_pdf(url: str, content_type: str, content: bytes) -> bool:
    return content_type == "application/pdf" or urlparse(url).path.lower().endswith(".pdf") or content.startswith(b"%PDF")


def _extract_pdf(content: bytes) -> Tuple[str, str]:
    try:
        reader = PdfReader(BytesIO(content))
    except Exception as exc:
        raise PaperFetchError("PDF を読み込めませんでした。") from exc

    page_texts: List[str] = []
    for page in reader.pages:
        page_texts.append(page.extract_text() or "")

    metadata = reader.metadata
    title = ""
    if metadata and metadata.title:
        title = str(metadata.title).strip()
    text = "\n\n".join(page_texts)
    guessed_title = _guess_title(text)
    if not title or _looks_like_bad_title(title):
        title = guessed_title
    return title, text


def _extract_html(html: str, url: str) -> Tuple[str, str]:
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "noscript", "svg", "nav", "footer", "header", "aside"]):
        tag.decompose()

    title = ""
    if soup.title and soup.title.string:
        title = soup.title.string.strip()

    main = soup.find("article") or soup.find("main") or soup.body or soup
    chunks: List[str] = []
    for element in main.find_all(["h1", "h2", "h3", "p", "li"], recursive=True):
        text = element.get_text(" ", strip=True)
        if text:
            chunks.append(text)

    if not chunks:
        chunks = [main.get_text("\n", strip=True)]

    return title or _title_from_url(url), "\n\n".join(chunks)


def _clean_text(text: str) -> str:
    text = text.replace("\x00", " ")
    text = re.sub(r"-\n(?=[a-z])", "", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    lines = [line.strip() for line in text.splitlines()]
    return "\n".join(line for line in lines if line)


def _drop_permission_preamble(text: str, title: str) -> str:
    if not title:
        return text
    first_chunk = text[:800].lower()
    if not any(token in first_chunk for token in ("permission", "attribution", "reproduce", "journalistic", "scholarly")):
        return text

    index = text.find(title)
    if 0 < index < 800:
        return text[index:].strip()
    return text


def _filter_sections(text: str, include_appendix: bool, include_references: bool) -> str:
    lines = text.splitlines()
    kept: List[str] = []
    in_appendix = False
    in_references = False

    for line in lines:
        if REFERENCES_RE.match(line):
            in_references = True
            if include_references:
                kept.append(line)
            continue

        if APPENDIX_RE.match(line):
            in_appendix = True
            in_references = False
            if include_appendix:
                kept.append(line)
            continue

        if SECTION_RE.match(line) and not REFERENCES_RE.match(line) and not APPENDIX_RE.match(line):
            in_references = False
            if not include_appendix:
                in_appendix = False

        if in_references and not include_references:
            continue
        if in_appendix and not include_appendix:
            continue
        kept.append(line)

    return "\n".join(kept).strip()


def _guess_title(text: str) -> str:
    candidates: List[str] = []
    for line in text.splitlines()[:80]:
        line = line.strip()
        if not 8 <= len(line) <= 180:
            continue
        lowered = line.lower()
        if lowered.startswith(("abstract", "arxiv", "proceedings", "conference")):
            continue
        if any(token in lowered for token in ("permission", "attribution", "reproduce", "journalistic", "scholarly")):
            continue
        if "@" in line or re.search(r"\b(?:google|university|department|institute|school)\b", lowered):
            continue
        if re.search(r"\d{4}", line):
            continue
        candidates.append(line)

    for line in candidates:
        if len(line.split()) >= 3 and not line.endswith("."):
            return line

    if candidates:
        return candidates[0]
    return "Imported paper"


def _looks_like_bad_title(title: str) -> bool:
    lowered = title.lower()
    return any(token in lowered for token in ("permission", "attribution", "reproduce", "journalistic", "scholarly"))


def _title_from_url(url: str) -> str:
    path = urlparse(url).path.rstrip("/").split("/")[-1]
    return path.replace("-", " ").replace("_", " ") or "Imported paper"
