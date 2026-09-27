//
//  ReviewSnapshot.swift
//  Zili
//

import Foundation

/// What the widget knows about the learner's favorites: one row per starred word, carrying when
/// it next falls due.
///
/// The schedule itself lives in SwiftData behind the app's CloudKit container, which an extension
/// can't open. This is the small, flat thing the app hands across the App Group instead — a few
/// dozen bytes a word, no dictionary and no store in the extension process.
///
/// Rows carry a due date rather than a count of what is due *now*, and that is the whole point: a
/// word falls due by the clock reaching it, not by anything the app does. Given the dates, the
/// widget works out how many have come due at any point in the future with the app never having
/// run since — and can tell the system when to ask again.
struct ReviewSnapshot: Codable, Hashable, Sendable {
  var words: [Word]

  /// The words due at `date`, the longest overdue first — the order a review deals them in.
  func due(at date: Date = .now) -> [Word] {
    words.filter { $0.dueDate <= date }.sorted { $0.dueDate < $1.dueDate }
  }

  /// When the next word falls due after `date`, or `nil` when nothing is still waiting.
  ///
  /// This is what the widget's timeline is built around: there is exactly one moment between now
  /// and then at which the count it shows can change, so it asks to be refreshed at that moment
  /// and not on a guessed interval.
  func nextDueDate(after date: Date = .now) -> Date? {
    words.map(\.dueDate).filter { $0 > date }.min()
  }

  /// A starred word, as the learner reads it and as the schedule holds it.
  struct Word: Codable, Hashable, Sendable {
    /// The simplified headword, which identifies the word everywhere in the app — what a tap on
    /// the widget carries back.
    var headword: String
    /// The characters in the script the learner reads, which is what the widget shows.
    var display: String
    /// The reading in the learner's romanization.
    var reading: String
    /// When the word next falls due. A word the learner has never been quizzed on is due now, so
    /// it carries the moment it was starred rather than being left out.
    var dueDate: Date
  }
}
