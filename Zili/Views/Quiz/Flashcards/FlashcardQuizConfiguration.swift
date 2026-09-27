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

extension FlashcardQuizConfiguration {
  /// The sort to deal by: the learner's choice while their favorites are the source, and a random
  /// sample otherwise — a set with no starring dates has no newest or oldest to draw.
  var deckSort: QuizDeckSort {
    source.isFavorites ? sort : .random
  }

  /// Points the quiz at `favorites`, drawn in the order they fall due — what a review is.
  func prepareReview(of favorites: [String]) {
    source = .favorites(favorites)
    sort = .dueForReview
  }

  /// Deals a deck from these settings into a session that records each miss and judgement.
  func deal(
    from lexicon: Lexicon,
    romanization: Romanization,
    wordMisses: WordMissStore,
    reviews: ReviewScheduleStore
  ) -> QuizSession {
    let (cue, missMode) = (recognitionCue, self.missMode)
    let deck = QuizDeckBuilder.build(
      from: lexicon,
      source: source,
      sort: deckSort,
      limit: deckSize,
      romanization: romanization,
      dueDates: reviews.dueDates(for: cue)
    )
    return QuizSession(
      deck: deck,
      onMiss: { wordMisses.recordMiss($0, mode: missMode) },
      onJudge: { reviews.record($1, for: $0, cue: cue) }
    )
  }
}
