//
//  SpeakingSentencesUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Reading sentences aloud, end to end. A test has no voice, so each launch scripts what the app
/// hears in place of the microphone: practice hears each sentence said back right, through to the
/// end of the deck; a quiz hears each misread, with what was heard shown, through to the results.
final class SpeakingSentencesUITests: ZiliUITestCase {
  func testPracticeSaysEachSentenceBackToTheEnd() async throws {
    launch(speech: .echo)
    await openSpeakingSentencesPracticeConfiguration()
    await startQuiz()

    readEverySentence(
      gradedAs: AccessibilityID.verdictCorrect,
      until: AccessibilityID.practiceFinished
    )

    expect(AccessibilityID.practiceFinished, "Saying every sentence back runs the deck out.")
  }

  func testQuizGradesMisreadSentencesToResults() async throws {
    launch(speech: .mishear)
    await openSpeakingSentencesQuizConfiguration()
    await startQuiz()

    expect(AccessibilityID.speakingHeard, "What was heard instead of the sentence is shown.")
    readEverySentence(
      gradedAs: AccessibilityID.verdictNeedsReview,
      until: AccessibilityID.quizResults
    )

    expect(
      AccessibilityID.quizResults,
      "Misreading every sentence runs the deck out to its results."
    )
  }

  /// Lets each sentence be heard as it appears, checking it earns the verdict `verdictID`, and moves
  /// on until `endID` shows.
  private func readEverySentence(gradedAs verdictID: String, until endID: String) {
    let next = el(AccessibilityID.quizNextButton)
    for _ in 0..<60 {
      if el(endID).exists { break }
      guard next.wait() else { break }

      expect(verdictID, "The sentence is graded as expected.")
      next.forceTap()
    }
  }
}
