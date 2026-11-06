//
//  SpeakingPracticeStage.swift
//  Zili
//

#if os(macOS)
  import SwiftUI

  /// Speaking practice in the Practice Speaking window: the form until a deck is dealt, then the
  /// practice in its place. The window lasts, so finishing or closing the practice returns to the
  /// form rather than closing the window, and the form offers no Cancel.
  struct SpeakingPracticeStage: View {
    let lexicon: Lexicon

    @State private var session: QuizSession?

    var body: some View {
      QuizStage(hasDeck: session != nil) {
        if let session {
          SpeakingPracticeView(lexicon: lexicon) { self.session = nil }
            .environment(session)
        }
      } configuration: {
        SpeakingQuizConfigurationForm(lexicon: lexicon, purpose: .practice) { session = $0 }
      }
    }
  }
#endif
