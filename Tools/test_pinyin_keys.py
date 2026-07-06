"""Unit tests for the build-time pinyin key pipeline."""

import pathlib
import plistlib
import unittest

from pinyin_keys import (
    canonical_marked,
    character_readings,
    letters,
    mark_syllable,
    search_keys,
    segment,
)


class MarkSyllableTests(unittest.TestCase):
    def test_places_the_tone_on_the_standard_vowel(self):
        self.assertEqual(mark_syllable("gan4"), "gàn")
        self.assertEqual(mark_syllable("gan1"), "gān")
        self.assertEqual(mark_syllable("hao3"), "hǎo")   # a wins over o
        self.assertEqual(mark_syllable("jing4"), "jìng")  # last vowel
        self.assertEqual(mark_syllable("liu2"), "liú")    # iu -> u
        self.assertEqual(mark_syllable("gui4"), "guì")    # ui -> i

    def test_neutral_tone_carries_no_mark(self):
        self.assertEqual(mark_syllable("de5"), "de")
        self.assertEqual(mark_syllable("zi5"), "zi")

    def test_folds_every_umlaut_spelling(self):
        for spelling in ("lü3", "lu:3", "lv3"):
            self.assertEqual(mark_syllable(spelling), "lǚ")


class CanonicalMarkedTests(unittest.TestCase):
    def test_renders_cedict_numbered_readings(self):
        self.assertEqual(canonical_marked("fang1 an4"), ["fāngàn"])
        self.assertEqual(canonical_marked("fan3 gan3"), ["fǎngǎn"])
        self.assertEqual(canonical_marked("lü3 xing2"), ["lǚxíng"])

    def test_folds_script_g_and_drops_separators(self):
        self.assertEqual(canonical_marked("ɡān"), ["gān"])
        self.assertEqual(canonical_marked("fānɡ'àn"), ["fāngàn"])
        self.assertEqual(canonical_marked("àn·zi"), ["ànzi"])
        self.assertEqual(canonical_marked("tòu//dǐ"), ["tòudǐ"])
        self.assertEqual(canonical_marked("xiùshǒu-pángguān"), ["xiùshǒupángguān"])

    def test_drops_both_apostrophe_spellings(self):
        # Oxford writes U+0027, Xiandai U+2019. Both mark a syllable boundary before a/o/e.
        self.assertEqual(canonical_marked("fānɡ'àn"), ["fāngàn"])
        self.assertEqual(canonical_marked("fāng’àn"), ["fāngàn"])
        self.assertEqual(canonical_marked("nǚ’ér"), ["nǚér"])

    def test_discards_parenthetical_annotations(self):
        self.assertEqual(canonical_marked("rú（旧读ruǎn）"), ["rú"])

    def test_splits_alternates_on_a_han_annotation(self):
        self.assertEqual(canonical_marked("xún 又 yīngxún"), ["xún", "yīngxún"])

    def test_passes_latin_acronyms_through_without_umlaut_damage(self):
        self.assertEqual(canonical_marked("V C R"), ["vcr"])
        self.assertEqual(canonical_marked("BBjī"), ["bbjī"])

    def test_rejects_empty_input(self):
        self.assertEqual(canonical_marked(""), [])
        self.assertEqual(canonical_marked("（旧读）"), [])


class LettersTests(unittest.TestCase):
    def test_strips_tone_marks_and_folds_the_umlaut(self):
        self.assertEqual(letters("lǚxíng"), "luxing")
        self.assertEqual(letters("gānjìng"), "ganjing")
        self.assertEqual(letters("nǚér"), "nuer")


# A stand-in for CharacterReadings.plist: character -> its Mandarin readings, tones included.
READINGS = character_readings({
    "方": {"mandarin": ["fang1"]},
    "案": {"mandarin": ["an4"]},
    "子": {"mandarin": ["zi3"]},
    "反": {"mandarin": ["fan3"]},
    "感": {"mandarin": ["gan3"]},
    "干": {"mandarin": ["gan1", "gan4"]},   # a heteronym: the source's mark picks the tone
    "一": {"mandarin": ["yi1"]},
    "十": {"mandarin": ["shi2"]},
    "二": {"mandarin": ["er4"]},
    "品": {"mandarin": ["pin3"]},
    "锅": {"mandarin": ["guo1"]},
    "儿": {"mandarin": ["er2"]},
    "童": {"mandarin": ["tong2"]},
    "村": {"mandarin": ["cun1"]},
    "妞": {"mandarin": ["niu1"]},
    "女": {"mandarin": ["nü3"]},
    "旅": {"mandarin": ["lü3"]},
    "行": {"mandarin": ["xing2", "hang2"]},
    "射": {"mandarin": ["she4"]},
    "线": {"mandarin": ["xian4"]},
    "你": {"mandarin": ["ni3"]},
    "好": {"mandarin": ["hao3"]},
})


class SegmentTests(unittest.TestCase):
    def test_resolves_the_boundary_abc_cannot(self):
        # fāngàn and fǎngǎn have identical letters AND identical mark positions.
        self.assertEqual(segment("方案", "fangan", READINGS), ["fang", "an"])
        self.assertEqual(segment("反感", "fangan", READINGS), ["fan", "gan"])

    def test_beats_the_greedy_segmentation_that_was_rejected(self):
        # Greedy longest-match yields yi|shie|r and yi|ping|uo. Character readings do not.
        self.assertEqual(segment("一十二", "yishier", READINGS), ["yi", "shi", "er"])
        self.assertEqual(segment("一品锅", "yipinguo", READINGS), ["yi", "pin", "guo"])

    def test_latin_letters_consume_themselves(self):
        self.assertEqual(
            segment("SOS儿童村", "sosertongcun", READINGS), ["s", "o", "s", "er", "tong", "cun"]
        )

    def test_erhua_attaches_r_to_the_previous_syllable(self):
        self.assertEqual(segment("妞儿", "niur", READINGS), ["niu", "r"])

    def test_a_leading_er_is_still_er(self):
        self.assertEqual(segment("女儿", "nuer", READINGS), ["nu", "er"])

    def test_skips_units_that_contribute_no_letters(self):
        self.assertEqual(segment("α射线", "shexian", READINGS), ["she", "xian"])

    def test_returns_none_when_the_walk_fails(self):
        self.assertIsNone(segment("〇", "ling", READINGS))       # no reading for 〇
        self.assertIsNone(segment("方案", "fangannn", READINGS))  # letters left over


class SearchKeysTests(unittest.TestCase):
    def keys(self, word, pinyin):
        found = search_keys(word, pinyin, READINGS)
        self.assertEqual(len(found), 1, f"expected one reading, got {found}")
        return found[0]

    def test_all_four_sources_converge_on_the_same_keys(self):
        for pinyin in ("an4 zi5", "ànzi", "àn·zi"):
            keys = self.keys("案子", pinyin)
            self.assertEqual((keys.toneless, keys.numbered, keys.marked), ("anzi", "an4zi5", "ànzi"))

    def test_neutral_tone_is_digit_five(self):
        self.assertEqual(self.keys("案子", "ànzi").numbered, "an4zi5")

    def test_heteronym_tones_come_from_the_source_not_the_character(self):
        # 干 has readings gān and gàn; the mark in the source decides, not CharacterReadings.
        self.assertEqual(self.keys("干", "ɡān").numbered, "gan1")
        self.assertEqual(self.keys("干", "ɡàn").numbered, "gan4")

    def test_umlaut_survives_in_marked_and_folds_elsewhere(self):
        keys = self.keys("旅行", "lü3 xing2")
        self.assertEqual(keys.marked, "lǚxíng")
        self.assertEqual(keys.toneless, "luxing")
        self.assertEqual(keys.numbered, "lu3xing2")

    def test_an_unsegmentable_reading_has_no_numbered_key(self):
        keys = self.keys("〇", "líng")
        self.assertEqual(keys.numbered, "")
        self.assertEqual(keys.toneless, "ling")   # still findable by bare pinyin
        self.assertEqual(keys.marked, "líng")     # and by tone-marked pinyin

    def test_alternates_each_get_their_own_keys(self):
        found = search_keys("㖊", "xún 又 yīngxún", READINGS)
        self.assertEqual([k.toneless for k in found], ["xun", "yingxun"])

    def test_numbered_sources_never_need_segmentation(self):
        # CC-CEDICT's digits already delimit its syllables. Passing no character readings at all
        # proves the segmenter is not consulted.
        self.assertEqual(search_keys("方案", "fang1 an4", {})[0].numbered, "fang1an4")
        self.assertEqual(search_keys("你好", "ni3 hao3", {})[0].numbered, "ni3hao3")

    def test_a_numbered_source_with_a_latin_run_falls_back(self):
        # `san1 D da3 yin4` is not wholly numbered syllables, so it needs the walk — which fails.
        self.assertEqual(search_keys("3D打印", "san1 D da3 yin4", READINGS)[0].numbered, "")

    def test_erhua_takes_a_neutral_tone(self):
        self.assertEqual(search_keys("妞儿", "niūr", READINGS)[0].numbered, "niu1r5")
        self.assertEqual(search_keys("女儿", "nǚér", READINGS)[0].numbered, "nu3er2")


class SegmentationRegressionTests(unittest.TestCase):
    """The worst case must stay 'absent', never 'wrong'. A greedy fallback would break these."""

    def test_greedy_mis_segmentations_never_appear(self):
        self.assertEqual(search_keys("一十二", "yīshíèr", READINGS)[0].numbered, "yi1shi2er4")
        self.assertEqual(search_keys("一品锅", "yīpǐnguō", READINGS)[0].numbered, "yi1pin3guo1")

    def test_ambiguous_pairs_resolve_by_headword(self):
        self.assertEqual(search_keys("方案", "fāngàn", READINGS)[0].numbered, "fang1an4")
        self.assertEqual(search_keys("反感", "fǎngǎn", READINGS)[0].numbered, "fan3gan3")


_DATA = pathlib.Path(__file__).resolve().parent.parent / "Data"
_LICENSED = _DATA / "licensed"

# Measured across every bundled dictionary. Raising either constant means a reading that used to be
# searchable by tone digits no longer is. Lowering them is an improvement — update them, and say so.
MAX_UNSEGMENTED_READINGS = 2056
BEST_LOST_CORPUS_RANK = 7148  # 南茜


def _load(path):
    root = plistlib.loads(path.read_bytes())
    return root.get("entries", root) if isinstance(root, dict) and "entries" in root else root


@unittest.skipUnless(_LICENSED.is_dir(), "licensed dictionaries are not present")
class CorpusCanaryTests(unittest.TestCase):
    """The worst case must not get worse: cap the readings we leave without a `numbered` key."""

    @classmethod
    def setUpClass(cls):
        cls.readings = character_readings(_load(_DATA / "open" / "CharacterReadings.plist"))
        frequency = _load(_DATA / "open" / "SUBTLEX-CH-Words.plist")
        ordered = sorted(frequency.items(), key=lambda item: item[1][0], reverse=True)
        cls.ranks = {word: index + 1 for index, (word, _) in enumerate(ordered)}
        cls.unsegmented, cls.lost = cls._scan()

    @classmethod
    def _scan(cls):
        """(readings with no numbered key, headwords with none in *any* bundled dictionary)."""
        count = 0
        segmented = set()
        unsegmented = set()
        paths = [_DATA / "open" / "CEDICT.plist", *sorted(_LICENSED.glob("*.plist"))]
        for path in paths:
            data = _load(path)
            # The licensed tree also holds the HSK sentence corpus, whose entries are a flat list
            # rather than a word→entries mapping; only the word dictionaries belong to this canary.
            if not isinstance(data, dict):
                continue
            for word, entries in data.items():
                for entry in entries:
                    pinyin = entry.get("pinyin") if isinstance(entry, dict) else None
                    if not isinstance(pinyin, str):
                        continue
                    for keys in search_keys(word, pinyin, cls.readings):
                        if keys.numbered:
                            segmented.add(word)
                        else:
                            count += 1
                            unsegmented.add(word)
        return count, unsegmented - segmented

    def test_unsegmented_reading_count_does_not_grow(self):
        self.assertLessEqual(self.unsegmented, MAX_UNSEGMENTED_READINGS)

    def test_no_common_word_loses_its_numbered_key(self):
        ranked = sorted(self.ranks[word] for word in self.lost if word in self.ranks)
        self.assertTrue(ranked, "expected some lost headwords to be in the corpus")
        self.assertGreaterEqual(ranked[0], BEST_LOST_CORPUS_RANK)

    def test_cedict_needs_no_segmentation(self):
        """CC-CEDICT's spaces delimit its syllables; only Latin acronyms should ever fail."""
        count = sum(
            1
            for word, entries in _load(_DATA / "open" / "CEDICT.plist").items()
            for entry in entries
            if isinstance(entry, dict) and isinstance(entry.get("pinyin"), str)
            for keys in search_keys(word, entry["pinyin"], self.readings)
            if not keys.numbered
        )
        self.assertLessEqual(count, 6)


if __name__ == "__main__":
    unittest.main()
