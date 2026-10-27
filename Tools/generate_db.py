#!/usr/bin/env python3
"""Convert the app's bundled property lists into prebuilt SQLite databases.

Every store the app queries lazily ships as a SQLite database generated here at build time, so
nothing large is parsed into memory at runtime. One subcommand per store:

    generate_db.py dictionary <source.plist> <dest.sqlite> --frequency <freq.plist> --readings <readings.plist>
    generate_db.py frequency  <source.plist> <dest.sqlite>
    generate_db.py strokes    <source.plist> <dest.sqlite>
    generate_db.py characters <readings.plist> <etymology.plist> <charfreq.plist> <dest.sqlite>
                              [--radicals <radicals.plist>]
    generate_db.py sentences  <source.plist> <dest.sqlite> [--grammar <grammar.plist>]

Each row keeps its record as a binary-plist blob (or plain columns) so the app decodes it through
the same parsers the source data uses, alongside indexed columns for lookup and search. Stroke
graphics, the bulkiest records, use a compact binary form of their own (see ``encoded_graphic``).
Word frequency is folded into the dictionaries as a `rank` column so Chinese/pinyin search can
order by it in SQL; English is a per-sense FTS5 index ranked by bm25 relevance.

Each reading is indexed under three keys — see ``pinyin_keys`` — so a query of bare letters, tone
digits, or tone marks each has a column to prefix-match against. The alphabet those keys use MUST
stay in step with ``PinyinSearchKey`` in the app.
"""

import argparse
import plistlib
import sqlite3
import struct
import sys
import zlib
from pathlib import Path

from pinyin_keys import character_readings, search_keys

# A rank strictly larger than any real frequency rank, for headwords absent from the corpus, so
# `ORDER BY rank` sorts them last. Mirrors WordDictionary's expectation of a non-null rank.
UNRANKED = 2_000_000_000


# MARK: Shared helpers


def load_plist(path):
    with open(path, "rb") as handle:
        return plistlib.load(handle)


def entries_of(root):
    """The entry map of a `{meta, entries}` plist, or the root itself when it has no wrapper."""
    if isinstance(root, dict) and "entries" in root:
        return root.get("entries", {}), root.get("meta", {})
    return root, {}


def fresh_database(destination):
    path = Path(destination)
    if path.exists():
        path.unlink()
    return sqlite3.connect(str(path))


def finish(connection):
    connection.commit()
    connection.execute("PRAGMA optimize")
    connection.execute("VACUUM")
    connection.close()


def blob(value):
    return plistlib.dumps(value, fmt=plistlib.FMT_BINARY)


def frequency_ranks(frequency_plist):
    """Maps each word to its 1-based rank by descending per-million frequency, from a SUBTLEX plist."""
    if not frequency_plist:
        return {}
    entries, _ = entries_of(load_plist(frequency_plist))
    ordered = sorted(entries.items(), key=lambda item: item[1][0], reverse=True)
    return {word: index + 1 for index, (word, _) in enumerate(ordered)}


# MARK: Dictionary


def build_dictionary(source, destination, frequency_plist, readings_plist):
    """Write one dictionary database. Returns (rows written, readings left without a numbered key)."""
    entries, meta = entries_of(load_plist(source))
    ranks = frequency_ranks(frequency_plist)
    readings = character_readings(entries_of(load_plist(readings_plist))[0])
    connection = fresh_database(destination)
    connection.executescript(
        """
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE entry (
            id INTEGER PRIMARY KEY,
            simplified TEXT NOT NULL,
            traditional TEXT NOT NULL,
            toneless TEXT NOT NULL,
            numbered TEXT NOT NULL,
            marked TEXT NOT NULL,
            rank INTEGER NOT NULL,
            payload BLOB NOT NULL
        );
        CREATE TABLE sense (id INTEGER PRIMARY KEY, headword TEXT NOT NULL, gloss TEXT NOT NULL);
        CREATE VIRTUAL TABLE sense_fts USING fts5(gloss, content='');
        """
    )
    insert_dictionary_meta(connection, meta)
    count = 0
    unsegmented = 0
    for simplified, entry_readings in entries.items():
        rank = ranks.get(simplified, UNRANKED)
        for reading in entry_readings if isinstance(entry_readings, list) else []:
            if not isinstance(reading, dict):
                continue
            traditional, pinyin = reading.get("traditional"), reading.get("pinyin")
            if not isinstance(traditional, str) or not isinstance(pinyin, str):
                continue
            payload = blob(reading)
            for keys in search_keys(simplified, pinyin, readings):
                if not keys.numbered:
                    unsegmented += 1
                connection.execute(
                    "INSERT INTO entry(simplified, traditional, toneless, numbered, marked, rank, payload) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (simplified, traditional, keys.toneless, keys.numbered, keys.marked, rank, payload),
                )
                count += 1
            # Each English sense is indexed as its own FTS document so that an exact-sense match
            # (e.g. 面包 → "bread") scores as a short, dense document and ranks above entries where
            # the word is incidental in a long gloss (e.g. 烤 → "to roast; …; to toast (bread)").
            for gloss in english_glosses(reading.get("senses", [])):
                inserted = connection.execute(
                    "INSERT INTO sense(headword, gloss) VALUES (?, ?)", (simplified, gloss)
                )
                connection.execute(
                    "INSERT INTO sense_fts(rowid, gloss) VALUES (?, ?)", (inserted.lastrowid, gloss)
                )
    # The three search indexes are covering: a prefix scan reads `rank` and `simplified` straight
    # from the index and never touches the payload-bearing table row.
    connection.executescript(
        """
        CREATE INDEX entry_simplified ON entry(simplified);
        CREATE INDEX entry_traditional ON entry(traditional);
        CREATE INDEX entry_toneless ON entry(toneless, rank, simplified);
        CREATE INDEX entry_numbered ON entry(numbered, rank, simplified);
        CREATE INDEX entry_marked ON entry(marked, rank, simplified);
        """
    )
    finish(connection)
    return count, unsegmented


def insert_dictionary_meta(connection, meta):
    rows = [(key, meta[key]) for key in ("identifier", "name", "license") if isinstance(meta.get(key), str)]
    if "licensed" in meta:
        rows.append(("licensed", "1" if meta.get("licensed") else "0"))
    connection.executemany("INSERT INTO meta(key, value) VALUES (?, ?)", rows)


def english_glosses(senses):
    """Each English gloss of an entry, for per-sense full-text search — bare-string and structured."""
    out = []
    for sense in senses:
        if isinstance(sense, str):
            out.append(sense)
        elif isinstance(sense, dict) and isinstance(sense.get("gloss"), str):
            out.append(sense["gloss"])
    return out


# MARK: Frequency


def build_frequency(source, destination):
    entries, _ = entries_of(load_plist(source))
    ranks = frequency_ranks(source)
    connection = fresh_database(destination)
    connection.execute(
        """
        CREATE TABLE frequency (
            word TEXT PRIMARY KEY,
            per_million REAL NOT NULL,
            contextual_diversity REAL NOT NULL,
            rank INTEGER NOT NULL
        )
        """
    )
    rows = [
        (word, float(pair[0]), float(pair[1]), ranks[word])
        for word, pair in entries.items()
        if isinstance(pair, (list, tuple)) and len(pair) == 2
    ]
    connection.executemany(
        "INSERT INTO frequency(word, per_million, contextual_diversity, rank) VALUES (?, ?, ?, ?)",
        rows,
    )
    finish(connection)
    return len(rows)


# MARK: Strokes


# How many coordinates follow each SVG path command in Make Me a Hanzi's outlines.
PATH_COMMAND_ARITY = {"M": 2, "L": 2, "Q": 4, "C": 6, "Z": 0}

# Coordinates are stored in quarter units, which every outline coordinate is a whole number of.
COORDINATE_SCALE = 4


def encoded_graphic(graphic):
    """A stroke graphic in the compact binary form `HanziGraphic(encoded:)` decodes, raw-DEFLATE
    compressed. All integers are little-endian; coordinates are int16 quarter units.

        u8  stroke count N
        N × outline: u16 command count, then per command its ASCII letter and its coordinates
        N × median:  u16 point count, then per point its x and y

    Outlines round-trip exactly. A median point off the quarter-unit grid, in a handful of glyphs,
    rounds to the nearest quarter unit.
    """
    strokes, medians = graphic["strokes"], graphic["medians"]
    out = bytearray(struct.pack("<B", len(strokes)))
    for path in strokes:
        commands = path_commands(path)
        out += struct.pack("<H", len(commands))
        for letter, values in commands:
            out += letter.encode("ascii") + struct.pack(f"<{len(values)}h", *values)
    for median in medians:
        out += struct.pack("<H", len(median))
        for point in median:
            out += struct.pack("<2h", *(round(value * COORDINATE_SCALE) for value in point))
    compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
    return compressor.compress(bytes(out)) + compressor.flush()


def path_commands(path):
    """An SVG path `d` string as (command letter, scaled coordinates) pairs."""
    tokens = path.split()
    commands = []
    index = 0
    while index < len(tokens):
        letter = tokens[index]
        arity = PATH_COMMAND_ARITY[letter]
        values = tokens[index + 1 : index + 1 + arity]
        commands.append((letter, [round(float(value) * COORDINATE_SCALE) for value in values]))
        index += 1 + arity
    return commands


def build_strokes(source, destination):
    entries, _ = entries_of(load_plist(source))
    connection = fresh_database(destination)
    connection.execute("CREATE TABLE graphic (character TEXT PRIMARY KEY, payload BLOB NOT NULL)")
    rows = [
        (character, encoded_graphic(graphic))
        for character, graphic in entries.items()
        if len(character) == 1 and isinstance(graphic, dict)
    ]
    connection.executemany("INSERT INTO graphic(character, payload) VALUES (?, ?)", rows)
    finish(connection)
    return len(rows)


# MARK: Characters


def build_characters(readings_plist, etymology_plist, charfreq_plist, destination, radicals_plist):
    readings, _ = entries_of(load_plist(readings_plist))
    etymology, _ = entries_of(load_plist(etymology_plist))
    charfreq, _ = entries_of(load_plist(charfreq_plist))
    radical_document = load_plist(radicals_plist) if radicals_plist else {}
    radicals = radical_document.get("entries", {})
    characters = {
        c for source in (readings, etymology, charfreq, radicals) for c in source if len(c) == 1
    }

    connection = fresh_database(destination)
    connection.executescript(
        """
        CREATE TABLE character (
            character TEXT PRIMARY KEY,
            readings BLOB,
            etymology TEXT,
            frequency_rank INTEGER,
            radical TEXT,
            residual_strokes INTEGER
        );
        CREATE INDEX character_radical ON character(radical, residual_strokes);
        CREATE TABLE radical (
            number TEXT PRIMARY KEY,
            glyph TEXT NOT NULL,
            strokes INTEGER NOT NULL,
            ordinal INTEGER NOT NULL
        );
        """
    )
    rows = []
    for character in characters:
        reading = readings.get(character)
        etym = etymology.get(character)
        rank = charfreq.get(character)
        radical = radicals.get(character, {})
        rows.append(
            (
                character,
                blob(reading) if isinstance(reading, dict) else None,
                etym if isinstance(etym, str) else None,
                int(rank) if isinstance(rank, int) else None,
                radical.get("radical"),
                radical.get("residualStrokes"),
            )
        )
    connection.executemany(
        "INSERT INTO character(character, readings, etymology, frequency_rank, radical, "
        "residual_strokes) VALUES (?, ?, ?, ?, ?, ?)",
        rows,
    )
    connection.executemany(
        "INSERT INTO radical(number, glyph, strokes, ordinal) VALUES (?, ?, ?, ?)",
        [
            (radical["number"], radical["glyph"], radical["strokes"], ordinal)
            for ordinal, radical in enumerate(radical_document.get("radicals", []))
        ],
    )
    finish(connection)
    return len(rows)


def build_sentences(source, destination, grammar_plist):
    """One row per practice sentence, with its level in each HSK standard (null where that
    standard's syllabus doesn't cover it) and the word it was written to exemplify, if any. Rows
    keep the source's order, which the app lists them in. With a grammar-point list, also the
    points in level order and, for each, the sentences that use it."""
    sentences, _ = entries_of(load_plist(source))
    points, _ = entries_of(load_plist(grammar_plist)) if grammar_plist else ([], {})
    connection = fresh_database(destination)
    connection.executescript(
        """
        CREATE TABLE sentence (
            id TEXT PRIMARY KEY,
            hanzi TEXT NOT NULL,
            numbered_pinyin TEXT NOT NULL,
            translation TEXT NOT NULL,
            level_old INTEGER,
            level_new INTEGER,
            level_newest INTEGER,
            target TEXT
        );
        CREATE INDEX sentence_level_old ON sentence(level_old);
        CREATE INDEX sentence_level_new ON sentence(level_new);
        CREATE INDEX sentence_level_newest ON sentence(level_newest);
        CREATE INDEX sentence_target ON sentence(target);
        CREATE TABLE grammar_point (
            id TEXT PRIMARY KEY,
            level INTEGER NOT NULL,
            ordinal INTEGER NOT NULL,
            name TEXT NOT NULL,
            pattern TEXT NOT NULL,
            explanation TEXT NOT NULL
        );
        CREATE TABLE sentence_grammar (
            point_id TEXT NOT NULL REFERENCES grammar_point(id),
            sentence_id TEXT NOT NULL REFERENCES sentence(id)
        );
        CREATE INDEX sentence_grammar_point ON sentence_grammar(point_id);
        """
    )
    connection.executemany(
        "INSERT INTO grammar_point VALUES (?, ?, ?, ?, ?, ?)",
        [
            (p["id"], p["level"], ordinal, p["name"], p["pattern"], p["explanation"])
            for ordinal, p in enumerate(points)
        ],
    )
    known_points = {p["id"] for p in points}
    for entry in sentences:
        levels = entry.get("levels", {})
        connection.execute(
            "INSERT INTO sentence VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                entry["id"],
                entry["hanzi"],
                entry["numberedPinyin"],
                entry["translation"],
                levels.get("old"),
                levels.get("new"),
                levels.get("newest"),
                entry.get("target"),
            ),
        )
        connection.executemany(
            "INSERT INTO sentence_grammar(point_id, sentence_id) VALUES (?, ?)",
            [
                (point, entry["id"])
                for point in dict.fromkeys(entry.get("grammarPoints", []))
                if point in known_points
            ],
        )
    finish(connection)
    return len(sentences)


# MARK: Entry point


def main(argv):
    parser = argparse.ArgumentParser(description="Generate the app's prebuilt SQLite databases.")
    kinds = parser.add_subparsers(dest="kind", required=True)

    dictionary = kinds.add_parser("dictionary")
    dictionary.add_argument("source")
    dictionary.add_argument("destination")
    dictionary.add_argument("--frequency", default=None)
    dictionary.add_argument("--readings", required=True)

    for name in ("frequency", "strokes", "sentences"):
        one = kinds.add_parser(name)
        one.add_argument("source")
        one.add_argument("destination")
        if name == "sentences":
            one.add_argument("--grammar", default=None)

    characters = kinds.add_parser("characters")
    characters.add_argument("readings")
    characters.add_argument("etymology")
    characters.add_argument("charfreq")
    characters.add_argument("destination")
    characters.add_argument("--radicals", default=None)

    args = parser.parse_args(argv[1:])
    if args.kind == "dictionary":
        count, unsegmented = build_dictionary(
            args.source, args.destination, args.frequency, args.readings
        )
        if unsegmented:
            sys.stderr.write(
                f"note: {unsegmented} readings have no numbered key in {args.destination}\n"
            )
    elif args.kind == "frequency":
        count = build_frequency(args.source, args.destination)
    elif args.kind == "strokes":
        count = build_strokes(args.source, args.destination)
    elif args.kind == "sentences":
        count = build_sentences(args.source, args.destination, args.grammar)
    else:
        count = build_characters(
            args.readings, args.etymology, args.charfreq, args.destination, args.radicals
        )

    sys.stderr.write(f"note: wrote {count} rows to {args.destination}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
