#!/usr/bin/env python3
"""Generate Zili's bundled sentence corpora from the HSK workbook dump.

Two corpora come out of one pass over the cleaned HSK sentences (see ``hsk_sentences``):

  - ``HSKSentences.plist`` — the **original** HSK sentences with generated numbered pinyin and an
    English translation. Copyrighted; ships only in Debug builds (``Data/licensed/``).
  - ``PracticeSentences.plist`` — a **novel** sentence for each usable HSK sentence, written with
    vocabulary at or below that sentence's HSK level, plus its pinyin and translation. Original
    content; always ships (``Data/open/``).

Each HSK sentence is sent to Claude once (via the Batches API for the full run, or synchronously for
a ``--limit`` pilot), which decides whether the input is a usable standalone sentence and, if so,
returns both corpora's fields as one structured object. Pinyin is **space-separated numbered pinyin**
(``wo3 xiang3 mai3 shui3 guo3``); the app transliterates it to the reader's romanization at display
time, so this is the one canonical reading we store.

Usage::

    # Pilot: 12 sentences, synchronous, prints results — validate quality before the full run.
    python generate_sentences.py --limit 12

    # Full run over every clean sentence, via the Batches API (50% cost, ~1h).
    python generate_sentences.py --batch

``ANTHROPIC_API_KEY`` is read from the environment (source it from 1Password, e.g. ``op run``).
"""

from __future__ import annotations

import argparse
import hashlib
import os
import plistlib
import sys
import time
from pathlib import Path

import anthropic
from anthropic.types.message_create_params import MessageCreateParamsNonStreaming
from anthropic.types.messages.batch_create_params import Request

import hsk_sentences

# The model that writes the sentences. Opus by default (the strongest option for correct pinyin and
# level-appropriate vocabulary); override with --model claude-sonnet-5 to cut cost roughly in half.
DEFAULT_MODEL = "claude-opus-4-8"

REPO = Path(__file__).resolve().parent.parent
SOURCE_FILE = Path.home() / "Desktop" / "HSK_Practice_Sentences.txt"
HSK_VOCABULARY = REPO / "Data" / "open" / "HSKVocabulary.plist"
LICENSED_OUT = REPO / "Data" / "licensed" / "HSKSentences.plist"
OPEN_OUT = REPO / "Data" / "open" / "PracticeSentences.plist"

# The Standard Course workbooks the dump is drawn from teach HSK 2.0, whose six levels the vocabulary
# plist tags "old-1"…"old-6". A sentence at level N may use any word introduced at or below level N.
VOCABULARY_STANDARD = "old"

SYSTEM_PROMPT = """\
You are an expert Mandarin Chinese teacher building study material for HSK learners.

You are given one sentence extracted from an HSK Standard Course workbook, tagged with its HSK level \
(1 = beginner … 6 = advanced). The extraction is imperfect, so first judge whether the input is a \
single, coherent, self-contained Chinese sentence worth studying.

Set `usable` to false — and leave every other field an empty string — when the input is not one \
clean sentence: it is a fragment, two unrelated sentences run together, a comprehension question \
about a passage the learner cannot see, garbled OCR, or otherwise not a natural standalone sentence.

When `usable` is true, produce all of these:
  - `original_pinyin`: the input sentence's reading as space-separated numbered pinyin — one \
syllable per token, each ending in its tone digit 1–5 (5 = neutral tone), e.g. \
"wo3 xiang3 mai3 yi4 xie1 shui3 guo3". Group syllables into words with no internal spaces is NOT \
required; a plain space between every syllable is fine. Apply tone sandhi as actually spoken \
(e.g. 不 before a 4th tone is bu2, 一 is often yi4/yi2). No tone marks, no punctuation, letters only.
  - `original_translation`: a natural, concise English translation of the input sentence.
  - `novel_hanzi`: a NEW, original Chinese sentence — never copy the input — that is similar in \
topic, structure, and difficulty, and uses ONLY vocabulary and grammar a learner at this HSK level \
(or below) would know. Keep it natural and roughly the same length. End it with normal Chinese \
punctuation (。？！).
  - `novel_pinyin`: `novel_hanzi`'s reading, in the same numbered-pinyin format as `original_pinyin`.
  - `novel_translation`: a natural, concise English translation of `novel_hanzi`.

Return only the structured object.\
"""

# The structured-output contract: every field required so the model can't omit one, empty strings
# when the sentence is unusable.
OUTPUT_SCHEMA = {
    "type": "object",
    "properties": {
        "usable": {"type": "boolean"},
        "original_pinyin": {"type": "string"},
        "original_translation": {"type": "string"},
        "novel_hanzi": {"type": "string"},
        "novel_pinyin": {"type": "string"},
        "novel_translation": {"type": "string"},
    },
    "required": [
        "usable",
        "original_pinyin",
        "original_translation",
        "novel_hanzi",
        "novel_pinyin",
        "novel_translation",
    ],
    "additionalProperties": False,
}


def main(argv: list[str]) -> int:
    args = parse_arguments(argv)
    sentences = hsk_sentences.clean_sentences(SOURCE_FILE.read_text())
    if args.levels:
        sentences = [s for s in sentences if s.level in args.levels]
    if args.limit:
        sentences = even_sample(sentences, args.limit)
    print(f"{len(sentences)} sentence(s) to generate from.", file=sys.stderr)

    allowed = allowed_characters_by_level()
    client = anthropic.Anthropic()
    results = (
        run_batch(client, sentences, args)
        if args.batch
        else run_sync(client, sentences, args)
    )

    kept = assemble(sentences, results, allowed)
    if args.limit and not args.write:
        preview(kept)
        return 0
    write_corpora(kept)
    return 0


# MARK: Generation


def run_sync(client, sentences, args):
    """Generate one sentence at a time, in order — for a small pilot you can eyeball."""
    results: dict[str, dict] = {}
    for index, sentence in enumerate(sentences, start=1):
        print(
            f"  [{index}/{len(sentences)}] HSK{sentence.level} {sentence.hanzi}",
            file=sys.stderr,
        )
        message = client.messages.create(
            model=args.model,
            max_tokens=1024,
            system=[
                {
                    "type": "text",
                    "text": SYSTEM_PROMPT,
                    "cache_control": {"type": "ephemeral"},
                }
            ],
            output_config={"format": {"type": "json_schema", "schema": OUTPUT_SCHEMA}},
            messages=[{"role": "user", "content": prompt_for(sentence)}],
        )
        results[key_of(sentence)] = parse_output(message)
    return results


def run_batch(client, sentences, args):
    """Generate every sentence through the Batches API — half price, keyed by our own IDs."""
    shared_system = [
        {"type": "text", "text": SYSTEM_PROMPT, "cache_control": {"type": "ephemeral"}}
    ]
    batch = client.messages.batches.create(
        requests=[
            Request(
                custom_id=key_of(sentence),
                params=MessageCreateParamsNonStreaming(
                    model=args.model,
                    max_tokens=1024,
                    system=shared_system,
                    output_config={
                        "format": {"type": "json_schema", "schema": OUTPUT_SCHEMA}
                    },
                    messages=[{"role": "user", "content": prompt_for(sentence)}],
                ),
            )
            for sentence in sentences
        ]
    )
    print(f"Batch {batch.id} submitted; polling…", file=sys.stderr)
    await_batch(client, batch.id)

    results: dict[str, dict] = {}
    for result in client.messages.batches.results(batch.id):
        if result.result.type == "succeeded":
            results[result.custom_id] = parse_output(result.result.message)
        else:
            print(f"  {result.custom_id}: {result.result.type}", file=sys.stderr)
    return results


def await_batch(client, batch_id):
    """Blocks until the batch ends, reporting progress. Date.now() is fine here — a plain script."""
    while True:
        batch = client.messages.batches.retrieve(batch_id)
        counts = batch.request_counts
        print(
            f"  status={batch.processing_status} "
            f"done={counts.succeeded + counts.errored} processing={counts.processing}",
            file=sys.stderr,
        )
        if batch.processing_status == "ended":
            return
        time.sleep(30)


def prompt_for(sentence: hsk_sentences.Sentence) -> str:
    return f"HSK level: {sentence.level}\nSentence: {sentence.hanzi}"


def parse_output(message) -> dict:
    """The JSON object the structured-output format guarantees in the message's text block."""
    import json

    text = next(block.text for block in message.content if block.type == "text")
    return json.loads(text)


# MARK: Assembly & validation


def assemble(sentences, results, allowed):
    """Turn the raw model outputs into the two corpora's entries, dropping unusable sentences and
    warning when a novel sentence strays outside its level's vocabulary or its pinyin looks off."""
    licensed: list[dict] = []
    openly: list[dict] = []
    for sentence in sentences:
        result = results.get(key_of(sentence))
        if not result or not result.get("usable"):
            continue
        licensed.append(
            entry(
                sentence.hanzi,
                sentence.level,
                result["original_pinyin"],
                result["original_translation"],
            )
        )
        novel = result["novel_hanzi"]
        openly.append(
            entry(
                novel,
                sentence.level,
                result["novel_pinyin"],
                result["novel_translation"],
            )
        )
        warn_if_off_level(novel, sentence.level, allowed)
        warn_if_pinyin_mismatched(novel, result["novel_pinyin"])
    print(f"Kept {len(openly)} usable sentence(s).", file=sys.stderr)
    return {"licensed": dedupe(licensed), "open": dedupe(openly)}


def entry(hanzi: str, level: int, numbered_pinyin: str, translation: str) -> dict:
    return {
        "id": content_id(hanzi),
        "level": level,
        "hanzi": hanzi,
        "numberedPinyin": numbered_pinyin.strip(),
        "translation": translation.strip(),
    }


def content_id(hanzi: str) -> str:
    """A stable id derived from the sentence text, so a learner's favorites survive regeneration."""
    return hashlib.sha1(hanzi.encode("utf-8")).hexdigest()[:16]


def dedupe(entries: list[dict]) -> list[dict]:
    """One entry per id, first occurrence winning, keeping level order."""
    seen: set[str] = set()
    return [e for e in entries if e["id"] not in seen and not seen.add(e["id"])]


def warn_if_off_level(hanzi: str, level: int, allowed: dict[int, set[str]]) -> None:
    stray = {c for c in hanzi if hsk_sentences._HAN_RE.match(c)} - allowed.get(
        level, set()
    )
    if stray:
        print(
            f"  ⚠︎ HSK{level} novel uses off-level char(s) {''.join(sorted(stray))}: {hanzi}",
            file=sys.stderr,
        )


def warn_if_pinyin_mismatched(hanzi: str, numbered_pinyin: str) -> None:
    syllables = len(numbered_pinyin.split())
    han = len(hsk_sentences._HAN_RE.findall(hanzi))
    if syllables != han:
        print(
            f"  ⚠︎ pinyin has {syllables} syllables for {han} characters: {hanzi}",
            file=sys.stderr,
        )


def allowed_characters_by_level() -> dict[int, set[str]]:
    """For each HSK level 1–6, the set of Han characters used by words at that level or below —
    the yardstick for flagging a novel sentence that reaches beyond its level's vocabulary."""
    root = plistlib.loads(HSK_VOCABULARY.read_bytes())
    per_level: dict[int, set[str]] = {level: set() for level in range(1, 7)}
    for simplified, records in root.get("entries", {}).items():
        bands = {
            int(tag.split("-")[1])
            for record in records
            for tag in record.get("levels", [])
            if tag.startswith(f"{VOCABULARY_STANDARD}-")
        }
        lowest = min(bands, default=None)
        if lowest is None:
            continue
        for level in range(lowest, 7):
            per_level[level].update(simplified)
    return per_level


# MARK: Output


def write_corpora(kept: dict) -> None:
    write_plist(
        LICENSED_OUT,
        kept["licensed"],
        name="HSK Standard Course Sentences",
        description="Practice sentences extracted from the HSK Standard Course workbooks. "
        "Copyrighted; bundled in Debug builds only.",
    )
    write_plist(
        OPEN_OUT,
        kept["open"],
        name="Zili Practice Sentences",
        description="Original HSK-leveled practice sentences generated for Zili.",
    )


def write_plist(
    path: Path, entries: list[dict], *, name: str, description: str
) -> None:
    ordered = sorted(entries, key=lambda e: (e["level"], e["id"]))
    document = {"meta": {"name": name, "description": description}, "entries": ordered}
    path.write_bytes(plistlib.dumps(document, fmt=plistlib.FMT_XML))
    print(f"Wrote {len(ordered)} entries → {path.relative_to(REPO)}", file=sys.stderr)


def preview(kept: dict) -> None:
    for entry in kept["open"]:
        print(f"HSK{entry['level']}  {entry['hanzi']}")
        print(f"        {entry['numberedPinyin']}")
        print(f"        {entry['translation']}\n")


# MARK: Helpers


def key_of(sentence: hsk_sentences.Sentence) -> str:
    """The batch custom_id for a source sentence: stable, and ≤64 chars as the API requires."""
    return content_id(sentence.hanzi)


def even_sample(sentences, limit):
    """Up to `limit` sentences spread evenly across the levels present, for a representative pilot."""
    from collections import defaultdict

    by_level: dict[int, list] = defaultdict(list)
    for sentence in sentences:
        by_level[sentence.level].append(sentence)
    per_level = max(1, limit // len(by_level))
    sample = [s for level in sorted(by_level) for s in by_level[level][:per_level]]
    return sample[:limit]


def parse_arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--model", default=DEFAULT_MODEL, help="Model id (default: %(default)s)."
    )
    parser.add_argument(
        "--batch",
        action="store_true",
        help="Generate the full corpus via the Batches API (half price, async).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        help="Generate only this many sentences, synchronously, and print them.",
    )
    parser.add_argument(
        "--levels",
        type=int,
        nargs="+",
        choices=range(1, 7),
        help="Restrict to these HSK levels.",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write the plists even for a --limit pilot (default: just print).",
    )
    args = parser.parse_args(argv)
    if not args.batch and not args.limit:
        parser.error("pass --limit N for a pilot or --batch for the full run.")
    if not os.environ.get("ANTHROPIC_API_KEY"):
        parser.error(
            "ANTHROPIC_API_KEY is not set (source it from 1Password, e.g. `op run`)."
        )
    return args


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
