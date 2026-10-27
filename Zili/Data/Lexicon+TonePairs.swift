//
//  Lexicon+TonePairs.swift
//  Zili
//

import Foundation

extension Lexicon {
  /// The two-syllable words taught across `levels`, keyed by the tone pair each is said with, each
  /// pair's words ordered most common first. A word is read as `levels`' standard teaches it.
  nonisolated func tonePairWords(in levels: [HSKLevel]) -> [TonePair: [String]] {
    var byPair = [TonePair: [HSKWord]]()
    for simplified in Set(levels.flatMap(words(in:))) {
      guard let word = hsk[simplified].first,
        let reading = word.relevantForms(in: levels.first?.standard).first?.transcriptions.numeric,
        let pair = TonePair(hanzi: simplified, numberedPinyin: reading)
      else { continue }
      byPair[pair, default: []].append(word)
    }
    return byPair.mapValues { words in
      words.sorted { ($0.commonness, $0.simplified) < ($1.commonness, $1.simplified) }
        .map(\.simplified)
    }
  }
}

extension HSKWord {
  /// Orders words most common first, a word the source gives no frequency for last.
  fileprivate var commonness: Int {
    frequencyFigure > 0 ? frequencyFigure : .max
  }
}
