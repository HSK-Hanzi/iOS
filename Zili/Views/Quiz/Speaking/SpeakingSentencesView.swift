//
//  SpeakingSentencesView.swift
//  Zili
//

import SwiftUI

/// Runs a deck of sentences to read aloud from the shared ``SentenceQuizSession``: each sentence is
/// shown, read aloud — after hearing it first, in practice — and graded character by character.
/// The turns only start once ``SpeechRecognitionGate`` has readied recognition. A quiz ends on its
/// graded results; practice, which keeps no score, on a plain note offering to go through it again.
struct SpeakingSentencesView: View {
  let lexicon: Lexicon
  let purpose: StudyPurpose

  /// Puts practice away, from the close button or once the deck is done. A quiz dismisses itself.
  var onPracticeDone: () -> Void = {}

  @Environment(SentenceQuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    Group {
      if session.isFinished {
        switch purpose {
          case .quiz:
            SentenceResultsView(onDone: resultsDone)
          case .practice:
            PracticeFinishedView(
              message: "You’ve said every sentence in the deck.",
              onRestart: session.restart,
              onDone: onPracticeDone
            )
        }
      } else if session.current != nil {
        SpeechRecognitionGate { [session] in
          session.current?.hanzi
        } content: { listener in
          if let sentence = session.current {
            SpeakingSentenceRoundView(
              sentence: sentence,
              lexicon: lexicon,
              listener: listener,
              purpose: purpose,
              onClose: close
            )
            .id(sentence.id)
          }
        }
      } else {
        QuizEmptyDeckView(description: "The selected levels have no sentences to say.")
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

#Preview("Practice · echoing") {
  SpeakingSentencesPreview(purpose: .practice)
    .environment(\.speechListenerSource, .scripted(.echo))
}

#Preview("Quiz · misheard") {
  SpeakingSentencesPreview(purpose: .quiz)
    .environment(\.speechListenerSource, .scripted(.mishear))
}

/// Loads the real ``Lexicon`` so what is heard is graded against the shipped readings.
private struct SpeakingSentencesPreview: View {
  private static let deck = [
    PracticeSentence(
      id: "tea",
      hanzi: "我想喝茶。",
      numberedPinyin: "wo3 xiang3 he1 cha2",
      translation: "I want to drink tea."
    )
  ]

  let purpose: StudyPurpose

  @State private var lexicon: Lexicon?
  @State private var session = SentenceQuizSession(deck: Self.deck)

  var body: some View {
    NavigationStack {
      if let lexicon {
        SpeakingSentencesView(lexicon: lexicon, purpose: purpose)
          .environment(session)
      } else {
        ProgressView()
      }
    }
    .task { lexicon = try? await Lexicon.load() }
  }
}
