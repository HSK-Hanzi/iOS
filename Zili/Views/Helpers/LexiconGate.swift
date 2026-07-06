//
//  LexiconGate.swift
//  Zili
//

import SwiftUI

/// Stands between a window and the app's language database: a spinner while it loads, a retry
/// screen if it fails, and the window's own content once the ``Lexicon`` is in hand. Every
/// window's root wraps itself in one, and each shares the single load held by ``AppData``, so a
/// retry from any window fills them all. Puts the shared ``FavoritesStore`` in the environment
/// for whatever it wraps.
struct LexiconGate<Content: View>: View {
  @ViewBuilder let content: (Lexicon) -> Content

  @Environment(AppData.self)
  private var appData

  var body: some View {
    Group {
      switch appData.state {
        case .loaded(let lexicon):
          content(lexicon)
            .environment(appData.favorites)
            .environment(appData.sentenceFavorites)
            .environment(appData.wordMisses)
            .environment(appData.sentenceMisses)
        case .failed:
          LoadFailureView { await appData.load() }
        case .loading:
          ProgressView()
      }
    }
    .task { await appData.load() }
  }
}

/// Shown when the language database can't be loaded, offering a retry.
private struct LoadFailureView: View {
  let retry: () async -> Void

  var body: some View {
    ContentUnavailableView {
      Label("Couldn’t Load Dictionary", systemImage: "exclamationmark.triangle")
    } description: {
      Text("The language database couldn’t be opened.")
    } actions: {
      Button("Try Again") {
        Task { await retry() }
      }
      .accessibilityIdentifier(AccessibilityID.loadFailureRetry)
    }
  }
}

#Preview("Loading → loaded") {
  LexiconGate { lexicon in
    Text("Loaded \(lexicon.availableLevels.count, format: .number) HSK levels.")
      .padding()
  }
  .environment(AppData.preview())
}

#Preview("Load failure") {
  LoadFailureView {}
}
