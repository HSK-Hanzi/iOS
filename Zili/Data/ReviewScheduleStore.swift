//
//  ReviewScheduleStore.swift
//  Zili
//

import Foundation
import SwiftData

/// The learner's per-word review schedules, one for each ``RecognitionCue``, the single source of
/// truth for when a favorite is due to come back.
///
/// A ``RecordStore`` keeps the ``WordReviewSchedule`` records observed and de-duplicated. There is
/// nothing to add up as there is for a miss tally: two schedules for one word and cue are two
/// accounts of the same thing, and the later review is the truer one, so the survivor takes it. This adds the
/// vocabulary the app speaks in, and is injected into the environment so the recognition quiz can
/// record a judgement and its setup screen can count what is due.
@MainActor
@Observable
final class ReviewScheduleStore {
  private let store: RecordStore<WordReviewSchedule, Key>

  /// Builds a store over `container`'s main context. ``inMemory()`` provides a throwaway one for
  /// previews.
  init(container: ModelContainer) {
    store = RecordStore(
      container: container,
      sortBy: [SortDescriptor(\WordReviewSchedule.word)],
      by: Key.init
    ) { survivor, loser in
      guard loser.lastReviewed > survivor.lastReviewed else { return }
      survivor.lastReviewed = loser.lastReviewed
      survivor.interval = loser.interval
    }
  }

  /// A store backed by an in-memory container, for SwiftUI previews.
  static func inMemory() -> ReviewScheduleStore {
    let container = RecordStore<WordReviewSchedule, Key>.inMemoryContainer()
    let store = ReviewScheduleStore(container: container)
    store.start()
    return store
  }

  /// The later-reviewed of two accounts of one word.
  private static func laterReview(
    _ first: WordReviewSchedule,
    _ second: WordReviewSchedule
  ) -> WordReviewSchedule {
    first.lastReviewed >= second.lastReviewed ? first : second
  }

  /// Opens the store's query, once the app is running. ``AppData`` calls this as it loads; until
  /// it does, the store reads as empty.
  func start() {
    store.start()
  }

  /// When each word scheduled from `cue` next falls due — what a deck drawn in review order is
  /// ranked by. A word missing from this has never been reviewed from `cue`, and so is due now.
  func dueDates(for cue: RecognitionCue) -> [String: Date] {
    Dictionary(
      store.all.filter { $0.cue == cue }.map { ($0.word, $0) },
      uniquingKeysWith: Self.laterReview
    )
    .mapValues(\.dueDate)
  }

  /// When `word` next falls due from `cue`, or `nil` if the learner has never been quizzed on it
  /// that way.
  func dueDate(for word: String, cue: RecognitionCue) -> Date? {
    record(for: Key(word: word, cue: cue))?.dueDate
  }

  /// How many of `words` are ready to be reviewed from `cue`. A word with no schedule counts: never
  /// having been quizzed on it is the earliest it can be due.
  func dueCount(among words: [String], cue: RecognitionCue, asOf now: Date = .now) -> Int {
    words.count { dueDate(for: $0, cue: cue).map { $0 <= now } ?? true }
  }

  /// Advances `word`'s schedule from `cue` by how the learner judged it, starting one on the first
  /// judgement.
  func record(_ outcome: QuizSession.Outcome, for word: String, cue: RecognitionCue) {
    let current = record(for: Key(word: word, cue: cue))
    guard let advanced = (current?.interval ?? .unseen).advanced(by: outcome) else { return }
    let record = current ?? store.adding(WordReviewSchedule(word: word, cue: cue))
    record.lastReviewed = .now
    record.interval = advanced
    store.commit()
  }

  /// The schedule under `key`, taking the later review of the records a CloudKit import can
  /// briefly leave under it — the same reading the de-duplication settles on once it lands.
  private func record(for key: Key) -> WordReviewSchedule? {
    store.all.filter { Key($0) == key }.reduce(nil) { survivor, next in
      survivor.map { Self.laterReview($0, next) } ?? next
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
