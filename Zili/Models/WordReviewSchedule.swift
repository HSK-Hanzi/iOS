//
//  WordReviewSchedule.swift
//  Zili
//

import Foundation
import SwiftData

/// What a flashcard showed the learner to recognize a word from. Knowing a word with its reading
/// beside it says little about recognizing its Hanzi alone, so each cue keeps its own schedule.
enum RecognitionCue: Hashable, Sendable {
  /// The whole word: the Hanzi with the reading, or the meaning to recall the word from.
  case word
  /// The Hanzi alone.
  case hanzi
}

/// When the learner last reviewed a word from one ``RecognitionCue`` and how long it waits before
/// coming back, persisted with SwiftData and synced through CloudKit.
///
/// A word is identified across the app by its simplified headword, so that string and the cue are
/// the record's natural key. CloudKit can't enforce uniqueness, so every record also carries a
/// stable ``identifier`` that lets every device pick the same winner when de-duplicating records
/// that arrived for the same key; unlike the miss tallies there is nothing to add up, so the
/// survivor takes the later review — see ``ReviewScheduleStore``. Per CloudKit's rules, every
/// property has a default value and none is marked `@Attribute(.unique)`.
@Model
final class WordReviewSchedule {
  var word: String = ""
  /// Whether this schedules recognizing the Hanzi alone, rather than the whole word.
  var hanziAlone = false
  var lastReviewed = Date.now
  var intervalDays = ReviewInterval.unseen.days
  var ease = ReviewInterval.unseen.ease
  var identifier = UUID()

  /// The wait this record describes, in the shape the ladder advances.
  var interval: ReviewInterval {
    get { ReviewInterval(days: intervalDays, ease: ease) }
    set {
      intervalDays = newValue.days
      ease = newValue.ease
    }
  }

  /// What the learner recognized the word from.
  var cue: RecognitionCue {
    hanziAlone ? .hanzi : .word
  }

  /// When the word falls due again.
  var dueDate: Date {
    Calendar.current.date(byAdding: .day, value: intervalDays, to: lastReviewed) ?? lastReviewed
  }

  init(
    word: String,
    cue: RecognitionCue,
    lastReviewed: Date = .now,
    interval: ReviewInterval = .unseen,
    identifier: UUID = UUID()
  ) {
    self.word = word
    hanziAlone = cue == .hanzi
    self.lastReviewed = lastReviewed
    intervalDays = interval.days
    ease = interval.ease
    self.identifier = identifier
  }
}
