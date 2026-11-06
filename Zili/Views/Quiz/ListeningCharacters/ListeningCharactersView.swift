//
//  ListeningCharactersView.swift
//  Zili
//

import SwiftUI

/// Runs a deck of words to pick out by ear, from the shared ``QuizSession``: each word is said and
/// the learner picks it from a few that look alike in length. A quiz ends on its graded results;
/// practice, which keeps no score, on a plain note offering to go through it again.
struct ListeningCharactersView: View {
  let lexicon: Lexicon
  let purpose: StudyPurpose

  /// Puts practice away, from the close button or once the deck is done. A quiz dismisses itself.
  var onPracticeDone: () -> Void = {}

  @Environment(QuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    Group {
      if session.isFinished {
        switch purpose {
          case .quiz:
            QuizResultsView(onDone: resultsDone)
          case .practice:
            PracticeFinishedView(
              message: "You’ve heard every word in the deck.",
              onRestart: session.restart,
              onDone: onPracticeDone
            )
        }
      } else if let card = session.current {
        ListeningCharactersRoundView(card: card, lexicon: lexicon, purpose: purpose, onClose: close)
          .id(card.word)
      } else {
        QuizEmptyDeckView(description: "The selected levels have no words to hear.")
      }
    }
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
    #endif
  }

  private var close: () -> Void {
    purpose == .quiz ? { dismiss() } : onPracticeDone
  }

  /// On the Mac a quiz owns its window and the results stay up until it is closed; on iOS the quiz
  /// is a pushed screen, so Done pops it.
  private var resultsDone: (() -> Void)? {
    #if os(macOS)
      nil
    #else
      { dismiss() }
    #endif
  }
}

#Preview("Quiz") {
  ListeningCharactersPreview(purpose: .quiz)
}

#Preview("Practice") {
  ListeningCharactersPreview(purpose: .practice)
}

/// Loads the real ``Lexicon`` so the choices are drawn from the shipped syllabus.
private struct ListeningCharactersPreview: View {
  private static let deck = [
    QuizCard(word: "妈妈", hanzi: "妈妈", reading: "mā ma", definition: "mom", hskBand: 1),
    QuizCard(word: "是", hanzi: "是", reading: "shì", definition: "to be", hskBand: 1)
  ]

  let purpose: StudyPurpose

  @State private var lexicon: Lexicon?
  @State private var session = QuizSession(deck: Self.deck)

  var body: some View {
    NavigationStack {
      if let lexicon {
        ListeningCharactersView(lexicon: lexicon, purpose: purpose)
          .environment(session)
      } else {
        ProgressView()
      }
    }
    .environment(FavoritesStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
