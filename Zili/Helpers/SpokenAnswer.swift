//
//  SpokenAnswer.swift
//  Zili
//

import Foundation

/// Grades a speaking-quiz answer: the learner is shown a word and says it, and we compare what
/// the recognizer heard to the word.
///
/// The recognizer hears sounds but writes characters, so a word said perfectly can come back as a
/// homophone — 市 said right arrives as 是. What is being tested is the pronunciation, so a
/// transcript passes when it *is* the word or when it reads the same: identical syllables and
/// identical tones, compared in numbered pinyin. A wrong tone is a different reading, so it fails.
///
/// Only the Chinese characters in a transcript count. The recognizer writes the full stop it
/// hears in the learner's intonation, and transcribes a nearby conversation in whatever script it
/// was in; neither is part of the answer.
enum SpokenAnswer {
  /// Whether any of `heard`'s candidates answers `word`. `readings` gives the numbered-pinyin
  /// readings of a headword — every reading, since a polyphone may be said either way.
  static func matches(
    _ heard: Heard,
    word: String,
    readings: (String) -> Set<String>
  ) -> Bool {
    let word = ideographs(of: word)
    let expected = Set(readings(word).map(normalizedReading))
    return heard.candidates
      .map(ideographs)
      .filter { !$0.isEmpty }
      .contains { $0 == word || !expected.isDisjoint(with: readings($0).map(normalizedReading)) }
  }

  private static func ideographs(of text: String) -> String {
    String(text.filter(\.isChineseIdeograph))
  }

  /// `reading` in one spelling, whichever source wrote it: lowercased, without spaces or
  /// apostrophes, `ü` for `u:` and `v`, and the neutral tone written as no digit at all — sources
  /// disagree on whether it is `5` or nothing.
  static func normalizedReading(_ reading: String) -> String {
    reading
      .lowercased()
      .replacing("u:", with: "ü")
      .replacing("v", with: "ü")
      .filter { !$0.isWhitespace && $0 != "'" && $0 != "5" }
  }
}

extension WordLookup {
  /// Every numbered-pinyin reading any source gives this word — each dictionary entry's and each
  /// HSK form's — for comparing how a word is said.
  var numberedReadings: Set<String> {
    let dictionary = byDictionary.flatMap(\.entries).map(\.pinyin)
    let hsk = hskEntries.flatMap(\.forms).map(\.transcriptions.numeric)
    return Set(dictionary + hsk).subtracting([""])
  }
}
