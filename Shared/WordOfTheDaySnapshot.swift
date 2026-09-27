//
//  WordOfTheDaySnapshot.swift
//  Zili
//

import Foundation

/// The words the app has picked for the days ahead, each rendered the way the learner reads it.
///
/// The widget can't pick a word itself: the pool is the dictionary's HSK syllabus, which the
/// extension doesn't carry, and the characters and reading depend on the learner's script and
/// romanization. So the app picks a stretch of days at a time and the widget walks through them.
struct WordOfTheDaySnapshot: Codable, Hashable, Sendable {
  /// The days picked, in order.
  var days: [Day]

  /// The picked days from the one containing `date` onward — the widget's timeline.
  func days(from date: Date, in calendar: Calendar = .current) -> [Day] {
    let today = calendar.startOfDay(for: date)
    return days.filter { $0.date >= today }
  }

  /// One day's word.
  struct Day: Codable, Hashable, Sendable {
    /// The start of the day the word belongs to.
    var date: Date
    /// The simplified headword — what a tap on the widget opens.
    var headword: String
    /// The characters in the script the learner reads.
    var display: String
    /// The reading in the learner's romanization.
    var reading: String
    /// A short English gloss, or `nil` when no dictionary defines the word.
    var gloss: String?
  }
}
