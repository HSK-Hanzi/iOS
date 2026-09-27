//
//  ReviewScheduleStore.swift
//  Zili
//

import CoreData
import Foundation
import SwiftData

/// The learner's per-word review schedules, one for each ``RecognitionCue``, the single source of
/// truth for when a favorite is due to come back.
///
/// It mirrors ``WordMissStore``: a SwiftData ``SwiftData/ModelContext`` with an in-memory mirror of
/// each word's schedule, so the quiz setup can rank a whole favorites list by what is most overdue
/// without asking the store word by word. Injected into the environment so the recognition quiz can
/// record a judgement and its setup screen can count what is due.
///
/// On every reload it de-duplicates the records CloudKit can produce for the same word and cue.
/// There is nothing to sum as there is for a miss tally: two such schedules are two accounts of the
/// same thing, and the later review is the truer one, so the survivor takes it.
@MainActor
@Observable
final class ReviewScheduleStore {
  private let context: ModelContext
  private var schedules: [Key: Entry] = [:]

  /// The remote-change observer token, held so `deinit` can hand it to the thread-safe
  /// `NotificationCenter.removeObserver`. Plumbing, not observable state.
  @ObservationIgnored nonisolated(unsafe) private var remoteChangeObserver: (any NSObjectProtocol)?

  /// Builds a store over `context` and loads the current schedules. Pass the environment's
  /// `modelContext`; ``inMemory()`` provides a throwaway one for previews.
  init(context: ModelContext) {
    self.context = context
    observeRemoteChanges()
    reload()
  }

  /// A store backed by an in-memory container, for SwiftUI previews.
  static func inMemory() -> ReviewScheduleStore {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    guard
      let container = try? ModelContainer(
        for: WordReviewSchedule.self,
        configurations: configuration
      )
    else {
      fatalError("In-memory model container for previews should never fail to build.")
    }
    return ReviewScheduleStore(context: ModelContext(container))
  }

  /// When each word scheduled from `cue` next falls due — what a deck drawn in review order is
  /// ranked by. A word missing from this has never been reviewed from `cue`, and so is due now.
  func dueDates(for cue: RecognitionCue) -> [String: Date] {
    Dictionary(
      uniqueKeysWithValues: schedules.compactMap { key, entry in
        key.cue == cue ? (key.word, entry.dueDate) : nil
      }
    )
  }

  /// When `word` next falls due from `cue`, or `nil` if the learner has never been quizzed on it
  /// that way.
  func dueDate(for word: String, cue: RecognitionCue) -> Date? {
    schedules[Key(word: word, cue: cue)]?.dueDate
  }

  /// How many of `words` are ready to be reviewed from `cue`. A word with no schedule counts: never
  /// having been quizzed on it is the earliest it can be due.
  func dueCount(among words: [String], cue: RecognitionCue, asOf now: Date = .now) -> Int {
    words.count { dueDate(for: $0, cue: cue).map { $0 <= now } ?? true }
  }

  /// Advances `word`'s schedule from `cue` by how the learner judged it, starting one on the first
  /// judgement.
  func record(_ outcome: QuizSession.Outcome, for word: String, cue: RecognitionCue) {
    let current = schedules[Key(word: word, cue: cue)]?.interval ?? .unseen
    guard let advanced = current.advanced(by: outcome) else { return }
    let record = record(for: word, cue: cue) ?? insert(word, cue: cue)
    record.lastReviewed = .now
    record.interval = advanced
    save()
    reload()
  }

  private func insert(_ word: String, cue: RecognitionCue) -> WordReviewSchedule {
    let record = WordReviewSchedule(word: word, cue: cue)
    context.insert(record)
    return record
  }

  private func record(for word: String, cue: RecognitionCue) -> WordReviewSchedule? {
    let hanziAlone = cue == .hanzi
    var descriptor = FetchDescriptor<WordReviewSchedule>(
      predicate: #Predicate { $0.word == word && $0.hanziAlone == hanziAlone }
    )
    descriptor.fetchLimit = 1
    return (try? context.fetch(descriptor))?.first
  }

  /// Reconciles the in-memory mirror with the store after de-duplicating it, keeping the later
  /// review of the records CloudKit produced for the same word and cue.
  private func reload() {
    let merged = deduplicate(fetchAll(), by: Key.init, in: context) { survivor, loser in
      guard loser.lastReviewed > survivor.lastReviewed else { return }
      survivor.lastReviewed = loser.lastReviewed
      survivor.interval = loser.interval
    }
    if merged {
      save()
    }
    schedules = Dictionary(
      fetchAll().map {
        (Key($0), Entry(lastReviewed: $0.lastReviewed, interval: $0.interval, dueDate: $0.dueDate))
      },
      uniquingKeysWith: { $0.later(than: $1) }
    )
  }

  private func fetchAll() -> [WordReviewSchedule] {
    (try? context.fetch(FetchDescriptor<WordReviewSchedule>())) ?? []
  }

  private func save() {
    try? context.save()
  }

  /// Reloads when CloudKit imports remote changes, so another device's reviews appear and any
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

  /// A schedule's natural key: the word, and what it was recognized from.
  private struct Key: Hashable {
    let word: String
    let cue: RecognitionCue

    init(word: String, cue: RecognitionCue) {
      self.word = word
      self.cue = cue
    }

    init(_ record: WordReviewSchedule) {
      self.init(word: record.word, cue: record.cue)
    }
  }

  /// A word's place in the schedule, the shape the in-memory mirror holds.
  private struct Entry {
    var lastReviewed: Date
    var interval: ReviewInterval
    var dueDate: Date

    /// The later of two accounts of one word, for the moment before a de-duplication lands.
    func later(than other: Self) -> Self {
      lastReviewed >= other.lastReviewed ? self : other
    }
  }
}

extension ReviewInterval {
  /// The interval `outcome` moves this one to, or `nil` where it moves nothing. A skip moves
  /// nothing: the learner passed on the word rather than failed it, so it keeps the wait it had.
  func advanced(by outcome: QuizSession.Outcome) -> Self? {
    switch outcome {
      case .correct: recalled()
      case .needsReview: missed()
      case .skipped: nil
    }
  }
}
