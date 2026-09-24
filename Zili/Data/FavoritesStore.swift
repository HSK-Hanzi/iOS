//
//  FavoritesStore.swift
//  Zili
//

import Foundation
import SwiftData

/// The learner's starred words, the single source of truth the UI reads and mutates.
///
/// A ``RecordStore`` keeps the ``FavoriteWord`` records observed, ordered and de-duplicated; this
/// adds the vocabulary the app speaks in. It is injected into the environment (like the app's
/// other capabilities) so any screen — a word's entry, the Practice grid, the quiz results — can
/// reach it.
@MainActor
@Observable
final class FavoritesStore {
  /// The favorited headwords, most recently added first — the order the Practice grid shows.
  var favoritedWords: [String] {
    store.all.map(\.word)
  }

  private let store: RecordStore<FavoriteWord, String>

  /// Builds a store over `container`'s main context. ``inMemory()`` provides a throwaway one for
  /// previews.
  init(container: ModelContainer) {
    store = RecordStore(
      container: container,
      sortBy: [SortDescriptor(\FavoriteWord.dateAdded, order: .reverse)],
      by: \.word
    )
  }

  /// A store backed by an in-memory container, for SwiftUI previews.
  static func inMemory() -> FavoritesStore {
    let container = RecordStore<FavoriteWord, String>.inMemoryContainer()
    let store = FavoritesStore(container: container)
    store.start()
    return store
  }

  /// Opens the store's query, once the app is running. ``AppData`` calls this as it loads; until
  /// it does, the store reads as empty.
  func start() {
    store.start()
  }

  /// Whether `word` is currently starred.
  func isFavorite(_ word: String) -> Bool {
    store.all.contains { $0.word == word }
  }

  /// Stars `word` if it isn't already, or unstars it if it is.
  func toggle(_ word: String) {
    if isFavorite(word) {
      store.delete { $0.word == word }
    } else {
      store.insert(FavoriteWord(word: word))
    }
  }

  /// Stars every word in `words` that isn't already a favorite, ignoring the rest.
  func addAll(_ words: [String]) {
    let additions = words.filter { !isFavorite($0) }
    guard !additions.isEmpty else { return }
    for word in additions {
      store.adding(FavoriteWord(word: word))
    }
    store.commit()
  }

  /// Unstars every favorited word.
  func clearAll() {
    store.delete()
  }
}
