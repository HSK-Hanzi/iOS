# Zili data pipeline

Command-line tools that turn the app's bundled property lists into the prebuilt SQLite databases
the app queries lazily at runtime. Every large store the app reads ships as a SQLite database
generated here, so nothing large is parsed into memory on device.

The source `.plist` files live in the two data submodules:

- `Data/Open/` — openly-licensed corpora, always bundled.
- `Data/Proprietary/` — copyrighted corpora, Debug builds only.

Each source plist uses a self-describing `{ meta, entries }` schema (or a bare entry map).

## Prerequisites

- **Python 3.14** via [pyenv](https://github.com/pyenv/pyenv) + `pyenv-virtualenv`. The
  `zili-tools` virtualenv is pinned in `Tools/.python-version`, so `cd Tools` selects it
  automatically once it exists:

  ```sh
  pyenv virtualenv 3.14.6 zili-tools
  ```

- **No third-party packages.** `generate_db.py` and its `pinyin_keys` helper use only the standard
  library (`argparse`, `plistlib`, `sqlite3`, `pathlib`, `re`, `unicodedata`). The SQLite bundled
  with Python must include the **FTS5** extension — standard on macOS and in the pyenv builds — for
  the dictionary's English full-text index.

## `generate_db.py`

Converts one source store into one SQLite database. One subcommand per store; each prints the row
count it wrote to stderr and overwrites the destination if it already exists.

### `dictionary`

Builds a searchable Chinese–English dictionary database from a dictionary plist. Word frequency is
folded in as a `rank` column so Chinese and pinyin searches order by it in SQL; each English sense
becomes its own FTS5 document ranked by bm25 relevance. Every reading is indexed under three pinyin
keys (toneless, numbered, tone-marked) whose alphabet must stay in step with `PinyinSearchKey` in
the app.

```text
generate_db.py dictionary <source.plist> <dest.sqlite> --readings <readings.plist> [--frequency <freq.plist>]
```

| Argument       | Meaning                                                              |
| -------------- | ------------------------------------------------------------------- |
| `source`       | Dictionary plist (e.g. `CEDICT.plist`, `ABC.plist`).                |
| `destination`  | SQLite database to write.                                            |
| `--readings`   | **Required.** `CharacterReadings.plist`, for per-character keying.   |
| `--frequency`  | Optional `SUBTLEX-CH-Words.plist`; unranked headwords sort last.     |

```sh
# CC-CEDICT (open)
generate_db.py dictionary \
  ../Data/Open/CEDICT.plist CEDICT.sqlite \
  --readings ../Data/Open/CharacterReadings.plist \
  --frequency ../Data/Open/SUBTLEX-CH-Words.plist

# ABC dictionary (proprietary)
generate_db.py dictionary \
  ../Data/Proprietary/ABC.plist ABC.sqlite \
  --readings ../Data/Open/CharacterReadings.plist \
  --frequency ../Data/Open/SUBTLEX-CH-Words.plist
```

If any reading has no numbered pinyin key, a `note:` count is written to stderr.

### `frequency`

Builds the word-frequency database from a SUBTLEX plist, one row per word with its per-million
frequency, contextual diversity, and 1-based rank by descending frequency.

```text
generate_db.py frequency <source.plist> <dest.sqlite>
```

```sh
generate_db.py frequency ../Data/Open/SUBTLEX-CH-Words.plist SUBTLEX-CH-Words.sqlite
```

### `strokes`

Builds the stroke-order database from the Make Me a Hanzi stroke plist, one row per single character
with its stroke graphic kept as a binary-plist blob.

```text
generate_db.py strokes <source.plist> <dest.sqlite>
```

```sh
generate_db.py strokes ../Data/Open/HanziStrokeOrder.plist HanziStrokeOrder.sqlite
```

### `characters`

Builds the per-character database, joining readings, etymology, and character frequency into one row
per character.

```text
generate_db.py characters <readings.plist> <etymology.plist> <charfreq.plist> <dest.sqlite>
```

```sh
generate_db.py characters \
  ../Data/Open/CharacterReadings.plist \
  ../Data/Open/CharacterEtymology.plist \
  ../Data/Open/CharacterFrequency.plist \
  Characters.sqlite
```

## Supporting scripts

- **`pinyin_keys.py`** — derives the three per-reading pinyin search keys (toneless, numbered,
  tone-marked). Imported by `generate_db.py`; its alphabet mirrors `PinyinSearchKey` in the app.
- **`generate_sentences.py`** — generates the bundled sentence corpora (`PracticeSentences.plist`,
  `HSKSentences.plist`) from the HSK workbook dump using the Claude API. See the module docstring
  for usage; this step feeds the pipeline rather than being part of the SQLite build.
- **`hsk_sentences.py`** — cleans the raw HSK sentence dump consumed by `generate_sentences.py`.
- **`test_pinyin_keys.py`, `test_hsk_sentences.py`** — unit tests for the two helpers.
