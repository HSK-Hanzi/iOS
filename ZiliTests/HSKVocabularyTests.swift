//
//  HSKVocabularyTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct HSKVocabularyTests {
  /// The syllabus lists a word in every band it belongs to, so a standard's vocabulary is the
  /// union of its bands — not their sum. 的 sits in both HSK 3.0 bands below, and counts once.
  @Test("A standard's word count unions its bands rather than summing them")
  func wordCountUnionsBandsOfTheSameStandard() {
    let vocabulary = vocabulary([
      "的": [HSKLevel(standard: .new, band: 1), HSKLevel(standard: .new, band: 2)],
      "我": [HSKLevel(standard: .new, band: 2)]
    ])

    #expect(vocabulary.wordCount(in: .new) == 2)
  }

  /// A word carried over from one standard to the next belongs to both, and counts once in each.
  @Test("Word counts are scoped to their own standard")
  func wordCountIgnoresOtherStandards() {
    let vocabulary = vocabulary([
      "的": [HSKLevel(standard: .new, band: 1), HSKLevel(standard: .old, band: 1)],
      "我": [HSKLevel(standard: .old, band: 3)]
    ])

    #expect(vocabulary.wordCount(in: .new) == 1)
    #expect(vocabulary.wordCount(in: .old) == 2)
    #expect(vocabulary.wordCount(in: .newest) == 0)
  }

  /// Builds a vocabulary in which each headword belongs to the given syllabus bands.
  private func vocabulary(_ levelsByHeadword: [String: [HSKLevel]]) -> HSKVocabulary {
    HSKVocabulary(
      wordsBySimplified: levelsByHeadword.mapValues { levels in
        [
          HSKWord(
            simplified: "",
            radical: "",
            frequencyFigure: 0,
            levels: levels,
            partsOfSpeech: [],
            forms: []
          )
        ]
      }
    )
  }
}
