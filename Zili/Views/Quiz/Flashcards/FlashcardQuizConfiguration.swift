//
//  FlashcardQuizConfiguration.swift
//  Zili
//

import Foundation

/// The learner's flashcard-quiz settings, shared through the environment so the
/// configuration screen writes them and the quiz reads them. Held by reference and observed,
/// so edits on the configuration screen stay live.
@MainActor
@Observable
final class FlashcardQuizConfiguration {
  /// Where the deck's words come from — currently an HSK syllabus band.
  var source: QuizDeckSource

  /// Which element is the prompt the learner recalls from.
  var direction: PromptDirection

  /// Whether a Hanzi prompt also shows the reading (moot when the prompt is the definition).
  var showsReadingWithHanzi: Bool

  /// The most cards to draw, or `nil` for the whole source.
  var deckSize: Int?

  init(
    source: QuizDeckSource,
    direction: PromptDirection = .chineseToEnglish,
    showsReadingWithHanzi: Bool = true,
    deckSize: Int? = 20
  ) {
    self.source = source
    self.direction = direction
    self.showsReadingWithHanzi = showsReadingWithHanzi
    self.deckSize = deckSize
  }
}
