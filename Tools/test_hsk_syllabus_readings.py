"""Unit tests for recording the syllabus readings of HSK words."""

import unittest

from hsk_syllabus_readings import annotate, readings, syllabus


class ReadingsTests(unittest.TestCase):
    def test_keeps_only_the_lowercase_letters(self):
        self.assertEqual(readings("āijiā-āihù"), ["āijiāāihù"])
        self.assertEqual(readings("fèn'é"), ["fèné"])
        self.assertEqual(readings("bīnggùnr5"), ["bīnggùnr"])
        self.assertEqual(readings("Dǎ kāi"), ["dǎkāi"])

    def test_splits_alternative_readings(self):
        self.assertEqual(readings("shú/shóu"), ["shú", "shóu"])


class SyllabusTests(unittest.TestCase):
    def test_collects_each_reading_of_a_word_once_in_list_order(self):
        rows = [("地", "dì"), ("地", "de"), ("地方", "dìfang"), ("地", "dì")]

        self.assertEqual(syllabus(rows), {"地": ["dì", "de"], "地方": ["dìfang"]})


class AnnotateTests(unittest.TestCase):
    def test_writes_each_standard_that_lists_the_word_onto_every_record(self):
        entries = {"说": [{}, {}], "邱": [{}]}
        syllabi = {"old": {"说": ["shuō"]}, "new": {}, "newest": {"说": ["shuō"]}}

        unread = annotate(entries, syllabi)

        self.assertEqual(entries["说"], [{"syllabusReadings": {"old": ["shuō"], "newest": ["shuō"]}}] * 2)
        self.assertEqual(entries["邱"], [{"syllabusReadings": {}}])
        self.assertEqual(unread, 1)


if __name__ == "__main__":
    unittest.main()
