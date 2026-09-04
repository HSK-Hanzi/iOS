//
//  SentenceQuizDeckBuilderTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct SentenceQuizDeckBuilderTests {
  private static func sentence(_ id: String, level: Int) -> PracticeSentence {
    PracticeSentence(
      id: id,
      level: level,
      hanzi: "句\(id)",
      numberedPinyin: "ju4",
      translation: "sentence \(id)"
    )
  }

  private static func library() -> SentenceLibrary {
    let corpus = SentenceCorpus(
      source: .practice,
      sentences: [
        sentence("a", level: 2),
        sentence("b", level: 1),
        sentence("c", level: 3),
        sentence("d", level: 1)
      ]
    )
    return SentenceLibrary(corpora: [corpus])
  }

  @Test
  func `a levels source draws the chosen bands in ascending level order, whatever order asked`()
    throws
  {
    let library = Self.library()
    let corpusID = try #require(library.defaultCorpus).id
    let source = SentenceQuizSource.levels(corpusID: corpusID, levels: [3, 1])
    let ids =
      SentenceQuizDeckBuilder
      .sentences(for: source, in: library, favoriteIDs: []).map(\.id)
    #expect(ids == ["b", "d", "c"])
  }

  @Test
  func `an unknown corpus id falls back to the default corpus`() {
    let library = Self.library()
    let source = SentenceQuizSource.levels(corpusID: "not-a-corpus", levels: [1])
    let ids =
      SentenceQuizDeckBuilder
      .sentences(for: source, in: library, favoriteIDs: []).map(\.id)
    #expect(ids == ["b", "d"])
  }

  @Test
  func `Favorites resolves the favorite ids to sentences, skipping ids not in the library`() {
    let library = Self.library()
    let deck = SentenceQuizDeckBuilder.sentences(
      for: .favorites,
      in: library,
      favoriteIDs: ["c", "missing", "a"]
    )
    #expect(deck.map(\.id) == ["c", "a"])
  }

  @Test
  func `Missed resolves its snapshot of ids, skipping ids not in the library`() {
    let library = Self.library()
    let deck = SentenceQuizDeckBuilder.sentences(
      for: .missed(["d", "gone", "a"]),
      in: library,
      favoriteIDs: []
    )
    #expect(deck.map(\.id) == ["d", "a"])
  }

  @Test
  func `Most Recent draws the newest favorites, Oldest the ones that have waited longest`() {
    let library = Self.library()
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
    let library = Self.library()
    let corpusID = try #require(library.defaultCorpus).id
    let source = SentenceQuizSource.levels(corpusID: corpusID, levels: [1, 2, 3])
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
