//
//  SpokenSentence.swift
//  Zili
//

import Foundation

/// How a sentence read aloud was heard, character by character.
///
/// The recognizer writes what it hears in characters, picking among homophones as it sees fit, so
/// a character it heard is judged by sound: it was said right when it *is* the sentence's
/// character, or when one of its readings — its word's reading in context, falling back to the
/// character's own — is the sentence's syllable there. The sentence's characters are lined up
/// with the heard ones as a longest common subsequence, so a skipped or extra syllable throws off
/// only itself.
///
/// Some syllables match on any tone: 一 and 不, which the corpus writes with the tones they change
/// to before another syllable, and syllables the corpus gives the neutral tone, which a dictionary
/// gives a full one and a learner says lightly. A sentence whose reading doesn't give one syllable
/// per character is judged on its characters alone.
struct SpokenSentence: Hashable, Sendable {
  /// Characters whose tone the corpus writes as it changes before the next syllable.
  private static let toneSandhi: Set<Character> = ["一", "不"]

  /// Whether each of the sentence's Chinese characters was heard said right, in order.
  let matched: [Bool]

  /// The transcript that was graded — the one, of those the recognizer weighed, that matched the
  /// most.
  let transcript: String

  /// Whether every character was said right.
  var isCorrect: Bool { !matched.isEmpty && !matched.contains(false) }

  /// Grades `heard` against `sentence`, or returns `nil` when none of it is Chinese — silence, or a
  /// conversation nearby — so the sentence is asked for again rather than marked wrong.
  /// `readings` gives a word's numbered-pinyin readings, and `words` splits a run of characters
  /// into words as a reader would.
  init?(
    _ heard: Heard,
    for sentence: PracticeSentence,
    readings: (String) -> Set<String>,
    words: (String) -> [String]
  ) {
    let expected = Self.expected(sentence)
    let graded = heard.candidates
      .map { (transcript: $0, heard: Self.heard($0, readings: readings, words: words)) }
      .filter { !$0.heard.isEmpty }
      .map { (transcript: $0.transcript, matched: Self.align(expected, with: $0.heard)) }
    guard
      let best = graded.max(by: {
        $0.matched.count(where: \.self) < $1.matched.count(where: \.self)
      })
    else { return nil }
    matched = best.matched
    transcript = best.transcript
  }

  /// The sentence's characters, each with the syllable the corpus gives it — or none, when the
  /// reading doesn't line up one syllable to a character.
  private static func expected(_ sentence: PracticeSentence) -> [(Character, String?)] {
    let characters = sentence.hanzi.filter(\.isChineseIdeograph)
    let syllables = sentence.numberedPinyin.split(separator: " ").map(String.init)
    guard syllables.count == characters.count else { return characters.map { ($0, nil) } }
    return zip(characters, syllables).map { ($0, SpokenAnswer.normalizedReading($1)) }
  }

  /// The characters of `transcript`, each with the syllables it may have been said as.
  private static func heard(
    _ transcript: String,
    readings: (String) -> Set<String>,
    words: (String) -> [String]
  ) -> [(Character, Set<String>)] {
    words(String(transcript.filter(\.isChineseIdeograph))).flatMap { word in
      let characters = Array(word)
      let wordReadings = readings(word).map { $0.split(separator: " ").map(String.init) }
        .filter { $0.count == characters.count }
      return characters.enumerated().map { index, character in
        let inWord = wordReadings.map { $0[index] }
        let syllables = inWord.isEmpty ? Array(readings(String(character))) : inWord
        return (character, Set(syllables.map(SpokenAnswer.normalizedReading)))
      }
    }
  }

  /// Which of `expected` a longest common subsequence with `heard` covers.
  private static func align(
    _ expected: [(Character, String?)],
    with heard: [(Character, Set<String>)]
  ) -> [Bool] {
    let rows = expected.count, columns = heard.count
    var lengths = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)
    for row in stride(from: rows - 1, through: 0, by: -1) {
      for column in stride(from: columns - 1, through: 0, by: -1) {
        lengths[row][column] =
          matches(expected[row], heard[column])
          ? lengths[row + 1][column + 1] + 1
          : max(lengths[row + 1][column], lengths[row][column + 1])
      }
    }
    var matched = Array(repeating: false, count: rows)
    var row = 0, column = 0
    while row < rows, column < columns {
      if matches(expected[row], heard[column]) {
        matched[row] = true
        row += 1
        column += 1
      } else if lengths[row + 1][column] >= lengths[row][column + 1] {
        row += 1
      } else {
        column += 1
      }
    }
    return matched
  }

  private static func matches(
    _ expected: (character: Character, syllable: String?),
    _ heard: (character: Character, syllables: Set<String>)
  ) -> Bool {
    guard expected.character != heard.character else { return true }
    guard let syllable = expected.syllable else { return false }
    guard toneSandhi.contains(expected.character) || isNeutral(syllable) else {
      return heard.syllables.contains(syllable)
    }
    return heard.syllables.map(toneless).contains(toneless(syllable))
  }

  /// Whether `syllable` is in the neutral tone, which ``SpokenAnswer/normalizedReading(_:)`` writes
  /// with no digit.
  private static func isNeutral(_ syllable: String) -> Bool {
    !syllable.contains(where: \.isNumber)
  }

  private static func toneless(_ syllable: String) -> String {
    syllable.filter { !$0.isNumber }
  }
}
