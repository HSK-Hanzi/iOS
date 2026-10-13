#!/usr/bin/env python3
"""Record the reading each HSK syllabus gives a word in the bundled HSK vocabulary.

The vocabulary's forms come from CC-CEDICT, which orders a word's readings alphabetically and lists
its proper-noun forms first, so the forms alone can't say which reading a learner meets at a level
(说 is shuō, not shuì). The published syllabus lists can:

    hsk_syllabus_readings.py <HSKVocabulary.plist> --old <dir> --new <dir> --newest <dir>

- ``--old``: HSK 2.0 levels as ``hsk-level-*.json`` (clem109/hsk-vocabulary).
- ``--new``: HSK 3.0 (2021) levels as ``HSK *.tsv`` — traditional, simplified, pinyin, … —
  (krmanik/HSK-3.0, ``New HSK (2021)/HSK List (Meaning)``).
- ``--newest``: HSK 3.0 (2026) levels as ``HSK_Level_*.txt`` — simplified, traditional, pinyin, … —
  (krmanik/HSK-3.0, ``New HSK (2025)/Anki xiehanzi``).

Each record of the plist gains ``syllabusReadings``: standard → the word's readings in that
standard's lists, in list order, each normalized to its lowercase tone-marked letters ("dǎkāi").
The app normalizes a form's pinyin the same way to match it. The plist is rewritten in place.
"""

import argparse
import json
import plistlib
import sys
import unicodedata
from pathlib import Path

ALTERNATIVE_SEPARATOR = "/"


def normalized(pinyin):
    """The reading's letters alone, lowercased and composed: "Dǎ kāi" and "dǎ-kāi" both "dǎkāi"."""
    composed = unicodedata.normalize("NFC", pinyin.lower())
    return "".join(character for character in composed if character.isalpha())


def readings(pinyin):
    """Each normalized alternative of a listed reading, e.g. "shú/shóu" → ["shú", "shóu"]."""
    return [normalized(alternative) for alternative in pinyin.split(ALTERNATIVE_SEPARATOR)]


def old_rows(directory):
    for path in sorted(Path(directory).glob("hsk-level-*.json")):
        for word in json.loads(path.read_text(encoding="utf-8")):
            yield word["hanzi"], word["pinyin"]


def tabular_rows(directory, pattern, simplified_column):
    for path in sorted(Path(directory).glob(pattern)):
        for line in path.read_text(encoding="utf-8").splitlines():
            columns = line.split("\t")
            if len(columns) > 2:
                yield columns[simplified_column], columns[2]


def syllabus(rows):
    """Simplified headword → its distinct normalized readings, in the order the lists give them."""
    by_word = {}
    for simplified, pinyin in rows:
        known = by_word.setdefault(simplified, [])
        known.extend(reading for reading in readings(pinyin) if reading and reading not in known)
    return by_word


def annotate(entries, syllabi):
    """Writes each word's readings per standard onto its records; returns how many have none."""
    unread = 0
    for simplified, records in entries.items():
        by_standard = {
            standard: by_word[simplified]
            for standard, by_word in syllabi.items()
            if simplified in by_word
        }
        unread += not by_standard
        for record in records:
            record["syllabusReadings"] = by_standard
    return unread


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("vocabulary", type=Path)
    parser.add_argument("--old", type=Path, required=True)
    parser.add_argument("--new", type=Path, required=True)
    parser.add_argument("--newest", type=Path, required=True)
    arguments = parser.parse_args(argv)

    syllabi = {
        "old": syllabus(old_rows(arguments.old)),
        "new": syllabus(tabular_rows(arguments.new, "HSK *.tsv", simplified_column=1)),
        "newest": syllabus(tabular_rows(arguments.newest, "HSK_Level_*.txt", simplified_column=0)),
    }
    with arguments.vocabulary.open("rb") as handle:
        root = plistlib.load(handle)
    unread = annotate(root["entries"], syllabi)
    with arguments.vocabulary.open("wb") as handle:
        plistlib.dump(root, handle, fmt=plistlib.FMT_BINARY)

    print(f"{len(root['entries']) - unread} words read, {unread} absent from every list", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
