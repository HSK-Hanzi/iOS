//
//  FavoritesStore.swift
//  Zili
//

import CoreData
import Foundation
import SwiftData

/// The learner's starred words, the single source of truth the UI reads and mutates.
///
/// It wraps a SwiftData ``ModelContext`` and keeps an in-memory mirror of the favorited
/// headwords so membership checks and star toggles are cheap and reactive. It is injected into
/// the environment (like the app's other capabilities) so any screen — a word's entry, the
/// Practice grid, the quiz results — can reach it.
///
/// CloudKit can't enforce uniqueness, so two devices starring the same word each create a
/// ``FavoriteWord``. On every reload the store de-duplicates: it keeps one record per headword
/// and deletes the rest, choosing the survivor by ``FavoriteWord/identifier`` so every device
/// converges on the same winner.
@MainActor
@Observable
final class FavoritesStore {
  /// The favorited headwords, most recently added first — the order the Practice grid shows.
  private(set) var favoritedWords: [String] = []

  private let context: ModelContext
  private var membership: Set<String> = []

  /// The remote-change observer token, held so `deinit` can hand it to the thread-safe
  /// `NotificationCenter.removeObserver`. Plumbing, not observable state.
  @ObservationIgnored nonisolated(unsafe) private var remoteChangeObserver: (any NSObjectProtocol)?

  /// Builds a store over `context` and loads the current favorites. Pass the environment's
  /// `modelContext`; ``inMemory()`` provides a throwaway one for previews.
  init(context: ModelContext) {
    self.context = context
    observeRemoteChanges()
    reload()
  }

  /// A store backed by an in-memory container, for SwiftUI previews.
  static func inMemory() -> FavoritesStore {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    guard
      let container = try? ModelContainer(for: FavoriteWord.self, configurations: configuration)
    else {
      fatalError("In-memory model container for previews should never fail to build.")
    }
    return FavoritesStore(context: ModelContext(container))
  }

  /// Whether `word` is currently starred.
  func isFavorite(_ word: String) -> Bool {
    membership.contains(word)
  }

  /// Stars `word` if it isn't already, or unstars it if it is.
  func toggle(_ word: String) {
    if isFavorite(word) {
      remove(word)
    } else {
      insert(word)
    }
    save()
    reload()
  }

  /// Stars every word in `words` that isn't already a favorite, ignoring the rest.
  func addAll(_ words: [String]) {
    let additions = words.filter { !isFavorite($0) }
    guard !additions.isEmpty else { return }
    for word in additions {
      insert(word)
    }
    save()
    reload()
  }

  /// Unstars every favorited word.
  func clearAll() {
    for favorite in fetchAll() {
      context.delete(favorite)
    }
    save()
    reload()
  }

  private func insert(_ word: String) {
    context.insert(FavoriteWord(word: word))
    membership.insert(word)
  }

  private func remove(_ word: String) {
    for favorite in fetchAll() where favorite.word == word {
      context.delete(favorite)
    }
    membership.remove(word)
  }

  /// Reconciles the in-memory mirror with the store after de-duplicating it, so another device's
  /// stars appear and any duplicates they introduced are resolved. Favorites carry no count to
  /// merge, so the survivor is simply kept and the rest deleted.
  private func reload() {
    if deduplicate(fetchAll(), by: \.word, in: context) {
      save()
    }
    let favorites = fetchAll().sorted { $0.dateAdded > $1.dateAdded }
    favoritedWords = favorites.map(\.word)
    membership = Set(favoritedWords)
  }

  private func fetchAll() -> [FavoriteWord] {
    (try? context.fetch(FetchDescriptor<FavoriteWord>())) ?? []
  }

  private func save() {
    try? context.save()
  }

  /// Reloads when CloudKit imports remote changes, so another device's stars appear and any
  /// duplicates they introduced are resolved.
  private func observeRemoteChanges() {
    guard !context.isStoredInMemoryOnly else { return }
    remoteChangeObserver = NotificationCenter.default.addObserver(
      forName: .NSPersistentStoreRemoteChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.reload() }
    }
  }

  deinit {
    if let remoteChangeObserver {
      NotificationCenter.default.removeObserver(remoteChangeObserver)
    }
  }
}
