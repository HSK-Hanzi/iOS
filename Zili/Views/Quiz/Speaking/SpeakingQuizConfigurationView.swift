//
//  SpeakingQuizConfigurationView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// Where the learner sets up a speaking quiz, as a screen in the Quiz tab's navigation stack. It
  /// owns the session the form deals and pushes ``SpeakingQuizView`` once a deck exists.
  struct SpeakingQuizConfigurationView: View {
    let lexicon: Lexicon

    @State private var session: QuizSession?

    var body: some View {
      SpeakingQuizConfigurationForm(lexicon: lexicon) { dealt in
        session = dealt
      }
      .navigationTitle("Speaking")
      .navigationDestination(isPresented: isQuizActive) {
        if let session {
          SpeakingQuizView(lexicon: lexicon)
            .environment(session)
        }
      }
    }

    private var isQuizActive: Binding<Bool> {
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
        SpeakingQuizConfigurationView(lexicon: lexicon)
      } else {
        ProgressView()
      }
    }
    .environment(FavoritesStore.inMemory())
    .environment(WordMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
#endif
