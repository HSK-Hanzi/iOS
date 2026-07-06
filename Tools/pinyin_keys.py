#!/usr/bin/env python3
"""Turn a dictionary's pinyin text into the three search keys the app queries.

`toneless` (`ganjing`) and `marked` (`gānjìng`) need no syllable boundaries; `numbered`
(`gan1jing4`) does, because the digit sits at the end of its syllable. Boundaries come from the
headword's characters — see `segment`.

The alphabet here MUST stay in step with `PinyinSearchKey` in the app: the keys stored by this
module are prefix-matched against queries normalized there.
"""

import re
import unicodedata
from collections import namedtuple

# Combining tone marks → tone digit. U+0308 (diaeresis) is the ü umlaut, not a tone.
TONE_BY_MARK = {"̄": 1, "́": 2, "̌": 3, "̀": 4}
NEUTRAL_TONE = 5

TONE_VOWELS = {
    "a": "āáǎà", "e": "ēéěè", "i": "īíǐì",
    "o": "ōóǒò", "u": "ūúǔù", "ü": "ǖǘǚǜ",
}
VOWELS = "aeiouü"

# Xiandai wraps alternate readings in fullwidth parentheses: rú（旧读ruǎn）
_ANNOTATION = re.compile(r"（[^）]*）")
# A run of Han characters separates alternate readings: xún 又 yīngxún
_ALTERNATE = re.compile(r"[㐀-鿿]+")
# Syllable separators: space, hyphen, Xiandai's // and ·, both apostrophes (Oxford writes
# U+0027, Xiandai U+2019), punctuation.
_SEPARATOR = re.compile("[\\s\\-/·'’,，;；]+")
# A numbered syllable as CC-CEDICT writes it, including its ü spellings.
_NUMBERED_SYLLABLE = re.compile(r"[a-zü]+:?\d")


def _umlaut(body):
    """Rewrite CC-CEDICT's `u:` and bare `v` spellings of ü."""
    return body.replace("u:", "ü").replace("v", "ü")


def _tone_vowel_index(body):
    """The vowel that carries the tone: `a` or `e`, else `o`, else the last vowel."""
    for vowel in ("a", "e", "o"):
        index = body.find(vowel)
        if index >= 0:
            return index
    for index in range(len(body) - 1, -1, -1):
        if body[index] in VOWELS:
            return index
    return -1


def mark_syllable(syllable):
    """Render one numbered syllable (`gan4`, `lu:3`, `de5`) as tone-marked pinyin."""
    tone = int(syllable[-1])
    body = _umlaut(syllable[:-1])
    index = _tone_vowel_index(body)
    if not 1 <= tone <= 4 or index < 0:
        return body
    return body[:index] + TONE_VOWELS[body[index]][tone - 1] + body[index + 1:]


def _render(run):
    """A separator-free run: numbered syllables become tone-marked; anything else passes through."""
    if not any(character.isdigit() for character in run):
        return run
    return _NUMBERED_SYLLABLE.sub(lambda match: mark_syllable(match.group()), run)


def _alternates(pinyin):
    """Each alternate reading's raw text: annotations stripped, script g folded, lowercased."""
    text = _ANNOTATION.sub("", pinyin.lower()).replace("ɡ", "g")
    return [a for a in _ALTERNATE.split(text) if any(c.isalpha() for c in a)]


def _marked(alternate):
    """One alternate's canonical tone-marked form. Separators carry no information a tone-marked
    string needs — the mark sits on a vowel — so they are dropped."""
    runs = [run for run in _SEPARATOR.split(alternate) if run]
    return unicodedata.normalize("NFC", "".join(_render(run) for run in runs))


def canonical_marked(pinyin):
    """Every canonical tone-marked reading a source's pinyin text yields."""
    return [marked for marked in (_marked(a) for a in _alternates(pinyin)) if marked]


# Han ranges the dictionaries actually use, including 〇 and Extension A/B and the compatibility
# block. A headword unit outside these that is not an ASCII letter contributes no pinyin letters.
_HAN_RANGES = (
    (0x3007, 0x3007), (0x3400, 0x4DBF), (0x4E00, 0x9FFF),
    (0xF900, 0xFAFF), (0x20000, 0x2FA1F),
)


def is_han(character):
    """Whether a character is one the dictionaries treat as a Chinese headword unit."""
    code = ord(character)
    return any(low <= code <= high for low, high in _HAN_RANGES)


def letters(marked):
    """The bare ASCII letters of a tone-marked reading: `lǚxíng` → `luxing`."""
    decomposed = unicodedata.normalize("NFD", marked)
    stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
    return "".join(c for c in stripped.replace("ü", "u") if "a" <= c <= "z")


def character_readings(entries):
    """Each character's toneless Mandarin readings, for use as segmentation boundaries."""
    lookup = {}
    for character, data in entries.items():
        if not isinstance(data, dict):
            continue
        found = {
            _umlaut(reading.rstrip("0123456789")).replace("ü", "u").lower()
            for reading in data.get("mandarin", [])
            if isinstance(reading, str)
        }
        if found:
            lookup[character] = found
    return lookup


def _units(word):
    """The headword characters that consume pinyin letters — Han characters and Latin letters."""
    return [c for c in word if is_han(c) or (c.isascii() and c.isalpha())]


def _candidates(unit, index, readings):
    """The letter sequences a headword unit may consume, longest first."""
    if not is_han(unit):
        return [unit.lower()]
    found = sorted(readings.get(unit, ()), key=len, reverse=True)
    # Erhua: a non-initial 儿 is often realised as an `r` glued to the previous syllable.
    return found + ["r"] if unit == "儿" and index > 0 else found


def segment(word, text, readings):
    """Split a reading's letters into syllables, using the headword's characters as boundaries.

    Returns `None` when no split consumes the headword and the letters exactly — an acronym, a
    character with no known reading, or a reading that disagrees with the headword. Callers must
    then omit the `numbered` key rather than guess: a wrong boundary is worse than a missing one.
    """
    units = _units(word)

    def walk(unit_index, position):
        if unit_index == len(units):
            return [] if position == len(text) else None
        for candidate in _candidates(units[unit_index], unit_index, readings):
            if text.startswith(candidate, position):
                rest = walk(unit_index + 1, position + len(candidate))
                if rest is not None:
                    return [candidate] + rest
        return None

    return walk(0, 0) if units else None


SearchKeys = namedtuple("SearchKeys", "toneless numbered marked")


def _letter_tones(marked):
    """One `(letter, tone)` pair per base letter of a tone-marked reading; tone `0` when unmarked.

    A combining mark attaches to the letter before it, so `ü`'s diaeresis is simply not a tone and
    `ǚ` yields `("u", 3)`. Pairing up front — rather than walking the decomposed string alongside
    the syllables — is what keeps a mark trailing the final letter of a syllable from being missed.
    """
    pairs = []
    for character in unicodedata.normalize("NFD", marked):
        if unicodedata.combining(character):
            if pairs and character in TONE_BY_MARK:
                pairs[-1] = (pairs[-1][0], TONE_BY_MARK[character])
        elif "a" <= character.lower() <= "z":
            pairs.append((character.lower(), 0))
    return pairs


def _tones(marked, syllables):
    """The tone digit of each syllable. An unmarked syllable is neutral."""
    pairs = _letter_tones(marked)
    tones = []
    position = 0
    for syllable in syllables:
        span = pairs[position:position + len(syllable)]
        tones.append(next((tone for _, tone in span if tone), NEUTRAL_TONE))
        position += len(syllable)
    return tones


def _numbered_syllables(alternate):
    """The syllables of a numbered-tone reading, whose digits already delimit them.

    CC-CEDICT writes `fang1 an4`, so it never needs ``segment`` — throwing those boundaries away
    and re-deriving them would leave 1,017 of its readings without a `numbered` key instead of 6.

    `None` when any run is not wholly numbered syllables: a tone-marked source, or a run of Latin
    letters such as CC-CEDICT's `san1 D da3 yin4`.
    """
    syllables = []
    for run in (run for run in _SEPARATOR.split(alternate) if run):
        matches = _NUMBERED_SYLLABLE.findall(run)
        if not matches or "".join(matches) != run:
            return None
        syllables.extend(matches)
    return syllables


def search_keys(word, pinyin, readings):
    """The `toneless`, `numbered`, and `marked` keys for every reading in a source's pinyin text.

    `numbered` is empty when the reading has no derivable syllable boundaries. `toneless` and
    `marked` never are — neither needs boundaries — so such a reading stays findable by bare and
    tone-marked pinyin.
    """
    keys = []
    for alternate in _alternates(pinyin):
        numbered_syllables = _numbered_syllables(alternate)
        if numbered_syllables:
            marked = unicodedata.normalize(
                "NFC", "".join(mark_syllable(s) for s in numbered_syllables))
            numbered = "".join(letters(mark_syllable(s)) + s[-1] for s in numbered_syllables)
        else:
            marked = _marked(alternate)
            syllables = segment(word, letters(marked), readings)
            numbered = (
                "".join(f"{s}{t}" for s, t in zip(syllables, _tones(marked, syllables)))
                if syllables
                else ""
            )
        bare = letters(marked)
        if bare:
            keys.append(SearchKeys(toneless=bare, numbered=numbered, marked=marked))
    return keys
