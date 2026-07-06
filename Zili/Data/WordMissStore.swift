//
//  WordMissStore.swift
//  Zili
//

import CoreData
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
/// It mirrors ``FavoritesStore`` for miss counts: a SwiftData ``ModelContext`` with an in-memory
/// mirror of each word's tallies so a word's entry can show its counts cheaply and reactively,
/// injected into the environment so a quiz can record a miss and a dictionary entry can show and
/// reset one. On every reload it de-duplicates the records CloudKit can produce for the same word,
/// keeping one and **summing** the rest into it so an offline device's tally isn't lost — see
/// ``deduplicate(_:by:in:consolidate:)``.
@MainActor
@Observable
final class WordMissStore {
  private let context: ModelContext
  private var tallies: [String: Tally] = [:]

  /// The words missed at least once in any mode — the pool the Practice browser's Missed set draws
  /// from, mirroring ``SentenceMissStore/missedSentenceIDs``.
  var missedWords: [String] {
    tallies.compactMap { word, tally in tally.total > 0 ? word : nil }
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
  static func inMemory() -> WordMissStore {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    guard
      let container = try? ModelContainer(for: WordMissCount.self, configurations: configuration)
    else {
      fatalError("In-memory model container for previews should never fail to build.")
    }
    return WordMissStore(context: ModelContext(container))
  }

  /// How many times `word` has been missed in `mode`.
  func misses(for word: String, mode: WordQuizMode) -> Int {
    tallies[word]?.count(for: mode) ?? 0
  }

  /// How many times `word` has been missed across every mode — what gates its entry's stat.
  func totalMisses(for word: String) -> Int {
    tallies[word]?.total ?? 0
  }

  /// The words missed at least once in `mode` — the pool a "drill missed" deck draws from.
  func wordsMissed(in mode: WordQuizMode) -> [String] {
    tallies.compactMap { word, tally in tally.count(for: mode) > 0 ? word : nil }
  }

  /// Records one more miss of `word` in `mode`, creating its record on the first miss.
  func recordMiss(_ word: String, mode: WordQuizMode) {
    let record = record(for: word) ?? insert(word)
    switch mode {
      case .writing: record.writingMisses += 1
      case .recognizing: record.recognizingMisses += 1
    }
    save()
    reload()
  }

  /// Clears every mode's tally for `word`, back to zero.
  func reset(_ word: String) {
    for record in fetchAll() where record.word == word {
      context.delete(record)
    }
    save()
    reload()
  }

  /// Clears every word's tallies — for the future settings page's "Reset All".
  func resetAll() {
    for record in fetchAll() {
      context.delete(record)
    }
    save()
    reload()
  }

  private func insert(_ word: String) -> WordMissCount {
    let record = WordMissCount(word: word)
    context.insert(record)
    return record
  }

  private func record(for word: String) -> WordMissCount? {
    var descriptor = FetchDescriptor<WordMissCount>(predicate: #Predicate { $0.word == word })
    descriptor.fetchLimit = 1
    return (try? context.fetch(descriptor))?.first
  }

  /// Reconciles the in-memory mirror with the store after de-duplicating it, summing the tallies of
  /// records CloudKit produced for the same word so no device's misses are lost.
  private func reload() {
    let merged = deduplicate(fetchAll(), by: \.word, in: context) { survivor, loser in
      survivor.writingMisses += loser.writingMisses
      survivor.recognizingMisses += loser.recognizingMisses
    }
    if merged {
      save()
    }
    tallies = Dictionary(
      fetchAll().map {
        ($0.word, Tally(writing: $0.writingMisses, recognizing: $0.recognizingMisses))
      },
      uniquingKeysWith: { $0.merged(with: $1) }
    )
  }

  private func fetchAll() -> [WordMissCount] {
    (try? context.fetch(FetchDescriptor<WordMissCount>())) ?? []
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

  /// A word's misses across the two modes, the shape the in-memory mirror holds.
  private struct Tally {
    var writing = 0
    var recognizing = 0

    var total: Int { writing + recognizing }

    func count(for mode: WordQuizMode) -> Int {
      switch mode {
        case .writing: writing
        case .recognizing: recognizing
      }
    }

    func merged(with other: Self) -> Self {
      Self(writing: writing + other.writing, recognizing: recognizing + other.recognizing)
    }
  }
}
