//
//  SpeakingSentencesConfigurationView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// Where the learner chooses the sentences to read aloud, for a quiz or for practice, as a screen
  /// in its tab's navigation stack. It owns the session the form deals and pushes
  /// ``SpeakingSentencesView`` once a deck exists.
  struct SpeakingSentencesConfigurationView: View {
    let lexicon: Lexicon
    let purpose: StudyPurpose

    @State private var session: SentenceQuizSession?

    var body: some View {
      SentenceQuizConfigurationForm(library: lexicon.sentences, mode: .speaking, purpose: purpose) {
        session = $0
      }
      .navigationTitle("Sentences")
      .navigationDestination(isPresented: isDeckActive) {
        if let session {
          SpeakingSentencesView(lexicon: lexicon, purpose: purpose) { self.session = nil }
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

  /// Loads the real ``Lexicon`` so the level picker and sentence counts reflect the shipped data.
  #Preview("From bundle") {
    @Previewable @State var lexicon: Lexicon?

    NavigationStack {
      if let lexicon {
        SpeakingSentencesConfigurationView(lexicon: lexicon, purpose: .quiz)
      } else {
        ProgressView()
      }
    }
    .environment(SentenceFavoritesStore.inMemory())
    .environment(SentenceMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
#endif
