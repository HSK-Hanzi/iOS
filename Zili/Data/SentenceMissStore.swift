//
//  SentenceMissStore.swift
//  Zili
//

import Foundation
import SwiftData

/// Which quiz a sentence was missed in — the listening quiz tests hearing it and typing it back,
/// the speaking quiz tests reading it aloud — so a sentence's misses are tallied separately per
/// skill.
enum SentenceQuizMode: CaseIterable, Sendable {
  case listening
  case speaking
}

/// The learner's per-sentence miss tallies, the single source of truth the UI reads and mutates.
///
/// It mirrors ``WordMissStore`` for sentences. A ``RecordStore`` keeps the ``SentenceMissCount``
/// records observed and de-duplicated, **summing** a duplicate's tallies into the survivor so an
/// offline device's misses aren't lost. Injected into the environment so a quiz can record a miss
/// and a sentence's detail can show and reset one.
@MainActor
@Observable
final class SentenceMissStore {
  /// The ids of sentences missed at least once in any quiz — the pool the Reading Sentences
  /// browser's Missed set draws from.
  var missedSentenceIDs: [String] {
    store.all.filter { $0.totalMisses > 0 }.map(\.sentenceID)
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
      survivor.speakingMisses += loser.speakingMisses
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

  /// The ids of sentences missed at least once in `mode` — the pool that quiz's "drill missed"
  /// deck draws from.
  func sentencesMissed(in mode: SentenceQuizMode) -> [String] {
    store.all.filter { $0.misses(in: mode) > 0 }.map(\.sentenceID)
  }

  /// How many times the sentence with `id` has been missed, across every quiz.
  ///
  /// Summed across every record for the sentence: an import can land a duplicate a moment before
  /// the store folds it away, and a tally that dipped in between would read as progress the learner
  /// didn't make.
  func misses(for id: String) -> Int {
    records(for: id).reduce(0) { $0 + $1.totalMisses }
  }

  /// How many times the sentence with `id` has been missed in `mode`.
  func misses(for id: String, mode: SentenceQuizMode) -> Int {
    records(for: id).reduce(0) { $0 + $1.misses(in: mode) }
  }

  /// Records one more miss of the sentence with `id` in `mode`, creating its record on the first
  /// miss.
  func recordMiss(_ id: String, mode: SentenceQuizMode) {
    let record = records(for: id).first ?? store.adding(SentenceMissCount(sentenceID: id))
    switch mode {
      case .listening: record.listeningMisses += 1
      case .speaking: record.speakingMisses += 1
    }
    store.commit()
  }

  /// Clears every quiz's tally for the sentence with `id`, back to zero.
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

extension SentenceMissCount {
  /// This record's tallies summed across every quiz.
  fileprivate var totalMisses: Int {
    SentenceQuizMode.allCases.reduce(0) { $0 + misses(in: $1) }
  }

  /// This record's tally for `mode`.
  fileprivate func misses(in mode: SentenceQuizMode) -> Int {
    switch mode {
      case .listening: listeningMisses
      case .speaking: speakingMisses
    }
  }
}
