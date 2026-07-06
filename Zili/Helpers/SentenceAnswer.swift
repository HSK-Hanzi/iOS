//
//  SentenceAnswer.swift
//  Zili
//

import Foundation

/// Grades a listening-quiz answer: the learner hears a sentence and types it back, and we compare
/// what they typed to the expected Hanzi. Punctuation and spacing don't count — a learner isn't
/// expected to guess whether the sentence ended in a full stop or a question mark, or to place the
/// spaces a keyboard might insert — so both sides are stripped of whitespace and punctuation and
/// canonicalized before they're compared. The match is on the characters that carry the meaning.
enum SentenceAnswer {
  /// The characters dropped before comparing: whitespace, and punctuation and symbols in either
  /// script (a full-width `，。？！` counts the same as an ASCII `,.?!`).
  private static let ignored = CharacterSet.whitespacesAndNewlines
    .union(.punctuationCharacters)
    .union(.symbols)

  /// Whether `typed` answers `expected`, ignoring whitespace and punctuation. An expected sentence
  /// with no comparable characters never matches, so a blank answer can't score.
  static func matches(_ typed: String, expected: String) -> Bool {
    let expected = normalized(expected)
    return !expected.isEmpty && normalized(typed) == expected
  }

  /// `text` reduced to its meaning-bearing characters: canonicalized (NFC) and stripped of
  /// whitespace, punctuation, and symbols.
  static func normalized(_ text: String) -> String {
    let scalars = text
      .precomposedStringWithCanonicalMapping
      .unicodeScalars
      .filter { !ignored.contains($0) }
    return String(String.UnicodeScalarView(scalars))
  }
}
