//
//  WordLookupDisplayTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct WordLookupDisplayTests {
  // MARK: definitionSenses

  /// A word in the HSK core shows its curated meanings, even when a dictionary also defines it.
  @Test
  func `definition senses prefer the curated HSK meanings`() {
    let lookup = lookup(
      hsk: [hskWord(meanings: ["to be"])],
      dictionaries: [result("cedict", [entry(glosses: ["something else"])])]
    )

    #expect(lookup.definitionSenses == ["to be"])
  }

  /// Outside the HSK core, senses come from the first dictionary offering a bilingual entry —
  /// a leading monolingual source is skipped, and only that one dictionary's glosses are used.
  @Test
  func `definition senses fall back to the first bilingual dictionary`() {
    let lookup = lookup(dictionaries: [
      result("xiandai-hanyu", [entry(glosses: ["名词。"])]),
      result("cedict", [entry(glosses: ["water", "river"])])
    ])

    #expect(lookup.definitionSenses == ["water", "river"])
  }

  /// When every source is monolingual, definition senses fall through to all of its glosses
  /// rather than coming up empty.
  @Test
  func `definition senses return monolingual glosses when nothing is bilingual`() {
    let lookup = lookup(dictionaries: [result("xiandai-hanyu", [entry(glosses: ["名词。", "动词。"])])])

    #expect(lookup.definitionSenses == ["名词。", "动词。"])
  }

  /// A word in the HSK core but without curated meanings still falls back to the dictionaries.
  @Test
  func `definition senses fall back when an HSK word has no meanings`() {
    let lookup = lookup(
      hsk: [hskWord(meanings: [])],
      dictionaries: [result("cedict", [entry(glosses: ["water"])])]
    )

    #expect(lookup.definitionSenses == ["water"])
  }

  /// Nothing known means no senses.
  @Test
  func `definition senses are empty when nothing is known`() {
    #expect(lookup().definitionSenses.isEmpty)
  }

  // MARK: primaryGloss

  /// The peek gloss favors the first bilingual (ASCII-letter) gloss over an earlier
  /// monolingual one.
  @Test
  func `primary gloss prefers a bilingual gloss over a monolingual one`() {
    let lookup = lookup(dictionaries: [result("cedict", [entry(glosses: ["水", "water"])])])

    #expect(lookup.primaryGloss == "water")
  }

  /// With no bilingual gloss anywhere, the peek gloss falls back to the very first gloss.
  @Test
  func `primary gloss falls back to the first gloss when none are bilingual`() {
    let lookup = lookup(dictionaries: [result("xiandai-hanyu", [entry(glosses: ["名词", "动词"])])])

    #expect(lookup.primaryGloss == "名词")
  }

  /// No glosses means no peek gloss.
  @Test
  func `primary gloss is nil when there are no glosses`() {
    #expect(lookup().primaryGloss == nil)
  }

  // MARK: romanization

  /// The authoritative HSK reading wins over a dictionary's pinyin.
  @Test
  func `romanization prefers the HSK transcription over the dictionary reading`() {
    let lookup = lookup(
      hsk: [hskWord(transcriptions: transcript(pinyin: "nǐ"))],
      dictionaries: [result("cedict", [entry(pinyin: "hao3")])]
    )

    #expect(lookup.romanization(.pinyin) == "nǐ")
  }

  /// When the requested system has no HSK transcription, the reading is converted from the
  /// HSK pinyin instead.
  @Test
  func `romanization converts the HSK pinyin when the system's transcription is empty`() {
    let lookup = lookup(hsk: [hskWord(transcriptions: transcript(pinyin: "hao3", wadeGiles: ""))])

    #expect(lookup.romanization(.wadeGiles) == "hǎo")
  }

  /// Outside the HSK core, the reading comes from the first dictionary entry's pinyin.
  @Test
  func `romanization falls back to the first dictionary entry's pinyin`() {
    let lookup = lookup(dictionaries: [result("cedict", [entry(pinyin: "hao3")])])

    #expect(lookup.romanization(.pinyin) == "hǎo")
  }

  /// No reading anywhere means no romanization.
  @Test
  func `romanization is nil when nothing has a reading`() {
    #expect(lookup().romanization(.pinyin) == nil)
  }

  // MARK: Fixtures

  private func lookup(
    hsk: [HSKWord] = [],
    dictionaries: [WordLookup.DictionaryResult] = []
  ) -> WordLookup {
    WordLookup(
      word: "词",
      byDictionary: dictionaries,
      hskEntries: hsk,
      frequency: nil,
      frequencyRank: nil
    )
  }

  private func result(
    _ identifier: String,
    _ entries: [DictionaryEntry]
  ) -> WordLookup.DictionaryResult {
    WordLookup.DictionaryResult(
      metadata: DictionaryMetadata(
        identifier: identifier,
        name: identifier,
        license: "",
        isLicensed: false
      ),
      entries: entries
    )
  }

  private func entry(pinyin: String = "", glosses: [String] = []) -> DictionaryEntry {
    DictionaryEntry(
      simplified: "词",
      traditional: "詞",
      pinyin: pinyin,
      senses: glosses.map { DictionarySense(gloss: $0) }
    )
  }

  private func hskWord(
    meanings: [String] = [],
    transcriptions: HSKWord.Transcriptions = HSKWord.Transcriptions(
      pinyin: "",
      numeric: "",
      bopomofo: "",
      wadeGiles: "",
      romatzyh: ""
    )
  ) -> HSKWord {
    HSKWord(
      simplified: "词",
      radical: "",
      frequencyFigure: 0,
      levels: [],
      partsOfSpeech: [],
      forms: [
        HSKWord.Form(
          traditional: "詞",
          transcriptions: transcriptions,
          meanings: meanings,
          classifiers: []
        )
      ]
    )
  }

  private func transcript(
    pinyin: String = "",
    bopomofo: String = "",
    wadeGiles: String = "",
    romatzyh: String = ""
  ) -> HSKWord.Transcriptions {
    HSKWord.Transcriptions(
      pinyin: pinyin,
      numeric: "",
      bopomofo: bopomofo,
      wadeGiles: wadeGiles,
      romatzyh: romatzyh
    )
  }
}
