#!/usr/bin/env python3
"""Parse and clean the HSK workbook practice-sentence dump.

The dump (``HSK_Practice_Sentences.txt``) is grouped into ``HSK N`` sections, each a numbered list of
lines extracted from a workbook. Extraction is noisy: OCR artifacts, answer-key fragments, spliced
lines, and instructional boilerplate sit alongside genuine sentences. This module turns the dump into
a list of ``Sentence`` records and applies a **conservative structural filter** that removes the
obvious junk — the semantic judgement of "is this a usable, self-contained sentence?" is left to the
generation step, which can skip an input it can't work with.

``generate_sentences.py`` consumes ``clean_sentences``; ``test_hsk_sentences.py`` pins the filter.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass

# A CJK ideograph — the Basic block plus the common Extension A. Enough to score "how Chinese" a line
# is without pulling in rare-extension ranges the workbooks never use.
_HAN = r"㐀-䶿一-鿿"
_HAN_RE = re.compile(f"[{_HAN}]")

# Punctuation that may appear inside a kept sentence. Deliberately excludes: the ellipsis (…) and
# middle dot (·), which mark truncation or OCR garble here; and parentheses （）, which mark
# fill-in-the-blank exercises and inline pinyin glosses rather than real sentence content.
_ALLOWED_PUNCTUATION = "，。！？；：、“”‘’《》—「」『』"
_ALLOWED_RE = re.compile(f"[{_HAN}{re.escape(_ALLOWED_PUNCTUATION)}\\s]")
# Sentence-final marks; more than one *inside* a line signals two spliced sentences.
_TERMINALS = "。！？"

# A section header, e.g. "HSK 3  (1049 sentences)  ·  Standard Course 3 Workbook".
_SECTION_RE = re.compile(r"^HSK\s+(\d+)\b")
# A numbered entry, e.g. "17. 每个星期六，我都去打篮球。  (p.12)".
_ENTRY_RE = re.compile(r"^\s*\d+\.\s*(.*?)\s*$")
# A trailing page marker, with an optional book prefix: "(p.12)", "(4A p.3)", "(5上 p.9)".
_PAGE_RE = re.compile(r"\s*[（(]\s*(?:\S+\s+)?p\.?\s*(\d+)\s*[)）]\s*$", re.IGNORECASE)
# A leading dialogue speaker the workbooks prefix onto a turn, e.g. "男：", "女:". The sentence after
# it is worth keeping; the label is not.
_SPEAKER_RE = re.compile(r"^\s*[男女][：:]\s*")
# A comprehension-question prompt, e.g. "问：男的是什么意思？" — a question *about* an unseen passage,
# never a sentence to study. Dropped whole.
_QUESTION_RE = re.compile(r"^\s*[问答][：:]")

# Front-matter vocabulary: the per-book preface and acknowledgements (the early pages) are written
# about teaching the course, so these words flag copy that is guidance, not a sentence to study.
_BOILERPLATE_MARKERS = (
    "学习者",
    "练习",
    "教师",
    "教材",
    "本册",
    "本课",
    "偏旁",
    "题型",
    "教学",
    "课时",
    "编写",
    "感谢",
    "教程",
    "注释",
    "词语",
    "课文",
    "语料",
    "单元",
    "词汇",
)

# The shortest and longest a kept sentence may be, counted in Han characters. Below the floor is a
# fragment; above the ceiling is almost always two or more spliced lines.
_MIN_HAN = 4
_MAX_HAN = 30


@dataclass(frozen=True)
class Sentence:
    """One workbook line: its HSK level (1–6), the Han text, and the page it came from."""

    level: int
    hanzi: str
    page: int | None


def parse(text: str) -> list[Sentence]:
    """Every numbered entry in the dump, tagged with the HSK level of the section it sits under."""
    sentences: list[Sentence] = []
    level: int | None = None
    for line in text.splitlines():
        if section := _SECTION_RE.match(line):
            level = int(section.group(1))
            continue
        entry = _ENTRY_RE.match(line)
        if level is None or entry is None:
            continue
        body, page = _split_page(entry.group(1))
        sentences.append(Sentence(level=level, hanzi=body, page=page))
    return sentences


def clean_sentences(text: str) -> list[Sentence]:
    """The parsed entries reduced to clean, de-duplicated sentences, in first-seen order."""
    seen: set[str] = set()
    kept: list[Sentence] = []
    for sentence in parse(text):
        if _QUESTION_RE.match(sentence.hanzi):
            continue
        hanzi = _normalize(sentence.hanzi)
        if hanzi in seen or not is_clean(hanzi, page=sentence.page):
            continue
        seen.add(hanzi)
        kept.append(Sentence(level=sentence.level, hanzi=hanzi, page=sentence.page))
    return kept


def is_clean(hanzi: str, *, page: int | None = None) -> bool:
    """Whether `hanzi` is a genuine, self-contained sentence worth studying.

    Conservative by design: it rejects only the dump's structural junk — OCR artifacts (stray Latin
    letters, digits, ellipses), fragments, spliced multi-sentence runs, and the instructional
    preface — leaving anything that reads as one real sentence for the generator to judge and mirror.
    """
    return (
        _MIN_HAN <= _han_count(hanzi) <= _MAX_HAN
        and _only_allowed_characters(hanzi)
        and not _is_spliced(hanzi)
        and not _is_boilerplate(hanzi, page)
    )


def _split_page(entry: str) -> tuple[str, int | None]:
    """Separates the trailing `(p.N)` marker from an entry's text."""
    if page := _PAGE_RE.search(entry):
        return entry[: page.start()].rstrip(), int(page.group(1))
    return entry, None


def _normalize(hanzi: str) -> str:
    """NFC-normalized, with the speaker prefix and stray internal spaces the OCR inserted removed."""
    stripped = _SPEAKER_RE.sub("", unicodedata.normalize("NFC", hanzi)).strip()
    # The OCR sometimes spaces out Han runs ("爸爸 现在 不 能"); a space between two Han characters is
    # never meaningful, so close it up while leaving other whitespace be.
    return re.sub(f"(?<=[{_HAN}])\\s+(?=[{_HAN}])", "", stripped)


def _han_count(hanzi: str) -> int:
    return len(_HAN_RE.findall(hanzi))


def _only_allowed_characters(hanzi: str) -> bool:
    """Every character is Han, sentence punctuation, or space — no Latin, digits, or garble glyphs."""
    return all(_ALLOWED_RE.match(character) for character in hanzi)


def _is_spliced(hanzi: str) -> bool:
    """More than one sentence-final mark inside the line — two entries run together."""
    interior = hanzi.rstrip(_TERMINALS + "”’")
    return any(terminal in interior for terminal in _TERMINALS)


def _is_boilerplate(hanzi: str, page: int | None) -> bool:
    """Instructional preface copy: only the early pages, and only when it reads like guidance."""
    return (
        page is not None
        and page <= 6
        and any(marker in hanzi for marker in _BOILERPLATE_MARKERS)
    )
