//
//  ListeningCharactersUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Picking words out by ear, end to end. A test can't hear which word was said, so the quiz picks
/// whichever choice comes first, through to the results; practice keeps picking until a wrong pick
/// is ruled out and the word is found, through to the end of the deck and round again.
final class ListeningCharactersUITests: ZiliUITestCase {
  func testQuizTakesOnePickPerWordToResults() async throws {
    launch()
    await openListeningCharactersQuizConfiguration()
    await startQuiz()

    for _ in 0..<60 {
      if el(AccessibilityID.quizResults).exists { break }
      guard firstOpenChoice().wait() else { break }

      firstOpenChoice().forceTap()
      expect(AccessibilityID.quizNextButton, "One pick answers the word.")
      tapNext()
    }

    expect(
      AccessibilityID.quizResults,
      "Picking a choice per word runs the deck out to its results."
    )
  }

  func testPracticePicksUntilTheWordIsFoundAndRoundsAgain() async throws {
    launch()
    await openListeningCharactersPracticeConfiguration()
    await startQuiz()

    for _ in 0..<60 {
      if el(AccessibilityID.practiceFinished).exists { break }
      guard firstOpenChoice().wait() else { break }

      pickUntilFound()
      tapNext()
    }

    expect(AccessibilityID.practiceFinished, "Finding every word runs the deck out.")
    await tap(AccessibilityID.practiceAgain, "Practice the deck again.")
    expect(AccessibilityID.listeningChoice, "Practice Again starts the deck over.")
  }

  /// The choices still open to pick.
  private func openChoices() -> XCUIElementQuery {
    app.descendants(matching: .any)
      .matching(identifier: AccessibilityID.listeningChoice)
      .matching(NSPredicate(format: "isEnabled == true"))
  }

  /// The first choice still open to pick.
  private func firstOpenChoice() -> XCUIElement {
    openChoices().firstMatch
  }

  /// Picks open choices one at a time until the word is found and the card turns over — at most
  /// once per choice, since practice rules each wrong pick out.
  private func pickUntilFound() {
    let next = el(AccessibilityID.quizNextButton)
    for _ in 0..<4 where !next.exists {
      let openBefore = openChoices().count
      firstOpenChoice().forceTap()
      if !next.exists, !ruledOutOne(of: openBefore) { _ = next.wait(timeout: 2) }
    }
    expect(AccessibilityID.quizNextButton, "Ruling out wrong picks leaves the word to find.")
  }

  /// Whether the last pick was ruled out: one of the `openBefore` choices has gone, and the rest
  /// are still open.
  private func ruledOutOne(of openBefore: Int) -> Bool {
    let open = openChoices().count
    return open == openBefore - 1 && open > 0
  }
}
