//
//  SentenceFavoritesStore.swift
//  Zili
//

import CoreData
import Foundation
import SwiftData

/// The learner's starred sentences, the single source of truth the UI reads and mutates.
///
/// It mirrors ``FavoritesStore`` for sentences: a SwiftData ``ModelContext`` with an in-memory
/// mirror of the favorited sentence ids so membership checks and star toggles are cheap and
/// reactive, injected into the environment so any screen — a sentence's detail, the practice list,
/// the listening-quiz results — can reach it. On every reload it de-duplicates the records CloudKit
/// can produce for the same sentence, keeping one and deleting the rest, choosing the survivor by
/// ``FavoriteSentence/identifier`` so every device converges on the same winner.
@MainActor
@Observable
final class SentenceFavoritesStore {
  /// The favorited sentence ids, most recently added first — the order the practice list shows.
  private(set) var favoritedIDs: [String] = []

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
  static func inMemory() -> SentenceFavoritesStore {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    guard
      let container = try? ModelContainer(for: FavoriteSentence.self, configurations: configuration)
    else {
      fatalError("In-memory model container for previews should never fail to build.")
    }
    return SentenceFavoritesStore(context: ModelContext(container))
  }

  /// Whether `id` is currently starred.
  func isFavorite(_ id: String) -> Bool {
    membership.contains(id)
  }

  /// Stars `id` if it isn't already, or unstars it if it is.
  func toggle(_ id: String) {
    if isFavorite(id) {
      remove(id)
    } else {
      insert(id)
    }
    save()
    reload()
  }

  /// Unstars every favorited sentence.
  func clearAll() {
    for favorite in fetchAll() {
      context.delete(favorite)
    }
    save()
    reload()
  }

  private func insert(_ id: String) {
    context.insert(FavoriteSentence(sentenceID: id))
    membership.insert(id)
  }

  private func remove(_ id: String) {
    for favorite in fetchAll() where favorite.sentenceID == id {
      context.delete(favorite)
    }
    membership.remove(id)
  }

  /// Reconciles the in-memory mirror with the store after de-duplicating it, so another device's
  /// stars appear and any duplicates they introduced are resolved. Favorites carry no count to
  /// merge, so the survivor is simply kept and the rest deleted.
  private func reload() {
    if deduplicate(fetchAll(), by: \.sentenceID, in: context) {
      save()
    }
    let favorites = fetchAll().sorted { $0.dateAdded > $1.dateAdded }
    favoritedIDs = favorites.map(\.sentenceID)
    membership = Set(favoritedIDs)
  }

  private func fetchAll() -> [FavoriteSentence] {
    (try? context.fetch(FetchDescriptor<FavoriteSentence>())) ?? []
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
