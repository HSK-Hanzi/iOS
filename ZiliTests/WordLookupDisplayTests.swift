//
//  WordLookupDisplayTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct `Word lookup display` {
  // MARK: definitionSenses

  /// A word in the HSK core shows its curated meanings, even when a dictionary also defines it.
  @Test
  func `definition senses prefer the curated HSK meanings`() {
    let lookup = lookup(
      hsk: [hskWord(meanings: ["to be"])],
      dictionaries: [result("cedict", [entry(glosses: ["something else"])])]
    )

    #expect(lookup.definitionSenses() == ["to be"])
  }

  /// Outside the HSK core, senses come from the first dictionary offering a bilingual entry —
  /// a leading monolingual source is skipped, and only that one dictionary's glosses are used.
  @Test
  func `definition senses fall back to the first bilingual dictionary`() {
    let lookup = lookup(dictionaries: [
      result("xiandai-hanyu", [entry(glosses: ["名词。"])]),
      result("cedict", [entry(glosses: ["water", "river"])])
    ])

    #expect(lookup.definitionSenses() == ["water", "river"])
  }

  /// When every source is monolingual, definition senses fall through to all of its glosses
  /// rather than coming up empty.
  @Test
  func `definition senses return monolingual glosses when nothing is bilingual`() {
    let lookup = lookup(dictionaries: [result("xiandai-hanyu", [entry(glosses: ["名词。", "动词。"])])])

    #expect(lookup.definitionSenses() == ["名词。", "动词。"])
  }

  /// A word in the HSK core but without curated meanings still falls back to the dictionaries.
  @Test
  func `definition senses fall back when an HSK word has no meanings`() {
    let lookup = lookup(
      hsk: [hskWord(meanings: [])],
      dictionaries: [result("cedict", [entry(glosses: ["water"])])]
    )

    #expect(lookup.definitionSenses() == ["water"])
  }

  /// Nothing known means no senses.
  @Test
  func `definition senses are empty when nothing is known`() {
    #expect(lookup().definitionSenses().isEmpty)
  }

  /// A word whose surname form comes first in the data is still defined, and read, by its
  /// common form.
  @Test
  func `an HSK word is defined by its common form rather than its surname`() {
    let lookup = lookup(hsk: [
      hskWord(forms: [form("Lěng", "Leng3", ["surname Leng"]), form("lěng", "leng3", ["cold"])])
    ])

    #expect(lookup.definitionSenses() == ["cold"])
    #expect(lookup.romanization(.pinyin) == "lěng")
  }

  /// Of a word's common readings, the one its syllabus lists is the one shown.
  @Test
  func `an HSK word is defined and read by its syllabus reading`() {
    let lookup = lookup(hsk: [
      hskWord(
        forms: [form("shuì", "shui4", ["to persuade"]), form("shuō", "shuo1", ["to speak"])],
        syllabusReadings: [.new: ["shuō"]]
      )
    ])

    #expect(lookup.definitionSenses() == ["to speak"])
    #expect(lookup.romanization(.pinyin) == "shuō")
  }

  /// Every form with the syllabus reading contributes its meanings, each once.
  @Test
  func `forms sharing the syllabus reading pool their meanings`() {
    let lookup = lookup(hsk: [
      hskWord(
        forms: [
          form("Chǒu", "Chou3", ["surname Chou"]),
          form("chǒu", "chou3", ["clown", "shameful"]),
          form("chǒu", "chou3", ["shameful", "ugly"])
        ],
        syllabusReadings: [.old: ["chǒu"]]
      )
    ])

    #expect(lookup.definitionSenses() == ["clown", "shameful", "ugly"])
  }

  /// A deck drilling one standard shows the reading that standard lists first.
  @Test
  func `the drilled standard's syllabus reading leads`() {
    let lookup = lookup(hsk: [
      hskWord(
        forms: [form("de", "de5", ["-ly"]), form("dì", "di4", ["earth"])],
        syllabusReadings: [.newest: ["de"], .new: ["dì", "de"]]
      )
    ])

    #expect(lookup.definitionSenses(in: .new) == ["earth"])
    #expect(lookup.definitionSenses() == ["-ly"])
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

  /// A word in the HSK core that no loaded dictionary covers — routine when only the open data
  /// ships — still peeks with its curated meaning rather than nothing.
  @Test("Primary gloss falls back to the curated HSK meaning")
  func primaryGlossFallsBackToHSKMeaning() {
    let lookup = lookup(hsk: [hskWord(meanings: ["word", "term"])])

    #expect(lookup.primaryGloss == "word")
  }

  /// A dictionary that lists a surname first still peeks with the word's common meaning.
  @Test
  func `primary gloss leads with a dictionary's common reading`() {
    let lookup = lookup(dictionaries: [
      result(
        "cedict",
        [
          entry(pinyin: "Leng3", glosses: ["surname Leng"]),
          entry(pinyin: "leng3", glosses: ["cold"])
        ]
      )
    ])

    #expect(lookup.primaryGloss == "cold")
  }

  /// An HSK word peeks with the gloss of the reading it shows, even when the dictionary lists
  /// another common reading first.
  @Test
  func `primary gloss follows the HSK word's syllabus reading`() {
    let lookup = lookup(
      hsk: [
        hskWord(
          forms: [form("shuì", "shui4", ["to persuade"]), form("shuō", "shuo1", ["to speak"])],
          syllabusReadings: [.new: ["shuō"]]
        )
      ],
      dictionaries: [
        result(
          "cedict",
          [
            entry(pinyin: "shui4", glosses: ["to persuade"]),
            entry(pinyin: "shuo1", glosses: ["to speak"])
          ]
        )
      ]
    )

    #expect(lookup.primaryGloss == "to speak")
  }

  /// A dictionary that spells its pinyin with a script g still lines up with the syllabus reading.
  @Test
  func `primary gloss matches a syllabus reading spelled with a script g`() {
    let lookup = lookup(
      hsk: [
        hskWord(
          forms: [form("háng", "hang2", ["row"]), form("xíng", "xing2", ["to walk"])],
          syllabusReadings: [.new: ["xíng"]]
        )
      ],
      dictionaries: [
        result(
          "oxford-ce",
          [entry(pinyin: "hánɡ", glosses: ["line"]), entry(pinyin: "xínɡ", glosses: ["walk"])]
        )
      ]
    )

    #expect(lookup.primaryGloss == "walk")
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
    hskWord(forms: [
      HSKWord.Form(
        traditional: "詞",
        transcriptions: transcriptions,
        meanings: meanings,
        classifiers: []
      )
    ])
  }

  private func hskWord(
    forms: [HSKWord.Form],
    syllabusReadings: [HSKLevel.Standard: [String]] = [:]
  ) -> HSKWord {
    HSKWord(
      simplified: "词",
      radical: "",
      frequencyFigure: 0,
      levels: [],
      partsOfSpeech: [],
      forms: forms,
      syllabusReadings: syllabusReadings
    )
  }

  private func form(_ pinyin: String, _ numeric: String, _ meanings: [String]) -> HSKWord.Form {
    HSKWord.Form(
      traditional: "詞",
      transcriptions: HSKWord.Transcriptions(
        pinyin: pinyin,
        numeric: numeric,
        bopomofo: "",
        wadeGiles: "",
        romatzyh: ""
      ),
      meanings: meanings,
      classifiers: []
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
