//
//  SentenceMissStore.swift
//  Zili
//

import CoreData
import Foundation
import SwiftData

/// The learner's per-sentence miss tallies, the single source of truth the UI reads and mutates.
///
/// It mirrors ``WordMissStore`` for sentences, which only the listening quiz tests — so a single
/// tally per sentence suffices. A SwiftData ``ModelContext`` backs an in-memory mirror of each
/// sentence's count so its detail can show and reset one cheaply and reactively, injected into the
/// environment so the listening quiz can record a miss. On every reload it de-duplicates the records
/// CloudKit can produce for the same sentence, keeping one and **summing** the rest into it so an
/// offline device's tally isn't lost — see ``deduplicate(_:by:in:consolidate:)``.
@MainActor
@Observable
final class SentenceMissStore {
  private let context: ModelContext
  private var counts: [String: Int] = [:]

  /// The ids of sentences missed at least once — the pool a "drill missed" deck draws from.
  var missedSentenceIDs: [String] {
    counts.compactMap { id, count in count > 0 ? id : nil }
  }

  /// The remote-change observer token, held so `deinit` can hand it to the thread-safe
  /// `NotificationCenter.removeObserver`. Plumbing, not observable state.
  @ObservationIgnored nonisolated(unsafe) private var remoteChangeObserver: (any NSObjectProtocol)?

  /// Builds a store over `context` and loads the current tallies. Pass the environment's
  /// `modelContext`; ``inMemory()`` provides a throwaway one for previews.
  init(context: ModelContext) {
    self.context = context
    observeRemoteChanges()
    reload()
  }

  /// A store backed by an in-memory container, for SwiftUI previews.
  static func inMemory() -> SentenceMissStore {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    guard
      let container = try? ModelContainer(
        for: SentenceMissCount.self,
        configurations: configuration
      )
    else {
      fatalError("In-memory model container for previews should never fail to build.")
    }
    return SentenceMissStore(context: ModelContext(container))
  }

  /// How many times the sentence with `id` has been missed in the listening quiz.
  func misses(for id: String) -> Int {
    counts[id] ?? 0
  }

  /// Records one more miss of the sentence with `id`, creating its record on the first miss.
  func recordMiss(_ id: String) {
    let record = record(for: id) ?? insert(id)
    record.listeningMisses += 1
    save()
    reload()
  }

  /// Clears the tally for the sentence with `id`, back to zero.
  func reset(_ id: String) {
    for record in fetchAll() where record.sentenceID == id {
      context.delete(record)
    }
    save()
    reload()
  }

  /// Clears every sentence's tally — for the future settings page's "Reset All".
  func resetAll() {
    for record in fetchAll() {
      context.delete(record)
    }
    save()
    reload()
  }

  private func insert(_ id: String) -> SentenceMissCount {
    let record = SentenceMissCount(sentenceID: id)
    context.insert(record)
    return record
  }

  private func record(for id: String) -> SentenceMissCount? {
    var descriptor = FetchDescriptor<SentenceMissCount>(
      predicate: #Predicate { $0.sentenceID == id }
    )
    descriptor.fetchLimit = 1
    return (try? context.fetch(descriptor))?.first
  }

  /// Reconciles the in-memory mirror with the store after de-duplicating it, summing the tallies of
  /// records CloudKit produced for the same sentence so no device's misses are lost.
  private func reload() {
    let merged = deduplicate(fetchAll(), by: \.sentenceID, in: context) { survivor, loser in
      survivor.listeningMisses += loser.listeningMisses
    }
    if merged {
      save()
    }
    counts = Dictionary(
      fetchAll().map { ($0.sentenceID, $0.listeningMisses) },
      uniquingKeysWith: +
    )
  }

  private func fetchAll() -> [SentenceMissCount] {
    (try? context.fetch(FetchDescriptor<SentenceMissCount>())) ?? []
  }

  private func save() {
    try? context.save()
  }

  /// Reloads when CloudKit imports remote changes, so another device's misses appear and any
  /// duplicates they introduced are summed and resolved.
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
