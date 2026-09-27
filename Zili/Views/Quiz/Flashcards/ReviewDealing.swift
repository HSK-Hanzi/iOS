//
//  ReviewDealing.swift
//  Zili
//

import SwiftUI

extension View {
  /// Deals a review of the learner's favorites into `session` the first time the view appears, when
  /// the view was opened to start one — from a widget, a control, or a link — rather than to set a
  /// quiz up by hand.
  func dealsReview(
    if isRequested: Bool,
    from lexicon: Lexicon,
    configuration: FlashcardQuizConfiguration,
    into session: Binding<QuizSession?>
  ) -> some View {
    modifier(
      ReviewDealing(
        isRequested: isRequested,
        lexicon: lexicon,
        configuration: configuration,
        session: session
      )
    )
  }
}

/// Deals the review once: coming back to the form from a finished quiz shows the form, not a
/// fresh deck. With nothing starred there is nothing to deal, and the form stays up, set to the
/// learner's favorites — the same empty choice, with Start disabled, that picking it by hand gives.
private struct ReviewDealing: ViewModifier {
  let isRequested: Bool
  let lexicon: Lexicon
  let configuration: FlashcardQuizConfiguration
  @Binding var session: QuizSession?

  @State private var hasDealt = false

  @Environment(FavoritesStore.self)
  private var favorites

  @Environment(WordMissStore.self)
  private var wordMisses

  @Environment(ReviewScheduleStore.self)
  private var reviews

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  func body(content: Content) -> some View {
    content.onAppear(perform: dealIfRequested)
  }

  private func dealIfRequested() {
    guard isRequested, !hasDealt else { return }
    hasDealt = true
    configuration.prepareReview(of: favorites.favoritedWords)
    guard !favorites.favoritedWords.isEmpty else { return }
    session = configuration.deal(
      from: lexicon,
      romanization: romanization,
      wordMisses: wordMisses,
      reviews: reviews
    )
  }
}
