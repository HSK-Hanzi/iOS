//
//  ListeningQuizConfigurationView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// Where the learner sets up a listening quiz, as a screen in the Quiz tab's navigation stack. It
  /// owns the session the form deals and pushes ``ListeningQuizView`` once a deck exists.
  struct ListeningQuizConfigurationView: View {
    let library: SentenceLibrary

    @State private var session: ListeningQuizSession?

    var body: some View {
      ListeningQuizConfigurationForm(library: library) { dealt in
        session = dealt
      }
      .navigationTitle("Listening")
      .navigationDestination(isPresented: isQuizActive) {
        if let session {
          ListeningQuizView()
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
    ListeningConfigurationPreview()
  }

  /// Loads the real ``SentenceLibrary`` so the level picker and sentence counts reflect the shipped
  /// corpora.
  private struct ListeningConfigurationPreview: View {
    @State private var library: SentenceLibrary?

    var body: some View {
      NavigationStack {
        if let library {
          ListeningQuizConfigurationView(library: library)
        } else {
          ProgressView()
        }
      }
      .environment(SentenceFavoritesStore.inMemory())
      .environment(SentenceMissStore.inMemory())
      .task { library = await SentenceLibrary.load() }
    }
  }
#endif
