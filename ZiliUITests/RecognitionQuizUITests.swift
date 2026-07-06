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
  @MainActor
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
}
