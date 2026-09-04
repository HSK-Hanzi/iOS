//
//  ListeningQuizSessionTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

@MainActor
struct ListeningQuizSessionTests {
  private static let deck = [
    PracticeSentence(
      id: "a",
      level: 1,
      hanzi: "一",
      numberedPinyin: "yi1",
      translation: "one"
    ),
    PracticeSentence(
      id: "b",
      level: 1,
      hanzi: "二",
      numberedPinyin: "er4",
      translation: "two"
    ),
    PracticeSentence(
      id: "c",
      level: 1,
      hanzi: "三",
      numberedPinyin: "san1",
      translation: "three"
    )
  ]

  @Test
  func `marking a sentence records its outcome, advances, and tallies right and wrong`() {
    let session = ListeningQuizSession(deck: Self.deck)
    #expect(session.current?.id == "a")

    session.mark(correct: true)
    #expect(session.current?.id == "b")
    #expect(session.correctCount == 1)
    #expect(session.incorrectCount == 0)
    #expect(!session.isFinished)

    session.mark(correct: false)
    #expect(session.current?.id == "c")
    #expect(session.correctCount == 1)
    #expect(session.incorrectCount == 1)
  }

  @Test
  func `answering every sentence finishes the deck`() {
    let session = ListeningQuizSession(deck: Self.deck)
    session.mark(correct: true)
    session.mark(correct: false)
    #expect(!session.isFinished)

    session.mark(correct: true)
    #expect(session.isFinished)
    #expect(session.current == nil)
  }

  @Test
  func `marking past the end is a no-op`() {
    let session = ListeningQuizSession(deck: Self.deck)
    session.mark(correct: true)
    session.mark(correct: true)
    session.mark(correct: true)

    session.mark(correct: false)
    #expect(session.currentIndex == 3)
    #expect(session.correctCount == 3)
    #expect(session.incorrectCount == 0)
  }

  @Test
  func `onMiss fires only for wrong answers, with the sentence's id`() {
    var missed: [String] = []
    let session = ListeningQuizSession(deck: Self.deck) { missed.append($0) }

    session.mark(correct: false)
    session.mark(correct: true)
    session.mark(correct: false)

    #expect(missed == ["a", "c"])
  }

  @Test
  func `the re-drill pile is the missed sentences, in deck order`() {
    let session = ListeningQuizSession(deck: Self.deck)
    session.mark(correct: false)
    session.mark(correct: true)
    session.mark(correct: false)

    #expect(session.sentencesToReDrill.map(\.id) == ["a", "c"])
  }

  @Test
  func `re-drilling restarts with only the missed sentences and clears progress`() {
    let session = ListeningQuizSession(deck: Self.deck)
    session.mark(correct: false)
    session.mark(correct: true)
    session.mark(correct: false)

    session.reDrill()

    #expect(session.deck.map(\.id) == ["a", "c"])
    #expect(session.currentIndex == 0)
    #expect(session.correctCount == 0)
    #expect(session.incorrectCount == 0)
    #expect(!session.isFinished)
  }
}
