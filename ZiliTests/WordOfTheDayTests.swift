//
//  WordOfTheDayTests.swift
//  ZiliTests
//

import Foundation
import Testing

@testable import Zili

/// Exercises how the app picks the day's word: the same word all day on every launch, a different
/// one tomorrow, and the whole pool before any word repeats.
struct `Word of the day` {
  private static let pool = (0..<10).map { "w\($0)" }

  private static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  private static let morning = Date(timeIntervalSinceReferenceDate: 8 * 60 * 60)

  private static func picker() throws -> WordOfTheDay {
    try #require(WordOfTheDay(pool: pool))
  }

  @Test
  func `picks one word for the whole of a day, from any picker`() throws {
    let evening = Self.morning.addingTimeInterval(12 * 60 * 60)

    let word = try Self.picker().word(on: Self.morning, in: Self.calendar)

    #expect(try Self.picker().word(on: evening, in: Self.calendar) == word)
  }

  @Test
  func `deals every word in the pool once before any repeats`() throws {
    let days = try Self.picker().days(from: Self.morning, count: Self.pool.count, in: Self.calendar)

    #expect(Set(days.map(\.word)) == Set(Self.pool))
  }

  @Test
  func `lays the days out from the start of today`() throws {
    let days = try Self.picker().days(from: Self.morning, count: 3, in: Self.calendar)

    #expect(days.map(\.date) == [0, 1, 2].map { Date(timeIntervalSinceReferenceDate: $0 * 86_400) })
  }

  @Test
  func `has nothing to pick from an empty pool`() {
    #expect(WordOfTheDay(pool: []) == nil)
  }

  @Test
  func `the widget walks from today's word, dropping the days behind it`() {
    let snapshot = WordOfTheDaySnapshot(
      days: [-1, 0, 1].map { offset in
        WordOfTheDaySnapshot.Day(
          date: Date(timeIntervalSinceReferenceDate: offset * 86_400),
          headword: "w\(Int(offset))",
          display: "",
          reading: "",
          gloss: nil
        )
      }
    )

    let days = snapshot.days(from: Self.morning, in: Self.calendar)

    #expect(days.map(\.headword) == ["w0", "w1"])
  }
}
