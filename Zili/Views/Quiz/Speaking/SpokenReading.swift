//
//  SpokenReading.swift
//  Zili
//

import Foundation

/// How a transcript of the learner's speech reads, word by word, in their romanization.
///
/// The recognizer writes what it hears in characters, and when it picks a homophone the characters
/// say nothing useful about what the learner actually said. The reading does: its syllables and
/// tones are the pronunciation. The transcript is split into words as a reader would split it, so
/// each word's own reading — not a character-by-character guess at a polyphone — is used.
@MainActor
enum SpokenReading {
  /// The reading of `transcript`'s Chinese, one word at a time and space-separated; empty when it
  /// holds no Chinese at all.
  static func reading(of transcript: String, in romanization: Romanization, lexicon: Lexicon)
    -> String
  {
    let characters = Array(transcript.filter(\.isChineseIdeograph))
    let resolver = WordResolver(lexicon: lexicon)
    return WordSegmenter.shared.words(in: String(characters), using: resolver)
      .map { String(characters[$0]) }
      .map { reading(ofWord: $0, in: romanization, lexicon: lexicon) }
      .joined(separator: " ")
  }

  /// A word's reading, or its characters' readings one by one when the word has no entry.
  private static func reading(ofWord word: String, in romanization: Romanization, lexicon: Lexicon)
    -> String
  {
    lexicon.lookup(word).romanization(romanization)
      ?? word.map { lexicon.lookup(String($0)).romanization(romanization) ?? String($0) }
      .joined(separator: " ")
  }
}
