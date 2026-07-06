//
//  AppData.swift
//  Zili
//

import SwiftData
import SwiftUI

/// The app's one load of its language database, shared by every window. Windows read ``state``
/// through ``LexiconGate`` rather than loading a ``Lexicon`` of their own, so a second dictionary
/// or a fifth quiz costs no extra work and every window stars the same words.
@MainActor
@Observable
final class AppData {
  private(set) var state = LoadState.loading

  /// The learner's starred words, over the container's main context.
  let favorites: FavoritesStore

  /// The learner's starred sentences, over the same context.
  let sentenceFavorites: SentenceFavoritesStore

  /// The learner's per-word quiz miss tallies, over the same context.
  let wordMisses: WordMissStore

  /// The learner's per-sentence quiz miss tallies, over the same context.
  let sentenceMisses: SentenceMissStore

  /// Whether the database is in hand — the File menu's new-quiz items stay inert until it is.
  var isLoaded: Bool {
    if case .loaded = state { true } else { false }
  }

  /// Guards the load against the several windows that each ask for it as they appear.
  private var isLoading = false

  /// The test-only launch options; ``UITestConfiguration/disabled`` for a shipped launch.
  private let uiTest: UITestConfiguration

  init(container: ModelContainer, uiTest: UITestConfiguration = .disabled) {
    self.uiTest = uiTest
    favorites = FavoritesStore(context: container.mainContext)
    sentenceFavorites = SentenceFavoritesStore(context: container.mainContext)
    wordMisses = WordMissStore(context: container.mainContext)
    sentenceMisses = SentenceMissStore(context: container.mainContext)
    seedForUITestingIfNeeded()
  }

  /// Loads the language database, and loads it again when a learner retries after a failure.
  /// Concurrent callers — one per window — collapse onto the first.
  func load() async {
    guard !isLoaded, !isLoading else { return }
    isLoading = true
    defer { isLoading = false }

    state = .loading
    guard !uiTest.failsLexiconLoad else {
      state = .failed
      return
    }
    do {
      state = .loaded(try await Lexicon.load())
    } catch {
      state = .failed
    }
  }

  /// Pre-populates the learner's stores with a fixed set of favorites and misses when a UI test
  /// asked for them, so the Favorites and Missed screens and "Reset All Missed" have deterministic
  /// content. Inert on a shipped launch.
  private func seedForUITestingIfNeeded() {
    guard uiTest.isEnabled else { return }
    if uiTest.seedsFavorites {
      favorites.addAll(["我", "你", "好"])
    }
    if uiTest.seedsMisses {
      wordMisses.recordMiss("是", mode: .recognizing)
      wordMisses.recordMiss("他", mode: .writing)
    }
  }

  /// How far along the load of the language database is.
  enum LoadState {
    case loading
    case loaded(Lexicon)
    case failed
  }
}

extension AppData {
  /// An instance over a throwaway in-memory store, for SwiftUI previews.
  static func preview() -> AppData {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    guard
      let container = try? ModelContainer(
        for: FavoriteWord.self,
        FavoriteSentence.self,
        WordMissCount.self,
        SentenceMissCount.self,
        configurations: configuration
      )
    else {
      fatalError("In-memory model container for previews should never fail to build.")
    }
    return AppData(container: container)
  }
}
