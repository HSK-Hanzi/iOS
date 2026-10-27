#!/usr/bin/env python3
"""Validate, level, and segment practice sentences against the HSK syllabi.

Each sentence is checked on its own terms — its segmentation spells out its Hanzi, its numbered pinyin
reads every character with a reading that character actually has — and then leveled once per HSK
standard: a sentence sits at the highest band, in that standard, of any word it uses. A word the
standard's syllabus doesn't list is broken into syllabus words where it can be; a sentence with a word
that can't be is left unleveled in that standard rather than guessed at.

``generate_sentences.py`` drives this module; ``test_sentence_library.py`` pins its rules.
"""

from __future__ import annotations

import hashlib
import re
from collections.abc import Iterable
from dataclasses import dataclass, field

from pinyin_keys import is_han

STANDARDS = ("old", "new", "newest")

# Marks a proper name in a generated segmentation: "*王/老师". Names are leveled as free.
NAME_MARK = "*"
WORD_SEPARATOR = "/"

# Characters that spell a number. A token made only of these is a numeral and is leveled as free.
NUMERAL_CHARACTERS = set("零〇一二三四五六七八九十百千万亿两几半")

# Readings a character takes before another syllable, which no per-character dictionary lists.
SANDHI_READINGS = {"一": {"yi2", "yi4"}, "不": {"bu2"}}

# How many Han characters a sentence at each band may run to, shortest to longest.
LENGTH_BOUNDS = {
    1: (2, 18),
    2: (2, 20),
    3: (2, 24),
    4: (2, 30),
    5: (2, 36),
    6: (2, 42),
    7: (2, 48),
}

_LATIN_OR_DIGIT = re.compile(r"[A-Za-z0-9０-９Ａ-Ｚａ-ｚ]")
_SYLLABLE = re.compile(r"^[a-z]+(?::)?[1-5]$")


# MARK: Text


def content_id(hanzi: str) -> str:
    """A stable id derived from the sentence text, so a learner's favorites survive regeneration."""
    return hashlib.sha1(hanzi.encode("utf-8")).hexdigest()[:16]


def han_only(text: str) -> str:
    """`text` with everything but Han characters removed."""
    return "".join(character for character in text if is_han(character))


def normalized_syllable(syllable: str) -> str:
    """A numbered-pinyin syllable in one spelling: lowercase, ü written ``u:``, and a toneless
    syllable given the neutral tone — so dictionary and generated readings compare equal."""
    syllable = syllable.strip().lower().replace("ü", "u:").replace("v", "u:")
    return syllable if syllable[-1:].isdigit() else f"{syllable}5"


# MARK: Syllabi


@dataclass(frozen=True)
class Syllabus:
    """Every headword's band in one HSK standard; each character's band, the lowest of any headword
    it is written in; and the longest headword, for segmenting."""

    bands: dict[str, int]
    longest: int = field(init=False)
    character_bands: dict[str, int] = field(init=False)

    def __post_init__(self) -> None:
        object.__setattr__(self, "longest", max(map(len, self.bands), default=1))
        characters: dict[str, int] = {}
        for word, band in self.bands.items():
            for character in word:
                characters[character] = min(band, characters.get(character, band))
        object.__setattr__(self, "character_bands", characters)


def syllabi(vocabulary: dict) -> dict[str, Syllabus]:
    """Each standard's syllabus, from ``HSKVocabulary.plist``'s entries. A word listed at several bands
    of a standard takes the lowest."""
    bands: dict[str, dict[str, int]] = {standard: {} for standard in STANDARDS}
    for word, records in vocabulary.items():
        for record in records:
            for tag in record.get("levels", []):
                standard, _, band = tag.partition("-")
                if standard in bands and band.isdigit():
                    current = bands[standard].get(word)
                    bands[standard][word] = min(int(band), current or int(band))
    return {standard: Syllabus(words) for standard, words in bands.items()}


def generation_band(word: str, syllabi: dict[str, Syllabus]) -> int | None:
    """The band a target word is written for: its HSK 3.0 (2026) band, else its 2021 band, else its
    HSK 2.0 band."""
    for standard in ("newest", "new", "old"):
        if (band := syllabi[standard].bands.get(word)) is not None:
            return band
    return None


# MARK: Leveling


@dataclass(frozen=True)
class Token:
    text: str
    is_name: bool = False

    @property
    def is_free(self) -> bool:
        """Whether the token costs nothing to read: a name, or a number spelled in Hanzi."""
        return self.is_name or set(self.text) <= NUMERAL_CHARACTERS


def tokens(words: str) -> list[Token]:
    """A ``/``-separated segmentation as tokens, a leading ``*`` marking a proper name."""
    return [
        Token(word.removeprefix(NAME_MARK), is_name=word.startswith(NAME_MARK))
        for word in (part.strip() for part in words.split(WORD_SEPARATOR))
        if word
    ]


def word_band(word: str, syllabus: Syllabus) -> int | None:
    """`word`'s band in `syllabus`. A word the syllabus doesn't list takes the band of the hardest
    word in its easiest split into syllabus words, or failing that its hardest character's band —
    HSK 2.0 lists 他 but not 他们, and 说话 but not 说. `None` when a character is in no syllabus word."""
    if word in syllabus.bands:
        return syllabus.bands[word]
    if (band := _split_band(word, syllabus)) is not None:
        return band
    characters = [syllabus.character_bands.get(character) for character in word]
    return None if None in characters else max(characters)


def _split_band(word: str, syllabus: Syllabus) -> int | None:
    """The hardest band in the easiest split of `word` into syllabus words, or `None`."""
    # best[i] is the lowest achievable "hardest band" for word[:i].
    best: list[int | None] = [0] + [None] * len(word)
    for end in range(1, len(word) + 1):
        for start in range(max(0, end - syllabus.longest), end):
            piece = word[start:end]
            if best[start] is None or piece not in syllabus.bands:
                continue
            hardest = max(best[start], syllabus.bands[piece])
            if best[end] is None or hardest < best[end]:
                best[end] = hardest
    return best[-1]


def sentence_level(sentence_tokens: Iterable[Token], syllabus: Syllabus) -> int | None:
    """The band a sentence sits at in `syllabus`: its hardest word's. `None` when any word falls
    outside the syllabus."""
    level = 1
    for token in sentence_tokens:
        if token.is_free:
            continue
        band = word_band(token.text, syllabus)
        if band is None:
            return None
        level = max(level, band)
    return level


def levels(sentence_tokens: list[Token], syllabi: dict[str, Syllabus]) -> dict[str, int]:
    """The sentence's level in each standard whose syllabus covers every word it uses."""
    found = {
        standard: sentence_level(sentence_tokens, syllabus)
        for standard, syllabus in syllabi.items()
    }
    return {standard: level for standard, level in found.items() if level is not None}


def segment(hanzi: str, lexicon: set[str], longest: int) -> list[Token]:
    """Splits `hanzi` into words by longest match against `lexicon`, one character at a time where
    nothing longer matches — the segmentation for sentences that came without one."""
    text = han_only(hanzi)
    result: list[Token] = []
    index = 0
    while index < len(text):
        for length in range(min(longest, len(text) - index), 0, -1):
            piece = text[index : index + length]
            if length == 1 or piece in lexicon:
                result.append(Token(piece))
                index += length
                break
    return result


# MARK: Validation


@dataclass(frozen=True)
class Readings:
    """What a character or word may be read as: per-character readings, and whole-word readings from
    a dictionary, each normalized with ``normalized_syllable``."""

    characters: dict[str, set[str]]
    words: dict[str, set[tuple[str, ...]]]

    @classmethod
    def build(cls, character_readings: dict, dictionary: dict) -> Readings:
        characters = {
            character: {normalized_syllable(r) for r in record.get("mandarin", [])}
            for character, record in character_readings.items()
        }
        words = {
            word: {tuple(normalized_syllable(s) for s in e["pinyin"].split()) for e in entries}
            for word, entries in dictionary.items()
        }
        return cls(characters, words)

    def accepts(self, word: str, syllables: tuple[str, ...]) -> bool:
        """Whether `syllables` is a plausible reading of `word`: the dictionary's reading of the whole
        word, or a reading of each character in turn."""
        if any(self._matches(syllables, reading) for reading in self.words.get(word, ())):
            return True
        return all(
            self._character_accepts(character, syllable, is_suffix=index > 0)
            for index, (character, syllable) in enumerate(zip(word, syllables, strict=True))
        )

    def _character_accepts(self, character: str, syllable: str, *, is_suffix: bool) -> bool:
        readings = self.characters.get(character, set())
        if syllable in readings or syllable in SANDHI_READINGS.get(character, ()):
            return True
        if character == "儿" and is_suffix and syllable == "r5":
            return True
        return syllable.endswith("5") and any(r[:-1] == syllable[:-1] for r in readings)

    @staticmethod
    def _matches(syllables: tuple[str, ...], reading: tuple[str, ...]) -> bool:
        """Equal syllable for syllable, a neutral tone standing in for any tone of the same sound."""
        return len(syllables) == len(reading) and all(
            ours == theirs or (ours.endswith("5") and ours[:-1] == theirs[:-1])
            for ours, theirs in zip(syllables, reading, strict=True)
        )


def problems(
    *,
    hanzi: str,
    words: str,
    pinyin: str,
    band: int,
    target: str | None,
    readings: Readings,
) -> list[str]:
    """Everything wrong with one generated sentence; empty when it may ship."""
    found: list[str] = []
    if _LATIN_OR_DIGIT.search(hanzi):
        found.append("contains Latin letters or digits")
    characters = han_only(hanzi)
    low, high = LENGTH_BOUNDS[band]
    if not low <= len(characters) <= high:
        found.append(f"{len(characters)} characters, outside {low}–{high} for band {band}")
    if target and target not in hanzi:
        found.append(f"missing its target word {target}")

    sentence_tokens = tokens(words)
    if "".join(token.text for token in sentence_tokens) != characters:
        found.append("segmentation doesn't spell the sentence")
        return found

    pinyin_words = [part.split() for part in pinyin.split(WORD_SEPARATOR)]
    if len(pinyin_words) != len(sentence_tokens):
        found.append("pinyin and segmentation have different word counts")
        return found
    for token, raw in zip(sentence_tokens, pinyin_words, strict=True):
        syllables = tuple(normalized_syllable(s) for s in raw)
        if len(syllables) != len(token.text) or not all(map(_SYLLABLE.match, syllables)):
            found.append(f"pinyin {' '.join(raw)} doesn't fit {token.text}")
        elif not readings.accepts(token.text, syllables):
            found.append(f"{token.text} isn't read {' '.join(syllables)}")
    return found


def numbered_pinyin(pinyin: str) -> str:
    """Word-grouped pinyin as the space-separated numbered pinyin the app stores."""
    return " ".join(normalized_syllable(s) for s in pinyin.replace(WORD_SEPARATOR, " ").split())


# MARK: Duplicates


def bigrams(text: str) -> set[str]:
    characters = han_only(text)
    return {characters[i : i + 2] for i in range(len(characters) - 1)}


class NearCopyIndex:
    """Finds sentences that share most of their character pairs with any in a reference set — how a
    generated sentence that merely paraphrases a workbook sentence is caught."""

    def __init__(self, sentences: Iterable[str], threshold: float = 0.6) -> None:
        self.threshold = threshold
        self._pairs: list[set[str]] = []
        self._postings: dict[str, list[int]] = {}
        for sentence in sentences:
            pairs = bigrams(sentence)
            for pair in pairs:
                self._postings.setdefault(pair, []).append(len(self._pairs))
            self._pairs.append(pairs)

    def is_near_copy(self, sentence: str) -> bool:
        pairs = bigrams(sentence)
        if not pairs:
            return False
        shared: dict[int, int] = {}
        for pair in pairs:
            for index in self._postings.get(pair, ()):
                shared[index] = shared.get(index, 0) + 1
        return any(
            count / len(pairs | self._pairs[index]) >= self.threshold
            for index, count in shared.items()
        )
