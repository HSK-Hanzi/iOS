//
//  SpeakingQuizView.swift
//  Zili
//

import SwiftUI

/// Runs a speaking quiz from the shared ``QuizSession``: each word is shown, the learner says it,
/// and what the recognizer heard is graded against it. The rounds only start once
/// ``SpeechRecognitionGate`` has readied recognition. The ``Lexicon`` comes along to read what was
/// heard.
struct SpeakingQuizView: View {
  let lexicon: Lexicon

  @Environment(QuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    Group {
      if session.isFinished {
        QuizResultsView(onDone: doneAction)
      } else if session.current != nil {
        SpeechRecognitionGate { [session] in
          session.current?.hanzi
        } content: { listener in
          if let card = session.current {
            SpeakingRoundView(card: card, lexicon: lexicon, listener: listener)
              .id(card.word)
          }
        }
      } else {
        QuizEmptyDeckView(description: "The selected levels have no words to say.")
      }
    }
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
    #endif
  }

  /// On the Mac the quiz owns its window and the results stay up until it is closed; on iOS the
  /// quiz is a pushed screen, so Done pops it.
  private var doneAction: (() -> Void)? {
    #if os(macOS)
      nil
    #else
      { dismiss() }
    #endif
  }
}

#Preview("Round · echoing") {
  SpeakingQuizPreview()
    .environment(\.speechListenerSource, .scripted(.echo))
}

#Preview("Round · misheard") {
  SpeakingQuizPreview()
    .environment(\.speechListenerSource, .scripted(.mishear))
}

#Preview("Unavailable") {
  SpeakingQuizPreview()
    .environment(\.speechListenerSource, .scripted(.unavailableUntilRetried))
}

/// Loads the real ``Lexicon`` so what is heard is graded against the shipped readings.
private struct SpeakingQuizPreview: View {
  private static let deck = [
    QuizCard(word: "你好", hanzi: "你好", reading: "nǐ hǎo", definition: "hello"),
    QuizCard(word: "市", hanzi: "市", reading: "shì", definition: "city")
  ]

  @State private var lexicon: Lexicon?

  var body: some View {
    NavigationStack {
      if let lexicon {
        SpeakingQuizView(lexicon: lexicon)
          .environment(QuizSession(deck: Self.deck))
      } else {
        ProgressView()
      }
    }
    .environment(FavoritesStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
