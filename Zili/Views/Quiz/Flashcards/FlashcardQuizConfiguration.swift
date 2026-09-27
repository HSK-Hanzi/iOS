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

  /// Which of the learner's favorites the deck draws, when the favorites are the source.
  var sort: QuizDeckSort

  /// The most cards to draw, or `nil` for the whole source.
  var deckSize: Int?

  /// What these settings' prompt gives the learner to recognize a word from: the Hanzi when it
  /// shows them alone, and the whole word when it shows the reading too or asks from the meaning.
  var recognitionCue: RecognitionCue {
    direction == .chineseToEnglish && !showsReadingWithHanzi ? .hanzi : .word
  }

  /// The tally a miss on these settings counts toward, following ``recognitionCue``.
  var missMode: WordQuizMode {
    switch recognitionCue {
      case .word: .recognizing
      case .hanzi: .recognizingHanzi
    }
  }

  init(
    source: QuizDeckSource,
    direction: PromptDirection = .chineseToEnglish,
    showsReadingWithHanzi: Bool = true,
    sort: QuizDeckSort = .random,
    deckSize: Int? = 20
  ) {
    self.source = source
    self.direction = direction
    self.showsReadingWithHanzi = showsReadingWithHanzi
    self.sort = sort
    self.deckSize = deckSize
  }
}
