//
//  RecognitionQuizUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Driving the recognition (flashcard) quiz end to end: dealing a deck and judging every card
/// through to its results seal.
///
/// The empty-deck state isn't exercised here: the configuration's Start button is disabled whenever
/// the chosen source resolves to zero words (an unstarred Favorites or unmissed Missed deck), so
/// `QuizEmptyDeckView` is unreachable through the recognition setup. `QuizEmptyDeckViewTests`-style
/// coverage would need a seam the UI doesn't offer, so the empty case is left to the view's preview.
final class RecognitionQuizUITests: ZiliUITestCase {
  func testRunQuizToResults() async throws {
    launch()
    let quiz = await QuizPage.openRecognition(self)
    await quiz.start()
    let deckSize = try XCTUnwrap(quiz.deckSize, "The progress pill counts the deck.")

    // Each card is judged only once it has been dealt: a judged card is thrown off before the next
    // takes its place, and a press that lands mid-throw is ignored rather than queued.
    for card in 1..<deckSize {
      quiz.judgeCorrect()
      quiz.expectProgress(card: card + 1, of: deckSize, "Judging a card deals the next.")
    }
    quiz.judgeCorrect()

    quiz.expectResults()
  }

  #if os(macOS)
    /// Judging a deck without touching the pointer. Space turns the card and an unmodified arrow
    /// judges it, which is the whole reach a hardware keyboard has: the Quiz menu's ⌘-arrows are a
    /// Mac-only surface, so before this the card could be graded by key but only turned by click.
    ///
    /// Neither the turn nor the outcome each arrow records is asserted. Both faces stay in the
    /// hierarchy through the flip, the hidden one at zero opacity, so "the answer is showing" is
    /// not a question the accessibility tree answers; and all three outcomes advance the deck by
    /// one, so only the results seal's tallies tell the arrows apart. What is checked is that every
    /// key reaches the quiz — Space consumed, so a card judged after a flip advances one place and
    /// not two, and each arrow judging exactly one card.
    func testJudgeDeckByKeyboard() async throws {
      launch()
      let quiz = await QuizPage.openRecognition(self)
      await quiz.start()
      quiz.expectProgress(card: 1, "The quiz deals its first card.")

      quiz.flipByKeyboard()
      quiz.judgeByKeyboard(.rightArrow)
      quiz.expectProgress(card: 2, "Correct advances one card, and the flip before it was inert.")

      quiz.judgeByKeyboard(.leftArrow)
      quiz.expectProgress(card: 3, "Needs-review advances.")

      quiz.judgeByKeyboard(.upArrow)
      quiz.expectProgress(card: 4, "Skip advances.")
    }
  #endif
}
