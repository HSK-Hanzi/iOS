//
//  QuizPage.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// A quiz, from its configuration form through its running deck to the results seal. One page covers
/// all three quiz kinds — recognition (flashcards), drawing, and listening — because they share a
/// configuration form and a running frame (progress pill, close, results); the kind-specific
/// controls (judge buttons, the draw button, the listening answer field) hang off the same page.
@MainActor
struct QuizPage: Page {
  let test: ZiliUITestCase

  // MARK: - Running-frame elements

  /// The results seal shown once the deck runs out.
  var results: XCUIElement { el(AccessibilityID.quizResults) }

  /// The recognition quiz's "I knew it" judge button.
  var correctButton: XCUIElement { el(AccessibilityID.quizCorrectButton) }

  /// The button that advances to the next card after a graded reveal.
  var nextButton: XCUIElement { el(AccessibilityID.quizNextButton) }

  /// The prompt-phase "Draw it!" button; tapping it begins a drawing round's writing phase.
  var drawButton: XCUIElement { el(AccessibilityID.drawingDrawButton) }

  /// The writing-phase button that skips the current character.
  var skipButton: XCUIElement { el(AccessibilityID.quizSkipButton) }

  /// The field a listening answer is typed into while the sentence plays.
  var answerField: XCUIElement { el(AccessibilityID.listeningAnswerField) }

  // MARK: - Opening a quiz

  /// Opens a recognition (flashcard) quiz onto its configuration form.
  @discardableResult
  static func openRecognition(_ test: ZiliUITestCase) async -> Self {
    await test.openRecognitionQuizConfiguration()
    return Self(test: test)
  }

  /// Opens a drawing quiz onto its configuration form.
  @discardableResult
  static func openDrawing(_ test: ZiliUITestCase) async -> Self {
    await test.openDrawingQuizConfiguration()
    return Self(test: test)
  }

  /// Opens a listening quiz onto its configuration form.
  @discardableResult
  static func openListening(_ test: ZiliUITestCase) async -> Self {
    await test.openListeningQuizConfiguration()
    return Self(test: test)
  }

  // MARK: - Actions

  /// Starts the quiz from its configuration form and waits for the first card's progress pill.
  func start() async {
    await test.startQuiz()
  }

  /// Asserts the quiz reached its results seal.
  @discardableResult
  func expectResults(_ message: String = "The quiz reaches its results.") -> XCUIElement {
    test.expect(AccessibilityID.quizResults, message)
  }

  /// Types `answer` into the listening answer field.
  func typeAnswer(_ answer: String) {
    test.type(answer, into: answerField)
  }

  /// Grades the typed listening answer, swapping in its reveal.
  func submitAnswer() async {
    await test.tap(AccessibilityID.listeningSubmit, "Check the typed answer.")
  }
}
