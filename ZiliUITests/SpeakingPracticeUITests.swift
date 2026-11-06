//
//  SpeakingPracticeUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Practicing speaking end to end. Each word is said by the app and then heard back; a test has no
/// voice, so each launch scripts what the app hears in place of the microphone. The tests follow a
/// deck said right through to its end and round again, and a word said wrong through to trying it
/// again and moving on.
final class SpeakingPracticeUITests: ZiliUITestCase {
  func testWordsSaidBackRunTheDeckOutAndRoundAgain() async throws {
    launch(speech: .echo)
    let practice = await QuizPage.openSpeakingPractice(self)
    await practice.start()
    let deckSize = try XCTUnwrap(practice.deckSize, "The progress pill reads the deck size.")

    sayEveryWord(in: practice, gradedAs: AccessibilityID.verdictCorrect)

    expect(AccessibilityID.practiceFinished, "Every word said runs the deck out.")
    await tap(AccessibilityID.practiceAgain, "Practice the deck again.")
    practice.expectProgress(card: 1, of: deckSize, "Practice Again starts the deck over.")
  }

  func testWordSaidWrongCanBeTriedAgainAndPassed() async throws {
    launch(speech: .mishear)
    let practice = await QuizPage.openSpeakingPractice(self)
    await practice.start()
    let deckSize = try XCTUnwrap(practice.deckSize, "The progress pill reads the deck size.")

    expect(AccessibilityID.verdictNeedsReview, "A word said wrong is graded for improvement.")
    expect(AccessibilityID.speakingHeard, "What was heard instead is shown.")

    await tap(AccessibilityID.practiceTryAgain, "Say the word again.")
    expect(AccessibilityID.verdictNeedsReview, "The word is heard and graded again.")
    practice.expectProgress(card: 1, of: deckSize, "Trying again stays on the same word.")

    practice.nextButton.forceTap()
    practice.expectProgress(card: 2, of: deckSize, "Next moves on to the following word.")
  }

  /// Lets each word be said and heard — a turn listens by itself once the word has been spoken —
  /// checking it earns the verdict `verdictID`, and moves on until the deck runs out.
  private func sayEveryWord(in practice: QuizPage, gradedAs verdictID: String) {
    let finished = el(AccessibilityID.practiceFinished)
    for _ in 0..<60 {
      if finished.exists { break }
      guard practice.nextButton.wait() else { break }

      expect(verdictID, "The word is graded as expected.")
      practice.nextButton.forceTap()
    }
  }
}
