#!/usr/bin/env python3
"""Pins the structural filter in ``hsk_sentences`` — what it keeps, drops, and normalizes."""

import hsk_sentences as h


def test_parse_tags_level_and_strips_page_markers():
    text = "\n".join(
        [
            "HSK 1  (2 sentences)  ·  Standard Course 1 Workbook",
            "1. 我是学生。  (p.16)",
            "HSK 4  (1 sentences)  ·  Standard Course 4A + 4B Workbooks",
            "1. 陪我去一趟银行。  (4A p.3)",
        ]
    )
    parsed = h.parse(text)
    assert [(s.level, s.hanzi, s.page) for s in parsed] == [
        (1, "我是学生。", 16),
        (4, "陪我去一趟银行。", 3),
    ]


def test_keeps_a_plain_sentence():
    assert h.is_clean("每个星期六，我都去打篮球。")


def test_keeps_a_sentence_with_a_title_and_quotes():
    assert h.is_clean("他最喜欢的书是《活着》。")


def test_drops_fragments_and_overlong_runs():
    assert not h.is_clean("对，没变。")  # 3 Han: below the floor
    assert not h.is_clean("字" * 31)  # above the ceiling: almost always spliced


def test_drops_ocr_noise():
    assert not h.is_clean("88我每天六点起床。")  # stray digits
    assert not h.is_clean("A不是，我是中国人。")  # answer-key letter
    assert not h.is_clean("手机在桌子上呢…")  # truncation ellipsis


def test_drops_fill_in_the_blank_and_gloss_parentheses():
    assert not h.is_clean("我（）是中国人，我是美国人。")
    assert not h.is_clean("就像菜里忘了加盐（yan，salt）。")


def test_drops_spliced_sentences_with_two_terminals():
    assert not h.is_clean("你叫什么名字？你喝水吗？")


def test_drops_early_page_boilerplate():
    assert not h.is_clean("这部分主要展示汉字的书写方式，学习者可以模仿练习。", page=4)
    # The same words later in the book are not treated as preface.
    assert h.is_clean("我每天都练习写汉字。", page=40)


def test_clean_sentences_drops_question_prompts_and_dedupes():
    text = "\n".join(
        [
            "HSK 2  (3 sentences)  ·  Standard Course 2 Workbook",
            "1. 问：男的是什么意思？  (p.5)",
            "2. 男：我最喜欢踢足球。  (p.10)",
            "3. 我最喜欢踢足球。  (p.11)",  # duplicate of the line above once its speaker is stripped
        ]
    )
    kept = [s.hanzi for s in h.clean_sentences(text)]
    assert kept == ["我最喜欢踢足球。"]


def test_normalize_strips_speaker_and_closes_ocr_spacing():
    text = "\n".join(
        [
            "HSK 2  (1 sentences)  ·  Standard Course 2 Workbook",
            "1. 女：爸爸 现在 不 能 回来。  (p.12)",
        ]
    )
    assert [s.hanzi for s in h.clean_sentences(text)] == ["爸爸现在不能回来。"]
