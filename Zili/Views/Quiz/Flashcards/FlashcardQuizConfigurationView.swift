//
//  FlashcardQuizConfigurationView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// Where the learner sets up a recognition quiz, as a screen in the Quiz tab's navigation stack.
  /// It owns the configuration the quiz reads and the session the form deals, and pushes
  /// ``FlashcardQuizView`` once a deck exists.
  struct FlashcardQuizConfigurationView: View {
    let lexicon: Lexicon

    @State private var configuration: FlashcardQuizConfiguration
    @State private var session: QuizSession?

    var body: some View {
      FlashcardQuizConfigurationForm(lexicon: lexicon, configuration: configuration) { dealt in
        session = dealt
      }
      .navigationTitle("Recognizing")
      .navigationDestination(isPresented: isQuizActive) {
        if let session {
          FlashcardQuizView()
            .environment(configuration)
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

    init(lexicon: Lexicon) {
      self.lexicon = lexicon
      let level = lexicon.availableLevels.first ?? HSKLevel(standard: .new, band: 1)
      _configuration = State(initialValue: FlashcardQuizConfiguration(source: .hskLevels([level])))
    }
  }

  #Preview("From bundle") {
    ConfigurationPreview()
  }

  /// Loads the real ``Lexicon`` so the level picker and word counts reflect the shipped data.
  private struct ConfigurationPreview: View {
    @State private var lexicon: Lexicon?

    var body: some View {
      NavigationStack {
        if let lexicon {
          FlashcardQuizConfigurationView(lexicon: lexicon)
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
