//
//  SpeakingPracticeView.swift
//  Zili
//

import SwiftUI

/// Runs speaking practice through the shared ``QuizSession``: each word is said for the learner to
/// say back, then turned over to its reading, meaning and a verdict on what was heard. The turns
/// only start once ``SpeechRecognitionGate`` has readied recognition. Practice keeps no score, so
/// the deck ends on a plain note offering to go through it again.
struct SpeakingPracticeView: View {
  let lexicon: Lexicon

  /// Puts practice away, from the close button or once the deck is done.
  let onDone: () -> Void

  @Environment(QuizSession.self)
  private var session

  var body: some View {
    Group {
      if session.isFinished {
        PracticeFinishedView(onRestart: session.restart, onDone: onDone)
      } else if session.current != nil {
        SpeechRecognitionGate { [session] in
          session.current?.hanzi
        } content: { listener in
          if let card = session.current {
            SpeakingPracticeRoundView(
              card: card,
              lexicon: lexicon,
              listener: listener,
              onClose: onDone
            )
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
}

/// The end of the deck: no grade, just the way to go through it again or to finish.
private struct PracticeFinishedView: View {
  let onRestart: () -> Void
  let onDone: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("All Done", systemImage: "checkmark.circle")
        .accessibilityIdentifier(AccessibilityID.speakingPracticeFinished)
    } description: {
      Text("You’ve said every word in the deck.")
    } actions: {
      Button("Practice Again", action: onRestart)
        .glassButton(prominent: true)
        .accessibilityIdentifier(AccessibilityID.speakingPracticeAgain)
      Button("Done", action: onDone)
        .glassButton()
    }
    .foregroundStyle(QuizStyle.chromeLabel)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .quizAmbientBackground(QuizStyle.ambientGradient)
  }
}

#Preview("Echoing") {
  SpeakingPracticePreview()
    .environment(\.speechListenerSource, .scripted(.echo))
}

#Preview("Misheard") {
  SpeakingPracticePreview()
    .environment(\.speechListenerSource, .scripted(.mishear))
}

#Preview("Finished") {
  PracticeFinishedView(onRestart: {}, onDone: {})
}

/// Loads the real ``Lexicon`` so what is heard is graded against the shipped readings.
private struct SpeakingPracticePreview: View {
  private static let deck = [
    QuizCard(word: "你好", hanzi: "你好", reading: "nǐ hǎo", definition: "hello"),
    QuizCard(word: "市", hanzi: "市", reading: "shì", definition: "city")
  ]

  @State private var lexicon: Lexicon?
  @State private var session = QuizSession(deck: Self.deck)

  var body: some View {
    NavigationStack {
      if let lexicon {
        SpeakingPracticeView(lexicon: lexicon, onDone: {})
          .environment(session)
      } else {
        ProgressView()
      }
    }
    .task { lexicon = try? await Lexicon.load() }
  }
}
