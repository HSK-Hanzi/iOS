//
//  SentenceFavoritesStore.swift
//  Zili
//

import Foundation
import SwiftData

/// The learner's starred sentences, the single source of truth the UI reads and mutates.
///
/// It mirrors ``FavoritesStore`` for sentences: a ``RecordStore`` keeps the ``FavoriteSentence``
/// records observed, ordered and de-duplicated, and this adds the vocabulary the app speaks in.
/// Injected into the environment so any screen — a sentence's detail, the practice list, the
/// listening-quiz results — can reach it.
@MainActor
@Observable
final class SentenceFavoritesStore {
  /// The favorited sentence ids, most recently added first — the order the practice list shows.
  var favoritedIDs: [String] {
    store.all.map(\.sentenceID)
  }

  private let store: RecordStore<FavoriteSentence, String>

  /// Builds a store over `container`'s main context. ``inMemory()`` provides a throwaway one for
  /// previews.
  init(container: ModelContainer) {
    store = RecordStore(
      container: container,
      sortBy: [SortDescriptor(\FavoriteSentence.dateAdded, order: .reverse)],
      by: \.sentenceID
    )
  }

  /// A store backed by an in-memory container, for SwiftUI previews.
  static func inMemory() -> SentenceFavoritesStore {
    let container = RecordStore<FavoriteSentence, String>.inMemoryContainer()
    let store = SentenceFavoritesStore(container: container)
    store.start()
    return store
  }

  /// Opens the store's query, once the app is running. ``AppData`` calls this as it loads; until
  /// it does, the store reads as empty.
  func start() {
    store.start()
  }

  /// Whether `id` is currently starred.
  func isFavorite(_ id: String) -> Bool {
    store.all.contains { $0.sentenceID == id }
  }

  /// Stars `id` if it isn't already, or unstars it if it is.
  func toggle(_ id: String) {
    if isFavorite(id) {
      store.delete { $0.sentenceID == id }
    } else {
      store.insert(FavoriteSentence(sentenceID: id))
    }
  }

  /// Unstars every favorited sentence.
  func clearAll() {
    store.delete()
  }
}
