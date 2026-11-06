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
struct `Miss tracking` {
  @Test
  func `a word's misses are counted per mode, surfaced for drilling, and cleared by reset`() {
    let store = WordMissStore.inMemory()

    store.recordMiss("好", mode: .writing)
    store.recordMiss("好", mode: .writing)
    store.recordMiss("好", mode: .recognizing)
    store.recordMiss("你", mode: .recognizing)
    store.recordMiss("好", mode: .recognizingHanzi)
    store.recordMiss("好", mode: .speaking)
    store.recordMiss("他", mode: .speaking)
    store.recordMiss("好", mode: .listening)

    #expect(store.misses(for: "好", mode: .writing) == 2)
    #expect(store.misses(for: "好", mode: .recognizing) == 1)
    #expect(store.misses(for: "好", mode: .recognizingHanzi) == 1)
    #expect(store.misses(for: "好", mode: .speaking) == 1)
    #expect(store.misses(for: "好", mode: .listening) == 1)
    #expect(store.totalMisses(for: "好") == 6)
    #expect(store.wordsMissed(in: .writing) == ["好"])
    #expect(Set(store.wordsMissed(in: .recognizing)) == ["好", "你"])
    #expect(store.wordsMissed(in: .recognizingHanzi) == ["好"])
    #expect(Set(store.wordsMissed(in: .speaking)) == ["好", "他"])
    #expect(store.wordsMissed(in: .listening) == ["好"])
    #expect(Set(store.missedWords) == ["好", "你", "他"])

    store.reset("好")

    #expect(store.totalMisses(for: "好") == 0)
    #expect(store.wordsMissed(in: .writing).isEmpty)
    #expect(store.wordsMissed(in: .recognizing) == ["你"])
    #expect(store.wordsMissed(in: .recognizingHanzi).isEmpty)
    #expect(store.wordsMissed(in: .speaking) == ["他"])
    #expect(store.wordsMissed(in: .listening).isEmpty)
  }

  @Test(arguments: [
    (PromptDirection.chineseToEnglish, false, WordQuizMode.recognizingHanzi),
    (.chineseToEnglish, true, .recognizing),
    (.englishToChinese, false, .recognizing)
  ])
  func `a flashcard miss counts toward Hanzi recognition only when the Hanzi showed alone`(
    direction: PromptDirection,
    showsReading: Bool,
    expected: WordQuizMode
  ) {
    let configuration = FlashcardQuizConfiguration(
      source: .favorites([]),
      direction: direction,
      showsReadingWithHanzi: showsReading
    )

    #expect(configuration.missMode == expected)
  }

  @Test
  func `a sentence's misses are counted per quiz, surfaced for drilling, and cleared by reset`() {
    let store = SentenceMissStore.inMemory()

    store.recordMiss("s1", mode: .listening)
    store.recordMiss("s1", mode: .listening)
    store.recordMiss("s1", mode: .speaking)
    store.recordMiss("s2", mode: .listening)
    store.recordMiss("s3", mode: .speaking)

    #expect(store.misses(for: "s1", mode: .listening) == 2)
    #expect(store.misses(for: "s1", mode: .speaking) == 1)
    #expect(store.misses(for: "s1") == 3)
    #expect(Set(store.sentencesMissed(in: .listening)) == ["s1", "s2"])
    #expect(Set(store.sentencesMissed(in: .speaking)) == ["s1", "s3"])
    #expect(Set(store.missedSentenceIDs) == ["s1", "s2", "s3"])

    store.reset("s1")

    #expect(store.misses(for: "s1") == 0)
    #expect(store.sentencesMissed(in: .listening) == ["s2"])
    #expect(store.sentencesMissed(in: .speaking) == ["s3"])
  }

  @Test
  func `de-duplication keeps one record per key and sums the losers' counts into it`() throws {
    let container = try ModelContainer(
      for: WordMissCount.self,
      configurations: .throwaway()
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
