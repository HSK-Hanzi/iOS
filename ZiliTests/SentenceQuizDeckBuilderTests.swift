//
//  SentenceQuizDeckBuilderTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct `Sentence quiz deck building` {
  private static func sentence(_ id: String, level: Int) -> LeveledSentence {
    LeveledSentence(id: id, levels: [.newest: level])
  }

  private static func levels(_ bands: Int...) -> Set<HSKLevel> {
    Set(bands.map { HSKLevel(standard: .newest, band: $0) })
  }

  private static func library() throws -> SentenceLibrary {
    let corpus = try SentenceCorpus.fixture([
      sentence("a", level: 2),
      sentence("b", level: 1),
      sentence("c", level: 3),
      sentence("d", level: 1)
    ])
    return SentenceLibrary(corpora: [corpus])
  }

  @Test
  func `a levels source draws the chosen bands in ascending level order, whatever order asked`()
    throws
  {
    let library = try Self.library()
    let corpusID = try #require(library.defaultCorpus).id
    let source = SentenceQuizSource.levels(corpusID: corpusID, levels: Self.levels(3, 1))
    let ids =
      SentenceQuizDeckBuilder
      .sentences(for: source, in: library, favoriteIDs: []).map(\.id)
    #expect(ids == ["b", "d", "c"])
    #expect(SentenceQuizDeckBuilder.count(for: source, in: library, favoriteIDs: []) == 3)
  }

  @Test
  func `an unknown corpus id falls back to the default corpus`() throws {
    let library = try Self.library()
    let source = SentenceQuizSource.levels(corpusID: "not-a-corpus", levels: Self.levels(1))
    let ids =
      SentenceQuizDeckBuilder
      .sentences(for: source, in: library, favoriteIDs: []).map(\.id)
    #expect(ids == ["b", "d"])
  }

  @Test
  func `Favorites resolves the favorite ids to sentences, skipping ids not in the library`() throws
  {
    let library = try Self.library()
    let deck = SentenceQuizDeckBuilder.sentences(
      for: .favorites,
      in: library,
      favoriteIDs: ["c", "missing", "a"]
    )
    #expect(deck.map(\.id) == ["c", "a"])
  }

  @Test
  func `Missed resolves its snapshot of ids, skipping ids not in the library`() throws {
    let library = try Self.library()
    let deck = SentenceQuizDeckBuilder.sentences(
      for: .missed(["d", "gone", "a"]),
      in: library,
      favoriteIDs: []
    )
    #expect(deck.map(\.id) == ["d", "a"])
  }

  @Test
  func `Most Recent draws the newest favorites, Oldest the ones that have waited longest`() throws {
    let library = try Self.library()
    let favoriteIDs = ["d", "c", "b", "a"]

    func deck(_ sort: QuizDeckSort) -> Set<String> {
      let sentences = SentenceQuizDeckBuilder.build(
        for: .favorites,
        in: library,
        favoriteIDs: favoriteIDs,
        sort: sort,
        limit: 2
      )
      return Set(sentences.map(\.id))
    }

    #expect(deck(.mostRecent) == ["d", "c"])
    #expect(deck(.oldest) == ["b", "a"])
  }

  @Test(arguments: [nil, 0, 2, 10] as [Int?])
  func `build caps the pool at limit and draws only from it, returning all when limit is nil`(
    limit: Int?
  ) throws {
    let library = try Self.library()
    let corpusID = try #require(library.defaultCorpus).id
    let source = SentenceQuizSource.levels(corpusID: corpusID, levels: Self.levels(1, 2, 3))
    let pool = Set(
      SentenceQuizDeckBuilder.sentences(for: source, in: library, favoriteIDs: []).map(\.id)
    )
    let deck = SentenceQuizDeckBuilder.build(
      for: source,
      in: library,
      favoriteIDs: [],
      limit: limit
    )
    #expect(deck.count == (limit.map { min($0, pool.count) } ?? pool.count))
    #expect(Set(deck.map(\.id)).isSubset(of: pool))
  }
}
