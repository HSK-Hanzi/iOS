#!/usr/bin/env python3
"""Pins how ``unihan_radicals`` reads radical and stroke data out of the Unicode database."""

import unihan_radicals as u

UNIHAN = [
    "#\tkRSUnicode\n",
    "U+6C34\tkRSUnicode\t85.0\n",
    "U+6C34\tkTotalStrokes\t4\n",
    "U+6CB3\tkRSUnicode\t85.5\n",
    "U+8BF4\tkRSUnicode\t149'.7\n",
    "U+8BA0\tkTotalStrokes\t2\n",
    "U+4E43\tkRSUnicode\t4.1 1.-1\n",
]
RADICALS = ["# comment\n", "85; 2F54; 6C34\n", "149'; 2EC8; 8BA0\n", "4; 2F03; 4E3F\n"]


def test_a_simplified_radical_keeps_its_apostrophe():
    assert u.radical_stroke("149'.7") == ("149'", 7)


def test_only_the_first_reading_counts_and_a_negative_residual_is_zero():
    assert u.radical_stroke("1.-1 4.1") == ("1", 0)


def test_build_maps_headwords_to_radicals_and_lists_the_radicals_used():
    document = u.build(UNIHAN, RADICALS, ["水", "河", "说", "乃", "河水"])

    assert document["entries"]["河"] == {"radical": "85", "residualStrokes": 5}
    assert document["entries"]["说"] == {"radical": "149'", "residualStrokes": 7}
    assert "河水" not in document["entries"]
    assert document["radicals"] == [
        {"number": "4", "glyph": "丿", "strokes": 0},
        {"number": "85", "glyph": "水", "strokes": 4},
        {"number": "149'", "glyph": "讠", "strokes": 2},
    ]
