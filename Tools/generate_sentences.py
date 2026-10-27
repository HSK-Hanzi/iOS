#!/usr/bin/env python3
"""Generate Zili's practice-sentence library with the Claude API.

The library is written word by word: every headword of the three HSK syllabi gets a handful of
original example sentences, written for the band the word is taught at, then checked, leveled in all
three standards, and merged with the sentences already shipped. One subcommand per stage:

  - ``words pilot`` — a few requests across the bands, synchronously, to read and to price.
  - ``words submit --yes`` — every word not yet generated, through the Batches API (half price).
  - ``review pilot`` / ``review submit --yes`` — a second model's read of every sentence that passed
    the checks; a sentence it rejects is dropped.
  - ``fetch [--wait]`` — downloads the results of submitted batches.
  - ``assemble [--write]`` — checks, levels, and dedupes everything generated (see
    ``sentence_library``), reports what it kept, and with ``--write`` writes the corpora.
  - ``cost`` — what every request so far has cost.

Every request and result is kept in ``Tools/.cache/sentences/`` — a batch's id is written down before
anything else happens — so an interrupted run resumes instead of paying twice, and ``submit`` skips any
request that already succeeded.

Credentials come from ``ANTHROPIC_API_KEY`` (source it from 1Password with ``op run``).
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import plistlib
import random
import subprocess
import sys
import time
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import anthropic
from anthropic.types.message_create_params import MessageCreateParamsNonStreaming
from anthropic.types.messages.batch_create_params import Request

import sentence_library as library

WRITER_MODEL = "claude-opus-5-5"
REVIEWER_MODEL = "claude-sonnet-5-5"

# Dollars per million tokens: input, output, cache read. A cache write costs 1.25× input.
PRICES = {
    "claude-opus-5-5": (4.00, 20.00, 0.20),
    "claude-sonnet-5-5": (2.00, 10.00, 0.20),
}
BATCH_DISCOUNT = 0.5
# Seconds a synchronous request may run: long enough for the largest outputs, which the SDK would
# otherwise refuse to wait for without streaming.
SYNC_TIMEOUT = 1800

REPO = Path(__file__).resolve().parent.parent
OPEN = REPO / "Data" / "Open"
PROPRIETARY = REPO / "Data" / "Proprietary"
CACHE = Path(__file__).resolve().parent / ".cache" / "sentences"

PRACTICE_SENTENCES = OPEN / "PracticeSentences.plist"
HSK_SENTENCES = PROPRIETARY / "HSKSentences.plist"
WORKBOOK_GRAMMAR = PROPRIETARY / "WorkbookGrammar.json"

TARGETS_PER_REQUEST = 5
SENTENCES_PER_WORD = {1: 12, 2: 12, 3: 12, 4: 8, 5: 8, 6: 8, 7: 5}
REVIEWS_PER_REQUEST = 25
# The request kinds whose results are new sentences: words' examples, and grammar points'
# (``generate_grammar.py examples``).
GENERATED_KINDS = {"words", "grammar-examples"}
# Bands whose whole vocabulary is short enough to list in the prompt.
LISTED_VOCABULARY_BANDS = {1, 2, 3}
# Bands whose prompts list the workbook grammar to practice.
GRAMMAR_BANDS = {1, 2, 3}

WORDS_SYSTEM = """\
You write original example sentences for learners of Mandarin Chinese preparing for HSK 3.0, whose \
bands run from 1 (beginner) to 7 (advanced; levels 7–9).

For each target word you are given, write the requested number of sentences. Every sentence must:
- use the target word in a common, natural sense (spread the sentences across its common senses);
- be natural, self-contained, standard Mandarin in simplified characters, the kind of thing a native \
speaker would actually say or write;
- use only vocabulary and grammar a learner at the given band knows, besides the target word itself;
- write numbers in Chinese characters, with no Arabic digits, Latin letters or brand names;
- end with 。, ？ or ！.

Across the set, vary the topic, the subject, the sentence type (statements, questions, short spoken \
replies, exclamations) and the length, and never reuse one template with words swapped. Avoid proper \
names unless the sentence needs one, and then use a common one such as 小王 or 李老师.

Fields for each sentence:
- `target`: the target word, exactly as given.
- `hanzi`: the sentence, with its punctuation.
- `words`: the sentence's characters only (no punctuation), split into words with "/"; prefix a \
proper name with "*", e.g. "*小王/在/家/吗".
- `pinyin`: numbered pinyin for the same words, "/" between words and a space between the syllables \
of a word, e.g. "xiao3 wang2/zai4/jia1/ma5". Mark every syllable 1–5 (5 = neutral tone). Write ü \
as "u:". Write an erhua 儿 as its own syllable "r5". Write 一 and 不 with the tone they are spoken \
with in context; never apply third-tone sandhi.
- `translation`: a natural, concise English translation.
- `topic`: one or two lowercase English words, such as "food" or "travel".
- `grammar`: when the sentence uses one of the structures listed for the band, that structure \
exactly as listed; otherwise "".\
"""

REVIEW_SYSTEM = """\
You check example sentences written for learners of Mandarin Chinese. For every sentence given, \
decide whether it may be shown to learners. Reject it when any of these is true:
- it is ungrammatical, unidiomatic, or something a native speaker would not say;
- the English translation misstates its meaning;
- its numbered pinyin is wrong for any character: a wrong tone, the wrong reading of a polyphone, or a \
neutral tone where one doesn't belong. (一 and 不 are written with the tone spoken in context, third \
tone sandhi is never written, and an erhua 儿 is "r5".)
- it is offensive, or culturally or factually wrong.

Reject only a definite error. A reading with an accepted standard variant is correct — a neutral \
tone on the second syllable of words like 漂亮, 困难, 这个 or 多少, or a full tone there instead. \
A translation that is accurate but could be worded better is correct.

For every id, first write `problem`: the definite error, or "" when there is none. Then set `ok` \
to whether `problem` is empty.\
"""

WORDS_SCHEMA = {
    "type": "object",
    "properties": {
        "sentences": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    field: {"type": "string"}
                    for field in (
                        "target",
                        "hanzi",
                        "words",
                        "pinyin",
                        "translation",
                        "topic",
                        "grammar",
                    )
                },
                "required": [
                    "target",
                    "hanzi",
                    "words",
                    "pinyin",
                    "translation",
                    "topic",
                    "grammar",
                ],
                "additionalProperties": False,
            },
        }
    },
    "required": ["sentences"],
    "additionalProperties": False,
}

REVIEW_SCHEMA = {
    "type": "object",
    "properties": {
        "verdicts": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "problem": {"type": "string"},
                    "ok": {"type": "boolean"},
                },
                "required": ["id", "problem", "ok"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["verdicts"],
    "additionalProperties": False,
}


def main(argv: list[str]) -> int:
    args = parse_arguments(argv)
    return args.run(args)


# MARK: Source data


@dataclass
class Sources:
    """Everything the stages read: the syllabi, readings, workbook sentences and grammar, and the
    sentences already shipped."""

    vocabulary: dict
    syllabi: dict[str, library.Syllabus]
    readings: library.Readings
    lexicon: set[str]
    practice: list[dict]
    workbook: list[dict]
    grammar: dict[int, list[str]]

    @classmethod
    def load(cls) -> Sources:
        vocabulary = entries(OPEN / "HSKVocabulary.plist")
        dictionary = entries(OPEN / "CEDICT.plist")
        return cls(
            vocabulary=vocabulary,
            syllabi=library.syllabi(vocabulary),
            readings=library.Readings.build(entries(OPEN / "CharacterReadings.plist"), dictionary),
            lexicon=set(dictionary) | set(vocabulary),
            practice=committed_entries(PRACTICE_SENTENCES),
            workbook=committed_entries(HSK_SENTENCES) if HSK_SENTENCES.exists() else [],
            grammar=workbook_grammar(),
        )

    def targets_by_band(self) -> dict[int, list[str]]:
        """Every headword written entirely in Hanzi, by the band it is generated for."""
        bands: dict[int, list[str]] = defaultdict(list)
        for word in sorted(self.vocabulary):
            band = library.generation_band(word, self.syllabi)
            if band and library.han_only(word) == word:
                bands[band].append(word)
        return bands

    def known_words(self, band: int) -> list[str]:
        """The HSK 3.0 (2026) words taught at `band` or below."""
        return sorted(w for w, b in self.syllabi["newest"].bands.items() if b <= band)

    def structures(self, band: int) -> list[str]:
        """The workbook grammar taught at `band` or below, for the bands where it is still being
        learned; past them it is assumed."""
        if band not in GRAMMAR_BANDS:
            return []
        return [s for level, items in sorted(self.grammar.items()) if level <= band for s in items]

    def workbook_examples(self, band: int, count: int, seed: str) -> list[str]:
        level = min(band, 6)
        pool = [e["hanzi"] for e in self.workbook if workbook_level(e) == level]
        return random.Random(seed).sample(pool, min(count, len(pool)))


def entries(path: Path):
    return plistlib.loads(path.read_bytes())["entries"]


def committed_entries(path: Path):
    """The entries of `path` as its submodule last committed it — the corpus already shipped, which
    ``assemble --write`` replaces in the working tree and must not then read back as its baseline."""
    committed = subprocess.run(
        ["git", "-C", str(path.parent), "cat-file", "--filters", f"HEAD:{path.name}"],
        capture_output=True,
        check=True,
    ).stdout
    return plistlib.loads(committed)["entries"]


def workbook_level(entry: dict) -> int | None:
    """The HSK 2.0 level a workbook sentence is taught at."""
    return entry.get("level") or entry.get("levels", {}).get("old")


def workbook_grammar() -> dict[int, list[str]]:
    if not WORKBOOK_GRAMMAR.exists():
        return {}
    document = json.loads(WORKBOOK_GRAMMAR.read_text())
    return {
        int(level): [lesson["structure"] for lesson in lessons]
        for level, lessons in document["levels"].items()
    }


# MARK: Requests


@dataclass(frozen=True)
class PlannedRequest:
    custom_id: str
    kind: str
    model: str
    system: list[dict]
    prompt: str
    schema: dict
    metadata: dict
    max_tokens: int = 16000

    def params(self, effort: str) -> dict:
        return {
            "model": self.model,
            "max_tokens": self.max_tokens,
            "system": self.system,
            "output_config": {
                "effort": effort,
                "format": {"type": "json_schema", "schema": self.schema},
            },
            "messages": [{"role": "user", "content": self.prompt}],
        }


def word_requests(sources: Sources, per_word: dict[int, int]) -> list[PlannedRequest]:
    """One request per group of target words, every band, in a fixed shuffled order so each group
    mixes words from across the alphabet."""
    planned = []
    for band, words in sorted(sources.targets_by_band().items()):
        system = [
            {"type": "text", "text": WORDS_SYSTEM},
            {
                "type": "text",
                "text": band_guide(sources, band),
                "cache_control": {"type": "ephemeral"},
            },
        ]
        shuffled = words[:]
        random.Random(f"band-{band}").shuffle(shuffled)
        for start in range(0, len(shuffled), TARGETS_PER_REQUEST):
            targets = shuffled[start : start + TARGETS_PER_REQUEST]
            custom_id = f"w{band}-{library.content_id('|'.join(targets))}"
            planned.append(
                PlannedRequest(
                    custom_id=custom_id,
                    kind="words",
                    model=WRITER_MODEL,
                    system=system,
                    prompt=words_prompt(sources, band, targets, per_word[band], custom_id),
                    schema=WORDS_SCHEMA,
                    metadata={"band": band, "targets": targets},
                )
            )
    return planned


def band_guide(sources: Sources, band: int) -> str:
    low, high = library.LENGTH_BOUNDS[band]
    lines = [
        f"Band: {band}.",
        f"Keep each sentence between {low} and {high} characters, most of them nearer the short end.",
    ]
    if band in LISTED_VOCABULARY_BANDS:
        lines.append(
            "Besides the target word, use only these words (and names and numbers): "
            + "、".join(sources.known_words(band))
        )
    else:
        lines.append(
            f"Besides the target word, use common vocabulary from HSK 3.0 band {band} and below."
        )
    if structures := sources.structures(band):
        lines.append("Structures learners at this band know: " + "; ".join(structures))
    return "\n".join(lines)


def words_prompt(sources: Sources, band: int, targets: list[str], count: int, seed: str) -> str:
    lines = [f"Write {count} sentences for each of these target words:"]
    lines += [f"- {target}" for target in targets]
    if examples := sources.workbook_examples(band, 3, seed):
        lines.append(
            "For the difficulty and register only — never copy or paraphrase them — "
            "here are textbook sentences at this level:"
        )
        lines += [f"  {example}" for example in examples]
    return "\n".join(lines)


def review_requests(candidates: list[dict]) -> list[PlannedRequest]:
    planned = []
    for start in range(0, len(candidates), REVIEWS_PER_REQUEST):
        group = candidates[start : start + REVIEWS_PER_REQUEST]
        ids = [c["id"] for c in group]
        prompt = "\n".join(
            json.dumps(
                {
                    "id": c["id"],
                    "hanzi": c["hanzi"],
                    "pinyin": c["numberedPinyin"],
                    "translation": c["translation"],
                },
                ensure_ascii=False,
            )
            for c in group
        )
        planned.append(
            PlannedRequest(
                custom_id=f"r-{library.content_id('|'.join(ids))}",
                kind="review",
                model=REVIEWER_MODEL,
                system=[{"type": "text", "text": REVIEW_SYSTEM}],
                prompt=prompt,
                schema=REVIEW_SCHEMA,
                metadata={"ids": ids},
            )
        )
    return planned


# MARK: Cache


class Cache:
    """The on-disk record of every request made and every result received, append-only."""

    def __init__(self, root: Path = CACHE) -> None:
        self.root = root
        (root / "results").mkdir(parents=True, exist_ok=True)

    @property
    def batches_file(self) -> Path:
        return self.root / "batches.jsonl"

    def append(self, path: Path, records) -> None:
        with path.open("a") as file:
            for record in records:
                file.write(json.dumps(record, ensure_ascii=False) + "\n")

    def record_requests(self, planned: list[PlannedRequest], effort: str) -> None:
        self.append(
            self.root / "requests.jsonl",
            (
                {
                    "custom_id": p.custom_id,
                    "kind": p.kind,
                    "effort": effort,
                    **p.metadata,
                }
                for p in planned
            ),
        )

    def requests(self) -> dict[str, dict]:
        return {r["custom_id"]: r for r in read_jsonl(self.root / "requests.jsonl")}

    def record_batch(self, batch_id: str, kind: str, count: int) -> None:
        self.append(
            self.batches_file,
            [{"id": batch_id, "kind": kind, "count": count, "created": now()}],
        )

    def batches(self) -> list[dict]:
        return read_jsonl(self.batches_file)

    def results_file(self, name: str) -> Path:
        return self.root / "results" / f"{name}.jsonl"

    def results(self) -> list[dict]:
        """Every result received, oldest first, so a later retry supersedes an earlier failure."""
        files = sorted(self.root.glob("results/*.jsonl"), key=lambda p: p.stat().st_mtime)
        return [record for path in files for record in read_jsonl(path)]

    def succeeded(self) -> dict[str, dict]:
        """The latest successful result for each custom id."""
        return {r["custom_id"]: r for r in self.results() if r["status"] == "succeeded"}


def read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


def result_record(
    custom_id: str, model: str, message=None, *, batch: bool, error: str = ""
) -> dict:
    """A result as kept on disk: its status, parsed output, and token usage."""
    record = {
        "custom_id": custom_id,
        "model": model,
        "batch": batch,
        "status": "errored",
        "error": error,
    }
    if message is None:
        return record
    record["usage"] = message.usage.model_dump(mode="json")
    if message.stop_reason in ("refusal", "max_tokens"):
        record["error"] = message.stop_reason
        return record
    text = next((block.text for block in message.content if block.type == "text"), "")
    try:
        record["output"] = json.loads(text)
        record["status"] = "succeeded"
    except json.JSONDecodeError:
        record["error"] = "unparseable output"
    return record


# MARK: Running


def run_sync(client, cache: Cache, planned: list[PlannedRequest], effort: str) -> list[dict]:
    """Runs requests concurrently at full price, recording each result as it arrives."""
    cache.record_requests(planned, effort)
    path = cache.results_file(f"sync-{planned[0].kind}-{int(time.time())}")

    def run(request: PlannedRequest) -> dict:
        try:
            message = client.with_options(timeout=SYNC_TIMEOUT).messages.create(
                **request.params(effort)
            )
            return result_record(request.custom_id, request.model, message, batch=False)
        except anthropic.APIError as error:
            return result_record(request.custom_id, request.model, batch=False, error=str(error))

    records = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for record in pool.map(run, planned):
            cache.append(path, [record])
            records.append(record)
            print(
                f"  {record['custom_id']}: {record['status']} {record['error']}",
                file=sys.stderr,
            )
    return records


def submit_batch(client, cache: Cache, planned: list[PlannedRequest], effort: str) -> str:
    cache.record_requests(planned, effort)
    batch = client.messages.batches.create(
        requests=[
            Request(
                custom_id=p.custom_id,
                params=MessageCreateParamsNonStreaming(**p.params(effort)),
            )
            for p in planned
        ]
    )
    cache.record_batch(batch.id, planned[0].kind, len(planned))
    print(f"Submitted batch {batch.id} ({len(planned)} requests).", file=sys.stderr)
    return batch.id


def fetch(client, cache: Cache, *, wait: bool) -> None:
    """Downloads the results of every ended batch not yet downloaded, polling when `wait`."""
    pending = [b for b in cache.batches() if not cache.results_file(b["id"]).exists()]
    while pending:
        for record in pending[:]:
            try:
                if download(client, cache, record):
                    pending.remove(record)
            except anthropic.APIConnectionError as error:
                print(f"  {record['id']}: {error}; retrying.", file=sys.stderr)
        if pending and wait:
            time.sleep(60)
        elif pending:
            return


def download(client, cache: Cache, record: dict) -> bool:
    """Reports a batch's progress and, once it has ended, saves its results. Whether it ended."""
    batch = client.messages.batches.retrieve(record["id"])
    counts = batch.request_counts
    print(
        f"  {batch.id}: {batch.processing_status} — {counts.succeeded} succeeded, "
        f"{counts.errored} errored, {counts.processing} processing",
        file=sys.stderr,
    )
    if batch.processing_status != "ended":
        return False
    model = WRITER_MODEL if record["kind"] == "words" else REVIEWER_MODEL
    results = [
        result_record(r.custom_id, model, r.result.message, batch=True)
        if r.result.type == "succeeded"
        else result_record(r.custom_id, model, batch=True, error=r.result.type)
        for r in client.messages.batches.results(batch.id)
    ]
    partial = cache.results_file(f"{batch.id}.partial")
    partial.unlink(missing_ok=True)
    cache.append(partial, results)
    partial.rename(cache.results_file(batch.id))
    return True


# MARK: Cost


def cost(record: dict) -> float:
    usage = record.get("usage")
    if not usage:
        return 0.0
    input_price, output_price, read_price = PRICES[record["model"]]
    dollars = (
        usage.get("input_tokens", 0) * input_price
        + (usage.get("cache_creation_input_tokens") or 0) * input_price * 1.25
        + (usage.get("cache_read_input_tokens") or 0) * read_price
        + usage.get("output_tokens", 0) * output_price
    ) / 1_000_000
    return dollars * (BATCH_DISCOUNT if record.get("batch") else 1)


def report_cost(cache: Cache) -> None:
    by_kind: Counter = Counter()
    requests = cache.requests()
    for record in cache.results():
        kind = requests.get(record["custom_id"], {}).get("kind", "?")
        by_kind[(kind, "batch" if record.get("batch") else "sync")] += cost(record)
    for (kind, mode), dollars in sorted(by_kind.items()):
        print(f"  {kind:7} {mode:5} ${dollars:8.2f}")
    print(f"  total         ${sum(by_kind.values()):8.2f}")


# MARK: Assembly


@dataclass
class Assembly:
    kept: list[dict]
    candidates: list[dict]
    rejections: Counter
    unreviewed: int


def assemble(sources: Sources, cache: Cache) -> Assembly:
    """Every sentence that may ship: the ones already shipped, then each generated sentence that
    passes the checks, isn't a copy of a workbook or earlier sentence, and wasn't rejected in review."""
    requests = cache.requests()
    succeeded = cache.succeeded()
    verdicts = {
        verdict["id"]: verdict
        for custom_id, record in succeeded.items()
        if requests.get(custom_id, {}).get("kind") == "review"
        for verdict in record["output"]["verdicts"]
    }
    near_copies = library.NearCopyIndex(e["hanzi"] for e in sources.workbook)
    rejections: Counter = Counter()

    kept = [existing_entry(e, sources) for e in sources.practice]
    seen_text = {library.han_only(e["hanzi"]) for e in kept}
    seen_words = {tuple(e["words"]) for e in kept}

    candidates = []
    for custom_id, record in sorted(succeeded.items()):
        request = requests.get(custom_id, {})
        if request.get("kind") not in GENERATED_KINDS:
            continue
        for sentence in record["output"]["sentences"]:
            entry, reason = generated_entry(sentence, request, sources, near_copies)
            if not reason and (point := request.get("point")):
                entry["grammarPoints"] = [point]
            text = library.han_only(sentence["hanzi"])
            if not reason and text in seen_text:
                reason = "duplicate"
            if not reason and tuple(entry["words"]) in seen_words:
                reason = "same words as another sentence"
            if reason:
                rejections[reason] += 1
                continue
            seen_text.add(text)
            seen_words.add(tuple(entry["words"]))
            candidates.append(entry)

    reviewed = [c for c in candidates if c["id"] in verdicts]
    rejections["rejected in review"] = sum(1 for c in reviewed if not verdicts[c["id"]]["ok"])
    kept += [c for c in candidates if verdicts.get(c["id"], {"ok": True})["ok"]]
    attach_grammar_points(kept, requests, succeeded)
    return Assembly(kept, candidates, rejections, len(candidates) - len(reviewed))


def attach_grammar_points(kept: list[dict], requests: dict, succeeded: dict) -> None:
    """Records on each entry the grammar points ``generate_grammar.py tag`` found it uses."""
    found = {
        tagged["id"]: tagged["points"]
        for custom_id, record in succeeded.items()
        if requests.get(custom_id, {}).get("kind") == "grammar-tag"
        for tagged in record["output"]["sentences"]
    }
    for entry in kept:
        if points := found.get(entry["id"]):
            entry["grammarPoints"] = points


def existing_entry(entry: dict, sources: Sources) -> dict:
    """An already-shipped sentence, leveled, under its original id and keeping what it records —
    segmented locally only if it came without a segmentation."""
    if "words" in entry:
        sentence_tokens = [library.Token(word) for word in entry["words"]]
    else:
        sentence_tokens = library.segment(entry["hanzi"], sources.lexicon, 7)
    kept = {k: v for k, v in entry.items() if k in ("target", "topic", "grammarPoints")}
    return {
        "id": entry["id"],
        "hanzi": entry["hanzi"],
        "numberedPinyin": entry["numberedPinyin"],
        "translation": library.smart_quotes(entry["translation"]),
        "words": [token.text for token in sentence_tokens],
        "levels": library.levels(sentence_tokens, sources.syllabi),
        **kept,
    }


def generated_entry(sentence: dict, request: dict, sources: Sources, near_copies):
    """A generated sentence as a corpus entry, with the reason to drop it if there is one. A
    sentence no syllabus levels is dropped, unless it was written for a grammar point — whose word
    the syllabi may not list — where it serves that point's page while no level lists it."""
    band = request["band"]
    found = library.problems(
        hanzi=sentence["hanzi"],
        words=sentence["words"],
        pinyin=sentence["pinyin"],
        band=band,
        target=sentence["target"],
        readings=sources.readings,
    )
    if found:
        return None, reason_category(found[0])
    if near_copies.is_near_copy(sentence["hanzi"]):
        return None, "near copy of a workbook sentence"
    sentence_tokens = library.tokens(sentence["words"])
    levels = library.levels(sentence_tokens, sources.syllabi)
    if not levels and not request.get("point"):
        return None, "outside every syllabus"
    entry = {
        "id": library.content_id(sentence["hanzi"].strip()),
        "hanzi": sentence["hanzi"].strip(),
        "numberedPinyin": library.numbered_pinyin(sentence["pinyin"]),
        "translation": library.smart_quotes(sentence["translation"].strip()),
        "words": [token.text for token in sentence_tokens],
        "levels": levels,
        "band": band,
    }
    for field in ("target", "topic"):
        if value := sentence.get(field, "").strip():
            entry[field] = value
    return entry, None


def reason_category(problem: str) -> str:
    """Groups a problem message into a category for the report."""
    for marker, category in (
        (" isn't read ", "pinyin reading"),
        ("doesn't fit", "pinyin shape"),
        ("word counts", "pinyin shape"),
        ("characters, outside", "length"),
        ("target word", "missing target"),
        ("Latin", "Latin letters or digits"),
        ("segmentation", "segmentation"),
    ):
        if marker in problem:
            return category
    return problem


def report(assembly: Assembly, verbose_samples: int = 0) -> None:
    print(
        f"Kept {len(assembly.kept)} sentences; {len(assembly.candidates)} generated passed the checks."
    )
    print(f"Awaiting review: {assembly.unreviewed}")
    for reason, count in assembly.rejections.most_common():
        print(f"  dropped {count:6} — {reason}")
    for standard in library.STANDARDS:
        counts = Counter(e["levels"].get(standard) for e in assembly.kept)
        bands = "  ".join(f"{level}:{counts[level]}" for level in sorted(k for k in counts if k))
        print(f"  {standard:7} {bands}  unleveled:{counts[None]}")
    for entry in random.Random(0).sample(
        assembly.candidates, min(verbose_samples, len(assembly.candidates))
    ):
        print(
            f"\nband {entry['band']} [{entry['target']}] {entry['levels']}  {entry.get('grammar', '')}"
        )
        print(f"  {entry['hanzi']}\n  {entry['numberedPinyin']}\n  {entry['translation']}")


def write(assembly: Assembly, sources: Sources) -> None:
    shipped = [{k: v for k, v in e.items() if k != "band"} for e in assembly.kept]
    write_plist(
        PRACTICE_SENTENCES,
        shipped,
        name="Zili Practice Sentences",
        description="Original practice sentences generated for Zili, leveled in each HSK standard.",
    )
    if sources.workbook:
        write_plist(
            HSK_SENTENCES,
            [existing_entry(e, sources) for e in sources.workbook],
            name="HSK Standard Course Sentences",
            description="Practice sentences extracted from the HSK Standard Course workbooks. "
            "Copyrighted; bundled in Debug builds only.",
        )


def write_plist(path: Path, entries_: list[dict], *, name: str, description: str) -> None:
    """Writes the corpus in the order given, which the app lists each level in — so the sentences
    already shipped lead their levels, ahead of the generated ones."""
    document = {"meta": {"name": name, "description": description}, "entries": entries_}
    path.write_bytes(plistlib.dumps(document, fmt=plistlib.FMT_BINARY))
    print(f"Wrote {len(entries_)} entries → {path.relative_to(REPO)}", file=sys.stderr)


# MARK: Commands


def words_command(args) -> int:
    sources = Sources.load()
    cache = Cache()
    per_word = SENTENCES_PER_WORD | dict(args.per_word or {})
    planned = word_requests(sources, per_word)
    done = cache.succeeded()
    remaining = [p for p in planned if p.custom_id not in done]
    print(
        f"{len(planned)} requests planned; {len(remaining)} not yet generated.",
        file=sys.stderr,
    )
    if args.action == "pilot":
        sample = pilot_sample(remaining, args.requests, args.seed)
        records = run_sync(anthropic.Anthropic(), cache, sample, args.effort)
        project(records, sample, remaining)
        return 0
    return submit(args, cache, remaining)


def review_command(args) -> int:
    sources = Sources.load()
    cache = Cache()
    done = cache.succeeded()
    reviewed = {
        i
        for r in cache.requests().values()
        if r["kind"] == "review" and r["custom_id"] in done
        for i in r["ids"]
    }
    candidates = [c for c in assemble(sources, cache).candidates if c["id"] not in reviewed]
    random.Random(1).shuffle(candidates)
    planned = review_requests(candidates)
    print(
        f"{len(candidates)} sentences to review in {len(planned)} requests.",
        file=sys.stderr,
    )
    if args.action == "pilot":
        sample = planned[: args.requests]
        records = run_sync(anthropic.Anthropic(), cache, sample, args.effort)
        project(records, sample, planned)
        return 0
    return submit(args, cache, planned)


def submit(args, cache: Cache, planned: list[PlannedRequest]) -> int:
    if not planned:
        print("Nothing to submit.", file=sys.stderr)
        return 0
    if not args.yes:
        print("Re-run with --yes to submit.", file=sys.stderr)
        return 1
    client = anthropic.Anthropic()
    submit_batch(client, cache, planned, args.effort)
    fetch(client, cache, wait=True)
    return 0


def pilot_sample(planned: list[PlannedRequest], count: int, seed: int) -> list[PlannedRequest]:
    """`count` requests spread evenly over the bands."""
    by_band: dict[int, list[PlannedRequest]] = defaultdict(list)
    for request in planned:
        by_band[request.metadata.get("band", 0)].append(request)
    generator = random.Random(seed)
    per_band = max(1, count // len(by_band))
    return [
        r
        for band in sorted(by_band)
        for r in generator.sample(by_band[band], min(per_band, len(by_band[band])))
    ]


def project(
    records: list[dict], sample: list[PlannedRequest], remaining: list[PlannedRequest]
) -> None:
    """Prices the pilot and what running every remaining request as a batch would cost."""
    spent = sum(map(cost, records))
    by_band = defaultdict(list)
    bands = {p.custom_id: p.metadata.get("band", 0) for p in sample}
    for record in records:
        by_band[bands[record["custom_id"]]].append(cost(record) * BATCH_DISCOUNT)
    remaining_by_band = Counter(p.metadata.get("band", 0) for p in remaining)
    projected = sum(
        remaining_by_band[band] * (sum(costs) / len(costs)) for band, costs in by_band.items()
    )
    failures = sum(1 for r in records if r["status"] != "succeeded")
    print(f"\nPilot: {len(records)} requests, {failures} failed, ${spent:.2f} spent.")
    print(f"Projected batch cost of all {len(remaining)} remaining requests: ${projected:.2f}")


def assemble_command(args) -> int:
    sources = Sources.load()
    assembly = assemble(sources, Cache())
    report(assembly, args.samples)
    if args.write:
        write(assembly, sources)
    return 0


def fetch_command(args) -> int:
    fetch(anthropic.Anthropic(), Cache(), wait=args.wait)
    return 0


def cost_command(args) -> int:
    report_cost(Cache())
    return 0


def parse_arguments(argv):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    commands = parser.add_subparsers(required=True)

    for name, run, default_effort in (
        ("words", words_command, "low"),
        ("review", review_command, "low"),
    ):
        command = commands.add_parser(name)
        command.set_defaults(run=run)
        command.add_argument("action", choices=("pilot", "submit"))
        command.add_argument(
            "--requests",
            type=int,
            default=35,
            help="Pilot size (default: %(default)s).",
        )
        command.add_argument("--seed", type=int, default=0, help="Picks the pilot sample.")
        command.add_argument("--effort", default=default_effort, choices=("low", "medium", "high"))
        command.add_argument("--yes", action="store_true", help="Actually submit the batch.")
        if name == "words":
            command.add_argument(
                "--per-word",
                type=lambda text: [tuple(map(int, pair.split("="))) for pair in text.split(",")],
                help="Override sentences per word by band, e.g. 1=10,7=2.",
            )

    command = commands.add_parser("fetch")
    command.set_defaults(run=fetch_command)
    command.add_argument("--wait", action="store_true")

    command = commands.add_parser("assemble")
    command.set_defaults(run=assemble_command)
    command.add_argument("--write", action="store_true")
    command.add_argument("--samples", type=int, default=0, help="Print this many kept sentences.")

    commands.add_parser("cost").set_defaults(run=cost_command)

    return parser.parse_args(argv)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
