//
//  DeduplicationTests.swift
//  ZiliTests
//

import Foundation
import SwiftData
import Testing

@testable import Zili

/// Exercises the CloudKit convergence logic in ``deduplicate(_:by:in:consolidate:)``: which
/// colliding record survives, how losers fold into it, and that a unique store is left untouched.
@MainActor
struct DeduplicationTests {
  private func inMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: WordMissCount.self,
      FavoriteWord.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test("Colliding miss records collapse to the smallest identifier, summing the losers' counts")
  func keepsSmallestIdentifierAndSumsCounts() throws {
    let context = try inMemoryContext()
    let records = [
      WordMissCount(word: "好", writingMisses: 2, recognizingMisses: 1),
      WordMissCount(word: "好", writingMisses: 3, recognizingMisses: 4),
      WordMissCount(word: "好", writingMisses: 5, recognizingMisses: 6)
    ]
    records.forEach(context.insert)
    let expectedSurvivor = try #require(
      records.min { $0.identifier.uuidString < $1.identifier.uuidString }
    )

    let merged = deduplicate(
      try context.fetch(FetchDescriptor<WordMissCount>()),
      by: \.word,
      in: context
    ) { survivor, loser in
      survivor.writingMisses += loser.writingMisses
      survivor.recognizingMisses += loser.recognizingMisses
    }
    try context.save()

    #expect(merged)
    let survivors = try context.fetch(FetchDescriptor<WordMissCount>())
    #expect(survivors.count == 1)
    let survivor = try #require(survivors.first)
    #expect(survivor.identifier == expectedSurvivor.identifier)
    #expect(survivor.writingMisses == 10)
    #expect(survivor.recognizingMisses == 11)
  }

  @Test("Each key converges independently on its smallest-identifier record")
  func collapsesEachKeyToItsSurvivor() throws {
    let context = try inMemoryContext()
    let hao = [FavoriteWord(word: "好"), FavoriteWord(word: "好")]
    let ni = [FavoriteWord(word: "你"), FavoriteWord(word: "你"), FavoriteWord(word: "你")]
    (hao + ni).forEach(context.insert)
    let expected = [hao, ni].compactMap { group in
      group.min { $0.identifier.uuidString < $1.identifier.uuidString }?.identifier
    }

    let merged = deduplicate(
      try context.fetch(FetchDescriptor<FavoriteWord>()),
      by: \.word,
      in: context
    )
    try context.save()

    #expect(merged)
    let survivors = try context.fetch(FetchDescriptor<FavoriteWord>())
    #expect(survivors.count == 2)
    #expect(Set(survivors.map(\.word)) == ["好", "你"])
    #expect(Set(survivors.map(\.identifier)) == Set(expected))
  }

  @Test("A collision-free store reports no change and deletes nothing")
  func leavesUniqueRecordsUntouched() throws {
    let context = try inMemoryContext()
    [FavoriteWord(word: "好"), FavoriteWord(word: "你"), FavoriteWord(word: "我")]
      .forEach(context.insert)

    let merged = deduplicate(
      try context.fetch(FetchDescriptor<FavoriteWord>()),
      by: \.word,
      in: context
    )
    try context.save()

    #expect(!merged)
    let survivors = try context.fetch(FetchDescriptor<FavoriteWord>())
    #expect(survivors.count == 3)
    #expect(Set(survivors.map(\.word)) == ["好", "你", "我"])
  }
}
