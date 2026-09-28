//
//  SpeakingQuizUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Running a speaking quiz end to end. A test has no voice, so each launch scripts what the app
/// hears in place of the microphone; the tests exercise the grading of what was heard, all the way
/// to the results seal, and the screen shown when recognition can't be readied.
final class SpeakingQuizUITests: ZiliUITestCase {
  func testWordsSaidRightAreGradedCorrectToResults() async throws {
    launch(speech: .echo)
    let quiz = await QuizPage.openSpeaking(self)
    await quiz.start()

    sayEveryWord(in: quiz, gradedAs: AccessibilityID.speakingCorrect)

    quiz.expectResults("Saying every word right runs the deck out to its results.")
  }

  func testWordsSaidWrongAreGradedForReviewToResults() async throws {
    launch(speech: .mishear)
    let quiz = await QuizPage.openSpeaking(self)
    await quiz.start()

    sayEveryWord(in: quiz, gradedAs: AccessibilityID.speakingNeedsReview)

    quiz.expectResults("Saying every word wrong runs the deck out to its results.")
  }

  func testRecognitionThatCannotBeReadiedIsRetried() async throws {
    launch(speech: .unavailableUntilRetried)
    let quiz = await QuizPage.openSpeaking(self)
    await tapStart()

    expect(AccessibilityID.speakingUnavailable, "Recognition that can't be readied says so.")
    await tap(AccessibilityID.speakingRetry, "Try readying recognition again.")
    quiz.expectProgress(card: 1, of: 20, "A retry that readies recognition starts the quiz.")
  }

  /// Lets each word be heard as it appears — a round starts listening by itself — checking it
  /// earns the verdict `verdictID`, and moves on until the deck runs out.
  private func sayEveryWord(in quiz: QuizPage, gradedAs verdictID: String) {
    for _ in 0..<60 {
      if quiz.results.exists { break }
      guard quiz.nextButton.wait() else { break }

      expect(verdictID, "The word is graded as expected.")
      quiz.nextButton.forceTap()
    }
  }
}
