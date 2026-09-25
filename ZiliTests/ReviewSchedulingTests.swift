//
//  ReviewSchedulingTests.swift
//  ZiliTests
//

import Foundation
import SwiftData
import Testing

@testable import Zili

/// Exercises the spaced-repetition schedule: the interval ladder a judgement advances, the store
/// that persists it and counts what is due, and the CloudKit reconciliation that two devices
/// reviewing the same word can need.
@MainActor
struct `Review scheduling` {
  private static let day: TimeInterval = 24 * 60 * 60

  @Test
  func `a recalled word waits a day, then longer every time it's known again`() {
    let first = ReviewInterval.unseen.recalled()
    let second = first.recalled()
    let third = second.recalled()

    #expect(first.days == 1)
    #expect(second.days == 3)
    #expect(third.days == 8)
    #expect(third.ease > ReviewInterval.unseen.ease)
  }

  @Test
  func `a missed word comes back tomorrow, and its stretch shortens`() {
    let learned = ReviewInterval.unseen.recalled().recalled().recalled()
    let missed = learned.missed()

    #expect(learned.days == 8)
    #expect(missed.days == 1)
    #expect(missed.ease < learned.ease)
  }

  @Test
  func `the ease floor holds, and is not a trap a word can't climb out of`() {
    var interval = ReviewInterval.unseen
    for _ in 0..<20 {
      interval = interval.missed()
    }

    #expect(interval.days == 1)
    #expect(interval.ease == 1.3)

    for _ in 0..<3 {
      interval = interval.recalled()
    }
    #expect(interval.days > 1)
  }

  @Test
  func `a long run of recalls stops stretching at the cap`() {
    var interval = ReviewInterval.unseen
    for _ in 0..<40 {
      interval = interval.recalled()
    }

    #expect(interval.days == 3650)
  }

  @Test
  func `a judgement schedules a word from its cue alone, and a skip leaves it where it was`()
    throws
  {
    let store = ReviewScheduleStore.inMemory()

    store.record(.correct, for: "好", cue: .word)
    store.record(.skipped, for: "你", cue: .word)

    #expect(try #require(store.dueDate(for: "好", cue: .word)) > .now)
    #expect(store.dueDate(for: "好", cue: .hanzi) == nil)
    #expect(store.dueDate(for: "你", cue: .word) == nil)
  }

  @Test
  func `a miss brings a word that had receded back to tomorrow`() throws {
    let store = ReviewScheduleStore.inMemory()

    store.record(.correct, for: "好", cue: .word)
    store.record(.correct, for: "好", cue: .word)
    store.record(.correct, for: "好", cue: .word)
    let receded = try #require(store.dueDate(for: "好", cue: .word))

    store.record(.needsReview, for: "好", cue: .word)
    let returned = try #require(store.dueDate(for: "好", cue: .word))

    #expect(receded > .now.addingTimeInterval(2 * Self.day))
    #expect(returned < .now.addingTimeInterval(2 * Self.day))
  }

  @Test
  func `the due count includes the words never reviewed, and excludes the ones still waiting`() {
    let store = ReviewScheduleStore.inMemory()

    store.record(.correct, for: "好", cue: .word)

    #expect(store.dueCount(among: ["好", "你", "我"], cue: .word) == 2)
    let later = Date.now.addingTimeInterval(2 * Self.day)
    #expect(store.dueCount(among: ["好"], cue: .word, asOf: later) == 1)
  }

  @Test
  func `two devices' schedules for one word and cue collapse onto the later review`() throws {
    let container = RecordStore<WordReviewSchedule, String>.inMemoryContainer()
    let context = container.mainContext
    // Two records CloudKit produced for the same word and cue, each with its own account of it.
    context.insert(
      WordReviewSchedule(
        word: "好",
        cue: .word,
        lastReviewed: .now.addingTimeInterval(-Self.day),
        interval: ReviewInterval(days: 2, ease: 2.4)
      )
    )
    context.insert(
      WordReviewSchedule(word: "好", cue: .word, interval: ReviewInterval(days: 9, ease: 2.8))
    )
    context.insert(WordReviewSchedule(word: "好", cue: .hanzi))
    try context.save()

    // Opening a store over them is what reconciles what CloudKit left behind.
    let store = ReviewScheduleStore(container: container)
    store.start()

    let survivors = try context.fetch(FetchDescriptor<WordReviewSchedule>())
    #expect(survivors.count == 2)
    let wordDue = try #require(store.dueDate(for: "好", cue: .word))
    #expect(wordDue > .now.addingTimeInterval(8 * Self.day))
    #expect(store.dueDate(for: "好", cue: .hanzi) != nil)
  }
}
