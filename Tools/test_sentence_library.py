#!/usr/bin/env python3
"""Pins how ``sentence_library`` levels sentences and decides which generated sentences may ship."""

import pytest

import sentence_library as s

VOCABULARY = {
    "我": [{"levels": ["old-1", "new-1", "newest-1"]}],
    "喝": [{"levels": ["old-1", "new-1", "newest-1"]}],
    "茶": [{"levels": ["old-1", "new-1", "newest-1"]}],
    "想": [{"levels": ["old-1", "new-1", "newest-1"]}],
    "红": [{"levels": ["old-2", "new-2", "newest-2"]}],
    "绿": [{"levels": ["old-3", "new-3", "newest-3"]}],
    "咖啡": [{"levels": ["old-2", "newest-2"]}],
    "谁": [{"levels": ["old-1", "new-1", "newest-1"]}],
}

READINGS = s.Readings.build(
    {
        "我": {"mandarin": ["wo3"]},
        "想": {"mandarin": ["xiang3"]},
        "喝": {"mandarin": ["he1", "he4"]},
        "茶": {"mandarin": ["cha2"]},
        "一": {"mandarin": ["yi1"]},
        "杯": {"mandarin": ["bei1"]},
        "不": {"mandarin": ["bu4"]},
        "要": {"mandarin": ["yao4", "yao1"]},
        "去": {"mandarin": ["qu4"]},
        "哪": {"mandarin": ["na3"]},
        "儿": {"mandarin": ["er2"]},
        "谁": {"mandarin": ["shui2"]},
        "绿": {"mandarin": ["lv4", "lu4"]},
        "的": {"mandarin": ["di2", "di4", "de"]},
    },
    {"谁": [{"pinyin": "shei2"}]},
)


@pytest.fixture(scope="module")
def syllabi():
    return s.syllabi(VOCABULARY)


def check(hanzi, words, pinyin, *, band=1, target=None):
    return s.problems(
        hanzi=hanzi,
        words=words,
        pinyin=pinyin,
        band=band,
        target=target,
        readings=READINGS,
    )


def test_a_sentence_sits_at_its_hardest_word(syllabi):
    assert s.levels(s.tokens("我/想/喝/绿/茶"), syllabi) == {
        "old": 3,
        "new": 3,
        "newest": 3,
    }


def test_a_compound_missing_from_the_syllabus_levels_by_its_parts(syllabi):
    assert s.word_band("红茶", syllabi["newest"]) == 2


def test_a_word_one_standard_lacks_leaves_the_sentence_unleveled_there(syllabi):
    assert s.levels(s.tokens("我/喝/咖啡"), syllabi) == {"old": 2, "newest": 2}


def test_names_and_numbers_cost_nothing(syllabi):
    assert s.levels(s.tokens("*王小明/喝/三/茶"), syllabi) == {
        "old": 1,
        "new": 1,
        "newest": 1,
    }


def test_a_clean_sentence_passes():
    assert check("我想喝茶。", "我/想/喝/茶", "wo3/xiang3/he1/cha2", target="喝") == []


def test_tone_sandhi_on_yi_and_bu_is_accepted():
    assert check("我不要一杯茶。", "我/不/要/一/杯/茶", "wo3/bu2/yao4/yi4/bei1/cha2") == []


def test_a_dictionary_word_reading_overrides_the_character_table():
    assert check("谁喝茶？", "谁/喝/茶", "shei2/he1/cha2") == []


def test_erhua_and_neutral_tones_are_accepted():
    assert check("我去哪儿？", "我/去/哪儿", "wo3/qu4/na3 r5") == []
    assert check("绿的茶。", "绿/的/茶", "lu:4/de5/cha2") == []


def test_a_wrong_tone_is_caught():
    assert check("我想喝茶。", "我/想/喝/茶", "wo3/xiang3/he1/cha4") == ["茶 isn't read cha4"]


def test_a_segmentation_that_misspells_the_sentence_is_caught():
    assert check("我想喝茶。", "我/想/茶", "wo3/xiang3/cha2") == [
        "segmentation doesn't spell the sentence"
    ]


def test_length_target_and_script_are_checked():
    found = check("我想喝3杯茶。", "我/想/喝/杯/茶", "wo3/xiang3/he1/bei1/cha2", target="要")
    assert "contains Latin letters or digits" in found
    assert "missing its target word 要" in found


def test_longest_match_segmentation():
    lexicon = {"我", "喝", "红茶", "红"}
    assert [t.text for t in s.segment("我喝红茶。", lexicon, 2)] == ["我", "喝", "红茶"]


def test_a_paraphrase_of_a_reference_sentence_is_a_near_copy():
    index = s.NearCopyIndex(["我每天早上都喝一杯绿茶。"])
    assert index.is_near_copy("我每天早上都喝一杯红茶。")
    assert not index.is_near_copy("他晚上不喝咖啡。")


@pytest.mark.parametrize(
    ("typed", "typographic"),
    [
        ("Don't forget.", "Don’t forget."),
        ("The students' books.", "The students’ books."),
        ('He said "hello" to me.', "He said “hello” to me."),
        ("'let alone' and 'moreover'", "‘let alone’ and ‘moreover’"),
        ('("Really?") she asked.', "(“Really?”) she asked."),
    ],
)
def test_typewriter_quotes_become_typographic(typed, typographic):
    assert s.smart_quotes(typed) == typographic

