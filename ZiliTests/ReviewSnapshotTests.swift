//
//  ReviewSnapshotTests.swift
//  ZiliTests
//

import Foundation
import Testing

@testable import Zili

/// Exercises what the widget reads: which words have come due at a given moment, and the one
/// moment after it at which that answer changes.
struct `Review snapshots` {
  private static let day: TimeInterval = 24 * 60 * 60

  private static let now = Date(timeIntervalSinceReferenceDate: 0)

  private static func snapshot(dueIn days: [Double]) -> ReviewSnapshot {
    ReviewSnapshot(
      words: days.enumerated().map { index, offset in
        ReviewSnapshot.Word(
          headword: "w\(index)",
          display: "w\(index)",
          reading: "r\(index)",
          dueDate: Date(timeIntervalSinceReferenceDate: 0).addingTimeInterval(offset * day)
        )
      }
    )
  }

  @Test
  func `the due words are the ones the clock has reached, longest overdue first`() {
    let snapshot = Self.snapshot(dueIn: [1, -3, -1, 5])

    let due = snapshot.due(at: Self.now)

    #expect(due.map(\.headword) == ["w1", "w2"])
  }

  @Test
  func `a word falling due exactly now counts as due`() {
    let snapshot = Self.snapshot(dueIn: [0])

    #expect(snapshot.due(at: Self.now).count == 1)
  }

  @Test
  func `the next due date is the soonest one still ahead, and nil once none are`() {
    let waiting = Self.snapshot(dueIn: [-1, 3, 7])

    #expect(waiting.nextDueDate(after: Self.now) == Self.now.addingTimeInterval(3 * Self.day))
    #expect(Self.snapshot(dueIn: [-2, -1]).nextDueDate(after: Self.now) == nil)
  }
}
