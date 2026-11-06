//
//  PracticeStages.swift
//  Zili
//

#if os(macOS)
  import SwiftUI

  /// Practice on a deck of words in a Practice window: the form until a deck is dealt, then the
  /// practice in its place. The window lasts, so finishing or closing the practice — `practice`'s
  /// argument — returns to the form rather than closing the window, and the form offers no Cancel.
  struct WordPracticeStage<Practice: View>: View {
    let lexicon: Lexicon
    let mode: WordQuizMode
    @ViewBuilder let practice: (_ onDone: @escaping () -> Void) -> Practice

    @State private var session: QuizSession?

    var body: some View {
      QuizStage(hasDeck: session != nil) {
        if let session {
          practice { self.session = nil }
            .environment(session)
        }
      } configuration: {
        WordQuizConfigurationForm(lexicon: lexicon, mode: mode, purpose: .practice) {
          session = $0
        }
      }
    }
  }

  /// Practice on a deck of sentences in a Practice window, staged the way ``WordPracticeStage``
  /// stages words.
  struct SentencePracticeStage<Practice: View>: View {
    let library: SentenceLibrary
    let mode: SentenceQuizMode
    @ViewBuilder let practice: (_ onDone: @escaping () -> Void) -> Practice

    @State private var session: SentenceQuizSession?

    var body: some View {
      QuizStage(hasDeck: session != nil) {
        if let session {
          practice { self.session = nil }
            .environment(session)
        }
      } configuration: {
        SentenceQuizConfigurationForm(library: library, mode: mode, purpose: .practice) {
          session = $0
        }
      }
    }
  }
#endif
