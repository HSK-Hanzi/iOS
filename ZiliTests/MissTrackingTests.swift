//
//  MissTrackingTests.swift
//  ZiliTests
//

import SwiftData
import Testing

@testable import Zili

/// Exercises the persistent miss tallies: per-mode counting and reset in the stores, and the
/// CloudKit de-duplication that sums the records two devices can produce for the same key.
@MainActor
struct MissTrackingTests {
  @Test("A word's misses are counted per mode, surfaced for drilling, and cleared by reset")
  func wordMissesCountPerModeAndReset() {
    let store = WordMissStore.inMemory()

    store.recordMiss("好", mode: .writing)
    store.recordMiss("好", mode: .writing)
    store.recordMiss("好", mode: .recognizing)
    store.recordMiss("你", mode: .recognizing)

    #expect(store.misses(for: "好", mode: .writing) == 2)
    #expect(store.misses(for: "好", mode: .recognizing) == 1)
    #expect(store.totalMisses(for: "好") == 3)
    #expect(store.wordsMissed(in: .writing) == ["好"])
    #expect(Set(store.wordsMissed(in: .recognizing)) == ["好", "你"])

    store.reset("好")

    #expect(store.totalMisses(for: "好") == 0)
    #expect(store.wordsMissed(in: .writing).isEmpty)
    #expect(store.wordsMissed(in: .recognizing) == ["你"])
  }

  @Test("A sentence's misses are counted, surfaced for drilling, and cleared by reset")
  func sentenceMissesCountAndReset() {
    let store = SentenceMissStore.inMemory()

    store.recordMiss("s1")
    store.recordMiss("s1")
    store.recordMiss("s2")

    #expect(store.misses(for: "s1") == 2)
    #expect(Set(store.missedSentenceIDs) == ["s1", "s2"])

    store.reset("s1")

    #expect(store.misses(for: "s1") == 0)
    #expect(store.missedSentenceIDs == ["s2"])
  }

  @Test("De-duplication keeps one record per key and sums the losers' counts into it")
  func deduplicationSumsDuplicateCounts() throws {
    let container = try ModelContainer(
      for: WordMissCount.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    // Two records CloudKit produced for the same word, each with its own tally.
    context.insert(WordMissCount(word: "好", writingMisses: 2, recognizingMisses: 1))
    context.insert(WordMissCount(word: "好", writingMisses: 3, recognizingMisses: 4))

    let merged = deduplicate(
      try context.fetch(FetchDescriptor<WordMissCount>()),
      by: \.word,
      in: context
    ) { survivor, loser in
      survivor.writingMisses += loser.writingMisses
      survivor.recognizingMisses += loser.recognizingMisses
    }

    #expect(merged)
    let survivors = try context.fetch(FetchDescriptor<WordMissCount>())
    let survivor = try #require(survivors.first)
    #expect(survivors.count == 1)
    #expect(survivor.writingMisses == 5)
    #expect(survivor.recognizingMisses == 5)
  }
}
