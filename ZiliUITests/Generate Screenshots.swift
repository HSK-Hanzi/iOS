//
//  Generate Screenshots.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Captures the App Store screenshot set with fastlane's `snapshot`. It reuses ``ZiliUITestCase``'s
/// platform-portable navigation verbs to walk the app's showcase screens, calling ``capture(_:)`` at
/// each, so `bundle exec fastlane screenshots` yields the same journey on every configured device.
///
/// This isn't an assertion test: its `expect`/`wait` calls exist only to synchronize a capture with
/// the screen it means to photograph, so a shot is never taken mid-transition. Both practice
/// browsers are drilled into a level first, so each shows the level's real content rather than a
/// bare picker grid.
final class GenerateScreenshots: ZiliUITestCase {
  /// Wires fastlane's screenshot bridge into the app before it launches, so `-uiTesting`'s
  /// deterministic state and `snapshot`'s capture arguments both take effect on the one launch.
  override func prepareForLaunch() {
    setupSnapshot(app)
  }

  @MainActor
  func testGenerateScreenshots() async throws {
    launch(seed: [.favorites, .misses])

    await captureDictionary()
    await capturePractice()
    await captureQuizzes()
  }

  // MARK: - Flows

  /// A chosen result's full entry, reached by searching the dictionary with an English query.
  private func captureDictionary() async {
    goToDictionary()
    type("hello", into: searchField)
    dismissKeyboard()
    expect(AccessibilityID.dictionaryResults, "The dictionary's search results.")

    await tap(
      AccessibilityID.dictionaryResultRow,
      until: AccessibilityID.wordEntry,
      "A word's full entry."
    )
    capture("01-WordEntry")
  }

  /// Both practice browsers drilled into their first level, so each shows real content.
  private func capturePractice() async {
    await goToPracticeCharacters()
    await tap(AccessibilityID.characterSetLevel("Level 1"), "The HSK Level 1 set.")
    expect(AccessibilityID.characterWordCell, "The level's words.")
    capture("02-PracticeCharacters")

    await goToPracticeSentences()
    await tap(AccessibilityID.sentenceSetLevel(1), "The first corpus level.")
    expect(AccessibilityID.sentenceRow, "The level's sentences.")
    capture("03-PracticeSentences")
  }

  /// Each study mode on its first live card.
  private func captureQuizzes() async {
    await openRecognitionQuizConfiguration()
    await startQuiz()
    capture("04-Flashcard")

    await openDrawingQuizConfiguration()
    await startQuiz()
    capture("05-DrawingQuiz")

    await openListeningQuizConfiguration()
    await startQuiz()
    capture("06-ListeningQuiz")
  }

  // MARK: - Capture

  /// Photographs the current screen under `name` through fastlane's `snapshot`.
  private func capture(_ name: String) {
    snapshot(name)
  }
}
