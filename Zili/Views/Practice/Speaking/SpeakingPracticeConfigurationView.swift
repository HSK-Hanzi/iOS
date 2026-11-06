//
//  SpeakingPracticeConfigurationView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// Where the learner chooses the words for speaking practice, as a screen in the Practice tab's
  /// navigation stack. It owns the session the form deals and pushes ``SpeakingPracticeView`` once
  /// a deck exists.
  struct SpeakingPracticeConfigurationView: View {
    let lexicon: Lexicon

    @State private var session: QuizSession?

    var body: some View {
      SpeakingQuizConfigurationForm(lexicon: lexicon, purpose: .practice) { dealt in
        session = dealt
      }
      .navigationTitle("Speaking")
      .navigationDestination(isPresented: isPracticeActive) {
        if let session {
          SpeakingPracticeView(lexicon: lexicon) { self.session = nil }
            .environment(session)
        }
      }
    }

    private var isPracticeActive: Binding<Bool> {
      Binding(
        get: { session != nil },
        set: { active in if !active { session = nil } }
      )
    }
  }

  /// Loads the real ``Lexicon`` so the level picker and word counts reflect the shipped data.
  #Preview("From bundle") {
    @Previewable @State var lexicon: Lexicon?

    NavigationStack {
      if let lexicon {
        SpeakingPracticeConfigurationView(lexicon: lexicon)
      } else {
        ProgressView()
      }
    }
    .environment(WordMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
#endif
