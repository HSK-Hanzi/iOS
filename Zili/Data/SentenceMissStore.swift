//
//  SentenceMissStore.swift
//  Zili
//

import Foundation
import SwiftData

/// The learner's per-sentence miss tallies, the single source of truth the UI reads and mutates.
///
/// It mirrors ``WordMissStore`` for sentences, which only the listening quiz tests — so a single
/// tally per sentence suffices. A ``RecordStore`` keeps the ``SentenceMissCount`` records observed
/// and de-duplicated, **summing** a duplicate's tally into the survivor so an offline device's
/// misses aren't lost. Injected into the environment so the listening quiz can record a miss and a
/// sentence's detail can show and reset one.
@MainActor
@Observable
final class SentenceMissStore {
  /// The ids of sentences missed at least once — the pool a "drill missed" deck draws from.
  var missedSentenceIDs: [String] {
    store.all.filter { $0.listeningMisses > 0 }.map(\.sentenceID)
  }

  private let store: RecordStore<SentenceMissCount, String>

  /// Builds a store over `container`'s main context. ``inMemory()`` provides a throwaway one for
  /// previews.
  init(container: ModelContainer) {
    store = RecordStore(
      container: container,
      sortBy: [SortDescriptor(\SentenceMissCount.sentenceID)],
      by: \.sentenceID
    ) { survivor, loser in
      survivor.listeningMisses += loser.listeningMisses
    }
  }

  /// A store backed by an in-memory container, for SwiftUI previews.
  static func inMemory() -> SentenceMissStore {
    let container = RecordStore<SentenceMissCount, String>.inMemoryContainer()
    let store = SentenceMissStore(container: container)
    store.start()
    return store
  }

  /// Opens the store's query, once the app is running. ``AppData`` calls this as it loads; until
  /// it does, the store reads as empty.
  func start() {
    store.start()
  }

  /// How many times the sentence with `id` has been missed in the listening quiz.
  ///
  /// Summed across every record for the sentence: an import can land a duplicate a moment before
  /// the store folds it away, and a tally that dipped in between would read as progress the learner
  /// didn't make.
  func misses(for id: String) -> Int {
    records(for: id).reduce(0) { $0 + $1.listeningMisses }
  }

  /// Records one more miss of the sentence with `id`, creating its record on the first miss.
  func recordMiss(_ id: String) {
    let record = records(for: id).first ?? store.adding(SentenceMissCount(sentenceID: id))
    record.listeningMisses += 1
    store.commit()
  }

  /// Clears the tally for the sentence with `id`, back to zero.
  func reset(_ id: String) {
    store.delete { $0.sentenceID == id }
  }

  /// Clears every sentence's tally — what Settings' "Reset All Missed" drives.
  func resetAll() {
    store.delete()
  }

  private func records(for id: String) -> [SentenceMissCount] {
    store.all.filter { $0.sentenceID == id }
  }
}
