//
//  WordFrequency.swift
//  Zili
//

import Foundation

/// How common a word is, measured against a subtitle corpus.
///
/// Two complementary measures: raw ``perMillion`` frequency, and ``contextualDiversity``
/// — the share of documents a word appears in, which predicts perceived difficulty better
/// than frequency alone and so drives flashcard and quiz ordering.
struct WordFrequency: Hashable, Sendable {
  /// Occurrences per one million corpus tokens.
  let perMillion: Double

  /// Percentage of corpus documents the word appears in, `0...100`.
  let contextualDiversity: Double
}
