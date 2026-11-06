//
//  SpokenVerdict.swift
//  Zili
//

import Foundation

/// What one attempt at saying a word earned. Only the transcript's Chinese counts, so a transcript
/// with none — silence, or a conversation nearby — is ``unheard`` rather than wrong.
enum SpokenVerdict: Hashable {
  /// Nothing Chinese was heard, so the attempt is asked for again rather than graded.
  case unheard
  /// Whether the word was said, with the reading of what was heard in the learner's romanization.
  case graded(isCorrect: Bool, heard: String)

  /// Grades `heard` against `card`'s word, reading what was heard by its sound rather than by the
  /// characters the recognizer happened to pick for it.
  @MainActor
  init(_ heard: Heard, for card: QuizCard, lexicon: Lexicon, romanization: Romanization) {
    let reading =
      heard.best.map { SpokenReading.reading(of: $0, in: romanization, lexicon: lexicon) } ?? ""
    guard !reading.isEmpty else {
      self = .unheard
      return
    }
    let isCorrect = SpokenAnswer.matches(heard, word: card.word) {
      lexicon.lookup($0).numberedReadings
    }
    self = .graded(isCorrect: isCorrect, heard: reading)
  }
}
