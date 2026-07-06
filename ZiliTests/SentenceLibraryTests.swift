//
//  SentenceLibraryTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct SentenceLibraryTests {
  private static func sentence(_ id: String, level: Int) -> PracticeSentence {
    PracticeSentence(
      id: id,
      level: level,
      hanzi: "句\(id)",
      numberedPinyin: "ju4",
      translation: "sentence \(id)"
    )
  }

  @Test("A corpus lists its levels ascending, whatever order its sentences arrived in")
  func levelsAreSortedAscending() {
    let corpus = SentenceCorpus(
      source: .practice,
      sentences: [
        Self.sentence("a", level: 3), Self.sentence("b", level: 1), Self.sentence("c", level: 2)
      ]
    )
    #expect(corpus.levels == [1, 2, 3])
  }

  @Test("A level's sentences keep their source order, and allSentences reads level by level")
  func sentencesKeepSourceOrderWithinLevel() {
    let corpus = SentenceCorpus(
      source: .practice,
      sentences: [
        Self.sentence("a", level: 2),
        Self.sentence("b", level: 1),
        Self.sentence("c", level: 2),
        Self.sentence("d", level: 1)
      ]
    )
    #expect(corpus.sentences(in: 1).map(\.id) == ["b", "d"])
    #expect(corpus.sentences(in: 2).map(\.id) == ["a", "c"])
    #expect(corpus.allSentences.map(\.id) == ["b", "d", "a", "c"])
    #expect(corpus.sentenceCount == 4)
  }

  @Test("The library resolves a sentence and a corpus by id across every loaded corpus")
  func libraryResolvesByID() {
    let first = SentenceCorpus(source: .practice, sentences: [Self.sentence("a", level: 1)])
    let library = SentenceLibrary(corpora: [first])

    #expect(library.defaultCorpus?.id == first.id)
    #expect(library.corpus(id: first.id)?.id == first.id)
    #expect(library.sentence(id: "a")?.level == 1)
    #expect(library.sentence(id: "missing") == nil)
    #expect(library.corpus(id: "missing") == nil)
  }
}
