//
//  ListeningQuizUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Running a listening quiz end to end: hear a sentence, type an answer, and have it auto-graded.
/// CJK entry is unreliable in the simulator, so every answer is a deliberately-wrong latin "x",
/// exercising the wrong-answer grading path from the first prompt all the way to the results seal.
final class ListeningQuizUITests: ZiliUITestCase {
  func testWrongAnswersAreGradedToResults() async throws {
    launch()
    await openListeningQuizConfiguration()
    await startQuiz()

    // Each round has two identified moments: the answer field while listening, then a graded reveal
    // whose "Next" button advances. A round is submit → Next; looping that runs the deck out to its
    // results.
    for _ in 0..<60 {
      if el(AccessibilityID.quizResults).exists { break }

      let answerField = el(AccessibilityID.listeningAnswerField)
      guard answerField.wait() else { break }

      // The field submits on Return, running the same grading the "Check" button does, and the
      // reveal that replaces it takes the keyboard with it. Tapping "Check" instead would mean
      // dismissing a keyboard this screen gives no way to dismiss: it hides its navigation bar and
      // does not scroll, so the swipe fallback swipes at nothing until its deadline expires.
      type("x\n", into: answerField)

      // Grading only swaps in the reveal; its Next button advances the deck.
      let next = el(AccessibilityID.quizNextButton)
      if next.wait() { next.forceTap() }
    }

    expect(
      AccessibilityID.quizResults,
      "Grading every wrong answer runs the deck out to its results."
    )
  }
}
