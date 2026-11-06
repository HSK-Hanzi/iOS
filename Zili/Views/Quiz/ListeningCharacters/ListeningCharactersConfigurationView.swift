//
//  ListeningCharactersConfigurationView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// Where the learner chooses the words to pick out by ear, for a quiz or for practice, as a
  /// screen in its tab's navigation stack. It owns the session the form deals and pushes
  /// ``ListeningCharactersView`` once a deck exists.
  struct ListeningCharactersConfigurationView: View {
    let lexicon: Lexicon
    let purpose: StudyPurpose

    @State private var session: QuizSession?

    var body: some View {
      WordQuizConfigurationForm(lexicon: lexicon, mode: .listening, purpose: purpose) { dealt in
        session = dealt
      }
      .navigationTitle("Characters")
      .navigationDestination(isPresented: isDeckActive) {
        if let session {
          ListeningCharactersView(lexicon: lexicon, purpose: purpose) { self.session = nil }
            .environment(session)
        }
      }
    }

    private var isDeckActive: Binding<Bool> {
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
        ListeningCharactersConfigurationView(lexicon: lexicon, purpose: .quiz)
      } else {
        ProgressView()
      }
    }
    .environment(WordMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
#endif
