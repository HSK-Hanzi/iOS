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
    await openRecognitionQuizConfiguration()
    await startQuiz()

    // The deck size isn't known, so judge each card correct until the results seal appears; stop
    // early if the button vanishes (the deck ran out) so the loop can't spin.
    for _ in 0..<60 {
      if el(AccessibilityID.quizResults).exists { break }
      let button = el(AccessibilityID.quizCorrectButton)
      if button.exists { button.forceTap() } else { break }
    }

    expect(AccessibilityID.quizResults, "The quiz reaches its results.")
  }

  #if os(macOS)
    /// Judging a deck without touching the pointer. Space turns the card and an unmodified arrow
    /// judges it, which is the whole reach a hardware keyboard has: the Quiz menu's ⌘-arrows are a
    /// Mac-only surface, so before this the card could be graded by key but only turned by click.
    ///
    /// The turn itself isn't asserted. Both faces stay in the hierarchy through the flip, the
    /// hidden one at zero opacity, so "the answer is showing" is not a question the accessibility
    /// tree answers. What is checked is that Space is consumed — a card judged after a flip
    /// advances exactly one place, not two — and that each arrow judges in its own direction.
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
