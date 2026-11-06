//
//  ListeningChoices.swift
//  Zili
//

import Foundation

/// The words offered for a word heard aloud: the word itself among a few others, to pick it out
/// by ear.
///
/// Every choice has as many characters as the word, so length gives nothing away, and none sounds
/// like another — a homophone can't be told apart by ear, so it would be a trick, not a test. Some
/// distractors are chosen for sounding close to the word, sharing its syllables in other tones or
/// most of them in the same tones, so the choice turns on listening; the rest are drawn at random,
/// so it doesn't always turn on the finest distinction.
enum ListeningChoices {
  /// How many choices are offered, the word included.
  static let count = 4

  /// How many of the distractors are chosen for sounding close to the word.
  private static let closeDistractors = 2

  /// `word` among up to ``count`` - 1 distractors from `pool`, shuffled. `readings` gives a word's
  /// numbered-pinyin readings — every reading, since a polyphone may sound like another word in
  /// any of them — and is asked once per word. Fewer choices come back when the pool has too few
  /// words that fit.
  static func choices(
    for word: String,
    among pool: [String],
    readings: (String) -> Set<String>,
    using generator: inout some RandomNumberGenerator
  ) -> [String] {
    let wordReadings = readings(word)
    let wordSyllables = wordReadings.map(syllables)
    let candidates =
      pool
      .filter { $0.count == word.count && $0 != word }
      .shuffled(using: &generator)
      .map { Candidate(word: $0, readings: readings($0)) }
      .filter { !$0.readings.isEmpty }
    let closest =
      candidates
      .map { ($0, closeness(of: $0.readings, to: wordSyllables)) }
      .sorted { $0.1 > $1.1 }
      .map(\.0)

    var chosen = [word]
    var heard = Set(wordReadings.map(SpokenAnswer.normalizedReading))
    func take(from ordered: [Candidate], upTo total: Int) {
      for candidate in ordered where chosen.count < total && !chosen.contains(candidate.word) {
        let sounds = Set(candidate.readings.map(SpokenAnswer.normalizedReading))
        guard heard.isDisjoint(with: sounds) else { continue }
        chosen.append(candidate.word)
        heard.formUnion(sounds)
      }
    }
    take(from: closest, upTo: 1 + closeDistractors)
    take(from: candidates, upTo: count)
    return chosen.shuffled(using: &generator)
  }

  /// How close a word read as `readings` sounds to one read as `wordSyllables`: the most
  /// syllables, position for position, that any of its readings shares with any of the word's,
  /// ignoring tone — with a half point more for each that shares the tone too.
  private static func closeness(of readings: Set<String>, to wordSyllables: [[String]]) -> Double {
    let closenesses = readings.map(syllables).flatMap { candidate in
      wordSyllables.map { closeness(of: candidate, to: $0) }
    }
    return closenesses.max() ?? 0
  }

  private static func closeness(of candidate: [String], to word: [String]) -> Double {
    zip(candidate, word).reduce(0) { total, pair in
      guard toneless(pair.0) == toneless(pair.1) else { return total }
      return total + (pair.0 == pair.1 ? 1.5 : 1)
    }
  }

  /// A numbered-pinyin reading's syllables, lowercased, with the neutral tone written as no digit.
  private static func syllables(_ reading: String) -> [String] {
    reading.lowercased().split(separator: " ").map { String($0).replacing("5", with: "") }
  }

  private static func toneless(_ syllable: String) -> String {
    syllable.filter { !$0.isNumber }
  }

  /// A word that might be offered, with its readings.
  private struct Candidate {
    let word: String
    let readings: Set<String>
  }
}
