//
//  ListeningQuizConfigurationView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// Where the learner chooses the sentences to hear and type back, for a quiz or for practice, as
  /// a screen in its tab's navigation stack. It owns the session the form deals and pushes
  /// ``ListeningQuizView`` once a deck exists.
  struct ListeningQuizConfigurationView: View {
    let library: SentenceLibrary
    var purpose = StudyPurpose.quiz

    @State private var session: SentenceQuizSession?

    var body: some View {
      SentenceQuizConfigurationForm(library: library, mode: .listening, purpose: purpose) { dealt in
        session = dealt
      }
      .navigationTitle("Sentences")
      .navigationDestination(isPresented: isQuizActive) {
        if let session {
          ListeningQuizView(purpose: purpose) { self.session = nil }
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

  /// Loads the real ``SentenceLibrary`` so the level picker and sentence counts reflect the shipped
  /// corpora.
  #Preview("From bundle") {
    @Previewable @State var library: SentenceLibrary?

    NavigationStack {
      if let library {
        ListeningQuizConfigurationView(library: library)
      } else {
        ProgressView()
      }
    }
    .environment(SentenceFavoritesStore.inMemory())
    .environment(SentenceMissStore.inMemory())
    .task { library = SentenceLibrary.load() }
  }
#endif
