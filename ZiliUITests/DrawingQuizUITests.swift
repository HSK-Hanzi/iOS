//
//  DrawingQuizUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Driving the drawing quiz's chrome from configuration to results. The stroke canvas is a
/// gesture surface XCUITest cannot draw on, so this exercises only the quiz frame around it:
/// configure the deck, start it, and skip past every card to the results screen. The drawing
/// gesture and its grading are covered by unit tests (`StrokeTestEvaluatorTests`), because
/// XCUITest cannot synthesize median-matching strokes for the evaluator to score.
final class DrawingQuizUITests: ZiliUITestCase {
  /// A round opens on its prompt, whose only control is "Draw it!"; the skip control appears once
  /// writing begins. Neither carries a stable deck size, so each card is advanced in two taps —
  /// begin writing, then skip — until the results seal appears.
  @MainActor
  func testSkipThroughDrawingQuizToResults() async throws {
    launch()
    await openDrawingQuizConfiguration()
    await startQuiz()

    for _ in 0..<120 {
      if el(AccessibilityID.quizResults).exists { break }

      // Prompt phase: begin writing so the skip control appears.
      let beginWriting = el(AccessibilityID.drawingDrawButton)
      if beginWriting.wait() { beginWriting.forceTap() }

      if el(AccessibilityID.quizResults).exists { break }

      // Writing phase: the canvas can't be drawn on, so skip the card.
      let skip = el(AccessibilityID.quizSkipButton)
      if skip.wait() { skip.forceTap() } else { break }
    }

    expect(AccessibilityID.quizResults, "The quiz reaches its results.")
  }
}
