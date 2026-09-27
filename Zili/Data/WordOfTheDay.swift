//
//  WordOfTheDay.swift
//  Zili
//

import Foundation

/// Picks one word a day from a fixed pool — the same word for a given day on every launch and every
/// device, with no state kept anywhere.
///
/// Days walk the pool by a stride that shares no factor with its size. Neighbouring days land far
/// apart in the sorted pool rather than on alphabetical neighbours, and every word comes round once
/// before any comes round twice.
struct WordOfTheDay {
  /// Where the walk's stride starts looking: a prime, so it is coprime with nearly any pool as is.
  private static let baseStride = 7_919

  /// The words picked from, in a fixed order.
  let pool: [String]

  private let stride: Int

  /// A picker over `pool`, or `nil` when there is nothing to pick.
  init?(pool: [String]) {
    guard !pool.isEmpty else { return nil }
    self.pool = pool
    stride = Self.stride(coprimeWith: pool.count)
  }

  /// A picker over every word in the newest HSK standard the lexicon has, or `nil` when it has no
  /// syllabus at all.
  init?(lexicon: Lexicon) {
    // Standards sort newest first, and the levels ascend by standard.
    guard let newest = lexicon.availableLevels.first?.standard else { return nil }
    let levels = lexicon.availableLevels.filter { $0.standard == newest }
    self.init(pool: Set(levels.flatMap(lexicon.words(in:))).sorted())
  }

  private static func stride(coprimeWith count: Int) -> Int {
    guard let stride = (baseStride...).first(where: { greatestCommonDivisor($0, count) == 1 })
    else {
      preconditionFailure("Some prime above the pool size is coprime with it.")
    }
    return stride
  }

  private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
    b == 0 ? a : greatestCommonDivisor(b, a % b)
  }

  /// The word for the day containing `date`.
  func word(on date: Date, in calendar: Calendar = .current) -> String {
    let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    return pool[(day * stride) % pool.count]
  }

  /// The `count` days starting with the one containing `date`, each with its word.
  func days(
    from date: Date,
    count: Int,
    in calendar: Calendar = .current
  ) -> [(date: Date, word: String)] {
    let today = calendar.startOfDay(for: date)
    return (0..<count).compactMap { offset in
      calendar.date(byAdding: .day, value: offset, to: today).map {
        ($0, word(on: $0, in: calendar))
      }
    }
  }
}
