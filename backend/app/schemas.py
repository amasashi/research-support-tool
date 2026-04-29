from typing import Optional

from pydantic import BaseModel, Field


class PaperInput(BaseModel):
    title: str = Field(default="Untitled paper", max_length=200)
    text: str = Field(min_length=1)


class TranslateResponse(BaseModel):
    document_id: int
    translated_text: str
    summary: str


class UrlImportRequest(BaseModel):
    url: str = Field(min_length=8)
    include_appendix: bool = False
    include_references: bool = False


class UrlImportResponse(BaseModel):
    title: str
    text: str
    source_url: str
    content_type: str
    character_count: int


class QuestionRequest(BaseModel):
    document_id: Optional[int] = None
    title: str = "Untitled paper"
    source_text: str
    translated_text: str = ""
    question: str = Field(min_length=1)
    selected_text: str = ""


class QuestionResponse(BaseModel):
    answer: str


class ImageRequest(BaseModel):
    document_id: Optional[int] = None
    title: str = "Untitled paper"
    source_text: str
    translated_text: str = ""
    focus: str = ""


class ImageResponse(BaseModel):
    image_url: str
    prompt: str


class MarkdownRequest(BaseModel):
    title: str
    source_text: str
    translated_text: str
    summary: str = ""
    notes: str = ""


class MarkdownResponse(BaseModel):
    markdown: str
