#!/usr/bin/env python3
"""List the HSK 3.0 grammar points and tag Zili's practice sentences with the ones they use.

Two stages, sharing ``generate_sentences``' request cache, batching, and pricing:

  - ``list`` — writes ``GrammarPoints.plist``: for each HSK 3.0 level, 1 through 7 (7 being levels
    7–9), the grammar points the HSK 3.0 grammar outline introduces there, each with a name, its
    pattern, and a short explanation in Zili's own words. One synchronous request per level, each
    shown the points already listed so none repeats.
  - ``tag pilot`` / ``tag submit --yes`` — has a model read the practice sentences in groups and
    name the grammar points each one uses, choosing among the points of the sentence's own level
    and the level below, so each point is illustrated by sentences about its level.
  - ``examples`` — writes example sentences for every point no sentence uses, one synchronous
    request per point; they are checked and reviewed like any other generated sentence.

``generate_sentences.py assemble --write`` attaches the tags to the corpus it writes.
"""

from __future__ import annotations

import argparse
import json
import plistlib
import random
import sys
from collections import defaultdict

import anthropic

import generate_sentences as sentences
from generate_sentences import Cache, PlannedRequest

GRAMMAR_POINTS = sentences.OPEN / "GrammarPoints.plist"
LEVELS = range(1, 8)
SENTENCES_PER_REQUEST = 25
EXAMPLES_PER_POINT = 8
# Room for a level's whole list, which runs to over a hundred points at the top levels.
LIST_MAX_TOKENS = 64000

LIST_SYSTEM = """\
You are an expert teacher of Mandarin Chinese grammar writing a reference for learners preparing \
for HSK 3.0, whose levels run from 1 (beginner) to 7 (advanced; levels 7–9).

List the grammar points the HSK 3.0 grammar outline introduces at the level you are given: \
sentence patterns, function words and the structures they form, complements, aspect markers, and \
the like. List each point once, at the level it is introduced, and leave out any point already \
listed at a lower level (you will be shown those). Give each point:
- `name`: a short name a learner would recognize, leading with its Chinese, e.g. "把 sentences", \
"越来越 + adjective", "是……的 for emphasis".
- `pattern`: its structure, e.g. "Subject + 把 + Object + Verb + Complement".
- `explanation`: two or three plain English sentences on what it means and how it is used, \
written for a learner at this level, in your own words.

Return only the structured object.\
"""

LIST_SCHEMA = {
    "type": "object",
    "properties": {
        "points": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "pattern": {"type": "string"},
                    "explanation": {"type": "string"},
                },
                "required": ["name", "pattern", "explanation"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["points"],
    "additionalProperties": False,
}

TAG_SYSTEM = """\
You tag example sentences for learners of Mandarin Chinese with the grammar points they \
illustrate. You are given a list of grammar points, each with an id, and a list of sentences, \
each with an id.

For every sentence, list the ids of the points it clearly uses: every element of the point's \
pattern appears in the sentence, working as that grammar, and a learner studying the point would \
find the sentence a good example of it. A pattern's characters inside an ordinary word don't count \
— 超出 is a word, not the complement 出来 — and half a paired pattern doesn't count — 先 without \
再 or 然后 is not 先……再. When in doubt, leave the point out; an empty list is fine.

Return a result for every sentence id.\
"""

TAG_SCHEMA = {
    "type": "object",
    "properties": {
        "sentences": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "points": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["id", "points"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["sentences"],
    "additionalProperties": False,
}


def main(argv: list[str]) -> int:
    args = parse_arguments(argv)
    return args.run(args)


# MARK: Listing


def list_command(args) -> int:
    client = anthropic.Anthropic()
    cache = Cache()
    points: list[dict] = []
    for level in LEVELS:
        request = list_request(level, points)
        [record] = sentences.run_sync(client, cache, [request], args.effort)
        if record["status"] != "succeeded":
            print(f"Level {level} failed: {record['error']}", file=sys.stderr)
            return 1
        listed = record["output"]["points"]
        points += [
            {"id": f"g{level}-{index:03}", "level": level, **point}
            for index, point in enumerate(listed, start=1)
        ]
        print(f"Level {level}: {len(listed)} points.", file=sys.stderr)
    write_points(points)
    sentences.report_cost(cache)
    return 0


def list_request(level: int, earlier: list[dict]) -> PlannedRequest:
    prompt = [f"Level: {level}"]
    if earlier:
        prompt.append("Already listed at lower levels:")
        prompt += [f"- {point['name']}" for point in earlier]
    return PlannedRequest(
        custom_id=f"grammar-list-{level}",
        kind="grammar-list",
        model=sentences.WRITER_MODEL,
        system=[{"type": "text", "text": LIST_SYSTEM}],
        prompt="\n".join(prompt),
        schema=LIST_SCHEMA,
        metadata={"level": level},
        max_tokens=LIST_MAX_TOKENS,
    )


def write_points(points: list[dict]) -> None:
    document = {
        "meta": {
            "name": "Zili Grammar Points",
            "description": "The grammar points of each HSK 3.0 level, explained for Zili.",
        },
        "entries": points,
    }
    GRAMMAR_POINTS.write_bytes(plistlib.dumps(document, fmt=plistlib.FMT_BINARY))
    print(f"Wrote {len(points)} points → {GRAMMAR_POINTS.relative_to(sentences.REPO)}")


def grammar_points() -> list[dict]:
    return plistlib.loads(GRAMMAR_POINTS.read_bytes())["entries"]


# MARK: Tagging


def tag_command(args) -> int:
    source = sentences.Sources.load()
    cache = Cache()
    corpus = sentences.assemble(source, cache).kept
    done = cache.succeeded()
    tagged = {
        sentence_id
        for request in cache.requests().values()
        if request["kind"] == "grammar-tag" and request["custom_id"] in done
        for sentence_id in request["ids"]
    }
    planned = tag_requests([e for e in corpus if e["id"] not in tagged], grammar_points())
    print(f"{len(planned)} tagging requests not yet run.", file=sys.stderr)
    if args.action == "pilot":
        sample = sentences.pilot_sample(planned, args.requests, args.seed)
        records = sentences.run_sync(anthropic.Anthropic(), cache, sample, args.effort)
        sentences.project(records, sample, planned)
        return 0
    return sentences.submit(args, cache, planned)


def tag_requests(corpus: list[dict], points: list[dict]) -> list[PlannedRequest]:
    """One request per group of sentences at the same HSK 3.0 (2026) level, offered the points of
    that level and the one below; sentences that level doesn't place are left untagged."""
    by_level: dict[int, list[dict]] = defaultdict(list)
    for entry in corpus:
        if level := entry.get("levels", {}).get("newest"):
            by_level[level].append(entry)
    planned = []
    for level, group in sorted(by_level.items()):
        offered = [p for p in points if level - 1 <= p["level"] <= level]
        system = [
            {"type": "text", "text": TAG_SYSTEM},
            {"type": "text", "text": points_text(offered), "cache_control": {"type": "ephemeral"}},
        ]
        random.Random(f"tag-{level}").shuffle(group)
        for start in range(0, len(group), SENTENCES_PER_REQUEST):
            chunk = group[start : start + SENTENCES_PER_REQUEST]
            ids = [e["id"] for e in chunk]
            planned.append(
                PlannedRequest(
                    custom_id=f"g{level}-{sentences.library.content_id('|'.join(ids))}",
                    kind="grammar-tag",
                    model=sentences.REVIEWER_MODEL,
                    system=system,
                    prompt="\n".join(
                        json.dumps({"id": e["id"], "hanzi": e["hanzi"]}, ensure_ascii=False)
                        for e in chunk
                    ),
                    schema=TAG_SCHEMA,
                    metadata={"band": level, "ids": ids},
                )
            )
    return planned


def points_text(points: list[dict]) -> str:
    return "Grammar points:\n" + "\n".join(
        f"{p['id']}: {p['name']} — {p['pattern']}" for p in points
    )


# MARK: Examples

EXAMPLES_SYSTEM = """\
You write original example sentences for learners of Mandarin Chinese preparing for HSK 3.0. You are \
given one grammar point, with its pattern and explanation, and the level that introduces it.

Write the requested number of sentences, each a clear, natural use of that grammar point, in \
standard Mandarin with simplified characters, using vocabulary a learner at that level knows. Vary \
the topic, the subject, and the sentence type. Write numbers in Chinese characters, with no Arabic \
digits, Latin letters or brand names, and end each sentence with 。, ？ or ！.

Fields for each sentence:
- `target`: "".
- `hanzi`: the sentence, with its punctuation.
- `words`: the sentence's characters only (no punctuation), split into words with "/"; prefix a \
proper name with "*".
- `pinyin`: numbered pinyin for the same words, "/" between words and a space between the syllables \
of a word. Mark every syllable 1–5 (5 = neutral tone). Write ü as "u:" and an erhua 儿 as its own \
syllable "r5". Write 一 and 不 with the tone they are spoken with; never apply third-tone sandhi.
- `translation`: a natural, concise English translation.
- `topic`: one or two lowercase English words.
- `grammar`: "".\
"""


def examples_command(args) -> int:
    corpus = sentences.assemble(sentences.Sources.load(), Cache()).kept
    used = {point for entry in corpus for point in entry.get("grammarPoints", [])}
    bare = [point for point in grammar_points() if point["id"] not in used]
    print(f"{len(bare)} grammar points have no example sentences.", file=sys.stderr)
    if not bare:
        return 0
    cache = Cache()
    sentences.run_sync(
        anthropic.Anthropic(), cache, [example_request(p) for p in bare], args.effort
    )
    sentences.report_cost(cache)
    return 0


def example_request(point: dict) -> PlannedRequest:
    prompt = "\n".join(
        [
            f"Level: {point['level']}",
            f"Grammar point: {point['name']}",
            f"Pattern: {point['pattern']}",
            f"Explanation: {point['explanation']}",
            f"Write {EXAMPLES_PER_POINT} sentences.",
        ]
    )
    return PlannedRequest(
        custom_id=f"ge-{point['id']}",
        kind="grammar-examples",
        model=sentences.WRITER_MODEL,
        system=[{"type": "text", "text": EXAMPLES_SYSTEM}],
        prompt=prompt,
        schema=sentences.WORDS_SCHEMA,
        metadata={"band": point["level"], "point": point["id"]},
    )


# MARK: Command line


def parse_arguments(argv):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    commands = parser.add_subparsers(required=True)

    command = commands.add_parser("list")
    command.set_defaults(run=list_command)
    command.add_argument("--effort", default="medium", choices=("low", "medium", "high"))

    command = commands.add_parser("examples")
    command.set_defaults(run=examples_command)
    command.add_argument("--effort", default="low", choices=("low", "medium", "high"))

    command = commands.add_parser("tag")
    command.set_defaults(run=tag_command)
    command.add_argument("action", choices=("pilot", "submit"))
    command.add_argument(
        "--requests", type=int, default=21, help="Pilot size (default: %(default)s)."
    )
    command.add_argument("--seed", type=int, default=0, help="Picks the pilot sample.")
    command.add_argument("--effort", default="low", choices=("low", "medium", "high"))
    command.add_argument("--yes", action="store_true", help="Actually submit the batch.")

    return parser.parse_args(argv)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
