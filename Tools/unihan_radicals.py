#!/usr/bin/env python3
"""Record each dictionary character's radical, for looking characters up by radical.

Reads two files of the Unicode Character Database (Unicode License v3):

  - ``Unihan_IRGSources.txt`` from ``Unihan.zip`` — each character's ``kRSUnicode`` (its Kangxi
    radical and the strokes beyond it, ``149'.7`` for 说, the apostrophe marking the radical's
    simplified form) and ``kTotalStrokes``.
  - ``CJKRadicals.txt`` — each radical's number and the character that writes it, simplified forms
    included (``149'`` is 讠).

and writes ``CharacterRadicals.plist``: a ``radicals`` list (number, glyph, stroke count) holding
every radical some character uses, and ``entries`` mapping each single-character CC-CEDICT headword
to its radical's number and its residual stroke count.

Usage::

    python unihan_radicals.py <Unihan_IRGSources.txt> <CJKRadicals.txt> \\
        ../Data/Open/CEDICT.plist ../Data/Open/CharacterRadicals.plist

Both files are at https://www.unicode.org/Public/UCD/latest/ucd/.
"""

from __future__ import annotations

import argparse
import plistlib
import re
import sys
from pathlib import Path

_FIELD = re.compile(r"^U\+([0-9A-F]+)\t(kRSUnicode|kTotalStrokes)\t(.+)$")
_RADICAL_ROW = re.compile(r"^(\d+'*);\s*[0-9A-F]+;\s*([0-9A-F]+)$")


def radical_stroke(value: str) -> tuple[str, int]:
    """The radical number and residual strokes of a ``kRSUnicode`` value, using its first reading:
    ``"149'.7"`` is ``("149'", 7)``; a negative residual (a radical missing strokes) counts as 0."""
    radical, residual = value.split()[0].split(".")
    return radical, max(0, int(residual))


def unihan_fields(lines) -> tuple[dict[str, str], dict[str, int]]:
    """Each character's ``kRSUnicode`` value and first ``kTotalStrokes`` count."""
    radicals: dict[str, str] = {}
    strokes: dict[str, int] = {}
    for line in lines:
        match = _FIELD.match(line.rstrip("\n"))
        if not match:
            continue
        character = chr(int(match[1], 16))
        if match[2] == "kRSUnicode":
            radicals[character] = match[3]
        else:
            strokes[character] = int(match[3].split()[0])
    return radicals, strokes


def radical_glyphs(lines) -> dict[str, str]:
    """Each radical number's glyph — the unified ideograph that writes it."""
    glyphs = {}
    for line in lines:
        match = _RADICAL_ROW.match(line.strip())
        if match:
            glyphs[match[1]] = chr(int(match[2], 16))
    return glyphs


def build(unihan_lines, radical_lines, headwords) -> dict:
    """The ``CharacterRadicals.plist`` document for the single-character `headwords`."""
    kangxi, strokes = unihan_fields(unihan_lines)
    glyphs = radical_glyphs(radical_lines)
    entries = {}
    for character in sorted(headwords):
        if len(character) != 1 or character not in kangxi:
            continue
        radical, residual = radical_stroke(kangxi[character])
        if radical not in glyphs:
            radical = radical.rstrip("'")
        entries[character] = {"radical": radical, "residualStrokes": residual}
    used = {entry["radical"] for entry in entries.values()}
    radicals = [
        {"number": number, "glyph": glyphs[number], "strokes": strokes.get(glyphs[number], 0)}
        for number in sorted(used, key=lambda n: (int(n.rstrip("'")), n))
    ]
    return {
        "meta": {
            "name": "Unihan radicals",
            "license": "Unicode License v3",
            "description": "Each CC-CEDICT character's Kangxi radical and residual stroke count.",
        },
        "radicals": radicals,
        "entries": entries,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("unihan", type=Path, help="Unihan_IRGSources.txt")
    parser.add_argument("cjk_radicals", type=Path, help="CJKRadicals.txt")
    parser.add_argument("cedict", type=Path, help="CEDICT.plist")
    parser.add_argument("destination", type=Path)
    args = parser.parse_args(argv)

    headwords = plistlib.loads(args.cedict.read_bytes())["entries"].keys()
    with args.unihan.open() as unihan, args.cjk_radicals.open() as radicals:
        document = build(unihan, radicals, headwords)
    args.destination.write_bytes(plistlib.dumps(document, fmt=plistlib.FMT_BINARY))
    print(
        f"{len(document['entries'])} characters under {len(document['radicals'])} radicals",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
