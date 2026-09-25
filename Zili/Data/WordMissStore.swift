//
//  WordMissStore.swift
//  Zili
//

import Foundation
import SwiftData

/// Which quiz a word was missed in — the drawing quiz tests writing a character, the flashcard quiz
/// tests recognizing a word — so a word's misses are tallied separately per skill.
enum WordQuizMode: Sendable {
  case writing
  case recognizing
}

/// The learner's per-word miss tallies, the single source of truth the UI reads and mutates.
///
/// A ``RecordStore`` keeps the ``WordMissCount`` records observed and de-duplicated, **summing** a
/// duplicate's tallies into the survivor so an offline device's misses aren't lost. This adds the
/// vocabulary the app speaks in, and is injected into the environment so a quiz can record a miss
/// and a dictionary entry can show and reset one.
@MainActor
@Observable
final class WordMissStore {
  /// The words missed at least once in any mode — the pool the Practice browser's Missed set draws
  /// from, mirroring ``SentenceMissStore/missedSentenceIDs``.
  var missedWords: [String] {
    store.all.filter { $0.writingMisses + $0.recognizingMisses > 0 }.map(\.word)
  }

  private let store: RecordStore<WordMissCount, String>

  /// Builds a store over `container`'s main context. ``inMemory()`` provides a throwaway one for
  /// previews.
  init(container: ModelContainer) {
    store = RecordStore(
      container: container,
      sortBy: [SortDescriptor(\WordMissCount.word)],
      by: \.word
    ) { survivor, loser in
      survivor.writingMisses += loser.writingMisses
      survivor.recognizingMisses += loser.recognizingMisses
    }
  }

  /// A store backed by an in-memory container, for SwiftUI previews.
  static func inMemory() -> WordMissStore {
    let container = RecordStore<WordMissCount, String>.inMemoryContainer()
    let store = WordMissStore(container: container)
    store.start()
    return store
  }

  /// Opens the store's query, once the app is running. ``AppData`` calls this as it loads; until
  /// it does, the store reads as empty.
  func start() {
    store.start()
  }

  /// How many times `word` has been missed in `mode`.
  ///
  /// Summed across every record for the word: an import can land a duplicate a moment before the
  /// store folds it away, and a tally that dipped in between would read as progress the learner
  /// didn't make.
  func misses(for word: String, mode: WordQuizMode) -> Int {
    records(for: word).reduce(0) { $0 + $1.misses(in: mode) }
  }

  /// How many times `word` has been missed across every mode — what gates its entry's stat.
  func totalMisses(for word: String) -> Int {
    misses(for: word, mode: .writing) + misses(for: word, mode: .recognizing)
  }

  /// The words missed at least once in `mode` — the pool a "drill missed" deck draws from.
  func wordsMissed(in mode: WordQuizMode) -> [String] {
    store.all.filter { $0.misses(in: mode) > 0 }.map(\.word)
  }

  /// Records one more miss of `word` in `mode`, creating its record on the first miss.
  func recordMiss(_ word: String, mode: WordQuizMode) {
    let record = records(for: word).first ?? store.adding(WordMissCount(word: word))
    switch mode {
      case .writing: record.writingMisses += 1
      case .recognizing: record.recognizingMisses += 1
    }
    store.commit()
  }

  /// Clears every mode's tally for `word`, back to zero.
  func reset(_ word: String) {
    store.delete { $0.word == word }
  }

  /// Clears every word's tallies — what Settings' "Reset All Missed" drives.
  func resetAll() {
    store.delete()
  }

  private func records(for word: String) -> [WordMissCount] {
    store.all.filter { $0.word == word }
  }
}

extension WordMissCount {
  /// This record's tally for `mode`.
  fileprivate func misses(in mode: WordQuizMode) -> Int {
    switch mode {
      case .writing: writingMisses
      case .recognizing: recognizingMisses
    }
  }
}
