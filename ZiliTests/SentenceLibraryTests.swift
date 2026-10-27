//
//  SentenceLibraryTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct `Sentence corpora` {
  private static func level(_ standard: HSKLevel.Standard, _ band: Int) -> HSKLevel {
    HSKLevel(standard: standard, band: band)
  }

  @Test
  func `a corpus lists a standard's levels ascending, leaving out sentences it doesn't level`()
    throws
  {
    let corpus = try SentenceCorpus.fixture([
      LeveledSentence(id: "a", levels: [.newest: 3, .old: 2]),
      LeveledSentence(id: "b", levels: [.newest: 1]),
      LeveledSentence(id: "c", levels: [.newest: 2, .old: 2])
    ])
    #expect(corpus.levels(in: .newest) == [1, 2, 3].map { Self.level(.newest, $0) })
    #expect(corpus.sentenceCounts(in: .old) == [Self.level(.old, 2): 2])
    #expect(corpus.levels(in: .new).isEmpty)
  }

  @Test
  func `a level's sentences keep their source order, and the count includes unleveled sentences`()
    throws
  {
    let corpus = try SentenceCorpus.fixture([
      LeveledSentence(id: "a", levels: [.newest: 2]),
      LeveledSentence(id: "b", levels: [.newest: 1]),
      LeveledSentence(id: "c", levels: [.newest: 2]),
      LeveledSentence(id: "d", levels: [:])
    ])
    #expect(corpus.sentences(in: Self.level(.newest, 1)).map(\.id) == ["b"])
    #expect(corpus.sentences(in: Self.level(.newest, 2)).map(\.id) == ["a", "c"])
    #expect(corpus.sentenceCount == 4)
  }

  @Test
  func `the library resolves a sentence and a corpus by id, even a sentence no standard levels`()
    throws
  {
    let first = try SentenceCorpus.fixture([
      LeveledSentence(id: "a", levels: [.newest: 1]),
      LeveledSentence(id: "unleveled", levels: [:])
    ])
    let library = SentenceLibrary(corpora: [first])

    #expect(library.defaultCorpus?.id == first.id)
    #expect(library.corpus(id: first.id)?.id == first.id)
    #expect(library.sentence(id: "a")?.hanzi == "句a")
    #expect(library.sentence(id: "unleveled") != nil)
    #expect(library.sentence(id: "missing") == nil)
    #expect(library.corpus(id: "missing") == nil)
  }
}
