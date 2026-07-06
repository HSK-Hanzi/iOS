//
//  DrawingQuizConfigurationView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// Where the learner sets up a drawing quiz, as a screen in the Quiz tab's navigation stack. It
  /// owns the session the form deals and pushes ``DrawingQuizView`` once a deck exists.
  struct DrawingQuizConfigurationView: View {
    let lexicon: Lexicon

    @State private var session: QuizSession?

    var body: some View {
      DrawingQuizConfigurationForm(lexicon: lexicon) { dealt in
        session = dealt
      }
      .navigationTitle("Drawing")
      .navigationDestination(isPresented: isQuizActive) {
        if let session {
          DrawingQuizView(lexicon: lexicon)
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

  #Preview("From bundle") {
    DrawingConfigurationPreview()
  }

  /// Loads the real ``Lexicon`` so the level picker and character counts reflect the shipped data.
  private struct DrawingConfigurationPreview: View {
    @State private var lexicon: Lexicon?

    var body: some View {
      NavigationStack {
        if let lexicon {
          DrawingQuizConfigurationView(lexicon: lexicon)
        } else {
          ProgressView()
        }
      }
      .environment(FavoritesStore.inMemory())
      .environment(WordMissStore.inMemory())
      .task { lexicon = try? await Lexicon.load() }
    }
  }
#endif
