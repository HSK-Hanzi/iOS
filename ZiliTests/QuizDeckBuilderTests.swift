//
//  QuizDeckBuilderTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct QuizDeckBuilderTests {
  @Test("A built deck respects its size limit and resolves each card's content")
  func honorsLimitAndResolvesContent() async throws {
    let lexicon = try await Lexicon.load()
    let level = try #require(lexicon.availableLevels.first)

    let deck = QuizDeckBuilder.build(
      from: lexicon,
      source: .hskLevels([level]),
      order: .frequency,
      limit: 5,
      romanization: .pinyin
    )

    #expect(!deck.isEmpty)
    #expect(deck.count <= 5)
    let card = try #require(deck.first)
    #expect(!card.hanzi.isEmpty)
    #expect(!card.definition.isEmpty)
  }

  @Test("Frequency ordering puts the most common words first")
  func frequencyOrdersMostCommonFirst() async throws {
    let lexicon = try await Lexicon.load()
    let level = try #require(lexicon.availableLevels.first)

    let deck = QuizDeckBuilder.build(
      from: lexicon,
      source: .hskLevels([level]),
      order: .frequency,
      limit: 30,
      romanization: .pinyin
    )

    let ranks = deck.map { lexicon.lookup($0.word).frequencyRank ?? Int.max }
    #expect(ranks == ranks.sorted())
  }

  @Test("The card reading is rendered in the chosen romanization")
  func readingReflectsRomanization() async throws {
    let lexicon = try await Lexicon.load()
    let level = try #require(lexicon.availableLevels.first)

    func firstReading(_ system: Romanization) -> String {
      QuizDeckBuilder.build(
        from: lexicon,
        source: .hskLevels([level]),
        order: .frequency,
        limit: 1,
        romanization: system
      ).first?.reading ?? ""
    }

    let pinyin = firstReading(.pinyin)
    #expect(!pinyin.isEmpty)
    #expect(pinyin != firstReading(.bopomofo))
  }

  @Test("Selecting several levels unions their words without duplicates")
  func combinesLevelsWithoutDuplicates() async throws {
    let lexicon = try await Lexicon.load()
    let levels = Array(lexicon.availableLevels.prefix(2))
    try #require(levels.count == 2)

    let combined = QuizDeckSource.hskLevels(Set(levels)).headwords(in: lexicon)

    #expect(Set(combined).count == combined.count)
    for level in levels {
      #expect(Set(combined).isSuperset(of: lexicon.words(in: level)))
    }
  }

  @Test("A character deck holds distinct drawable characters, no more than its limit")
  func characterDeckIsDistinctAndDrawable() async throws {
    let lexicon = try await Lexicon.load()
    let level = try #require(lexicon.availableLevels.first)

    let deck = QuizDeckBuilder.characterDeck(
      from: lexicon,
      source: .hskLevels([level]),
      limit: 20,
      romanization: .pinyin
    )

    #expect(deck.count == 20)
    #expect(Set(deck.map(\.word)).count == deck.count)
    for card in deck {
      let character = try #require(card.word.first)
      #expect(card.word.count == 1)
      #expect(lexicon.strokeGraphic(for: character) != nil)
    }
  }

  @Test("A level set's name groups by standard and collapses consecutive bands into ranges")
  func displayNameCollapsesConsecutiveBands() {
    let range = QuizDeckSource.hskLevels([
      HSKLevel(standard: .new, band: 3),
      HSKLevel(standard: .new, band: 4),
      HSKLevel(standard: .new, band: 5)
    ])
    #expect(range.displayName == "HSK 3.0 (2021) · 3–5")

    let gap = QuizDeckSource.hskLevels([
      HSKLevel(standard: .new, band: 1),
      HSKLevel(standard: .new, band: 2),
      HSKLevel(standard: .new, band: 5)
    ])
    #expect(gap.displayName == "HSK 3.0 (2021) · 1–2, 5")
  }
}
