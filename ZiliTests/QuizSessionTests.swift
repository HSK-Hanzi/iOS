//
//  QuizSessionTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

@MainActor
struct QuizSessionTests {
  private static let deck = [
    QuizCard(word: "a", hanzi: "一", reading: "yī", definition: "one"),
    QuizCard(word: "b", hanzi: "二", reading: "èr", definition: "two"),
    QuizCard(word: "c", hanzi: "三", reading: "sān", definition: "three")
  ]

  @Test("Marking a card records its outcome and advances, with peek looking one card ahead")
  func marksAndAdvances() {
    let session = QuizSession(deck: Self.deck)
    #expect(session.current?.word == "a")
    #expect(session.peek?.word == "b")

    session.mark(.correct)
    #expect(session.current?.word == "b")
    #expect(session.peek?.word == "c")
    #expect(session.correctCount == 1)
    #expect(!session.isFinished)

    session.mark(.correct)
    #expect(session.current?.word == "c")
    #expect(session.peek == nil)
  }

  @Test("Judging every card finishes the deck and tallies each outcome")
  func talliesOutcomes() {
    let session = QuizSession(deck: Self.deck)
    session.mark(.correct)
    session.mark(.needsReview)
    session.mark(.skipped)

    #expect(session.isFinished)
    #expect(session.correctCount == 1)
    #expect(session.reviewCount == 1)
    #expect(session.skippedCount == 1)
  }

  @Test("The re-drill pile is the reviewed and skipped words, in deck order")
  func reDrillPileIsMissedWords() {
    let session = QuizSession(deck: Self.deck)
    session.mark(.needsReview)
    session.mark(.correct)
    session.mark(.skipped)

    #expect(session.wordsToReDrill == ["a", "c"])
  }

  @Test("Re-drilling restarts with only the missed cards")
  func reDrillKeepsOnlyMisses() {
    let session = QuizSession(deck: Self.deck)
    session.mark(.needsReview)
    session.mark(.correct)
    session.mark(.skipped)

    session.reDrill()

    #expect(session.deck.map(\.word) == ["a", "c"])
    #expect(session.currentIndex == 0)
    #expect(session.correctCount == 0)
    #expect(!session.isFinished)
  }

  @Test("A wrong answer reports its word as missed; a correct or skipped one doesn't")
  func reportsOnlyWrongAnswersAsMisses() {
    var missed: [String] = []
    let session = QuizSession(deck: Self.deck) { missed.append($0) }

    session.mark(.needsReview)
    session.mark(.correct)
    session.mark(.skipped)

    #expect(missed == ["a"])
  }
}
