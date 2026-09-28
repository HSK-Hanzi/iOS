//
//  MacQuizWindowUITests.swift
//  ZiliUITests
//

// The UI test target doesn't link Swift Testing, and the project has no Nimble dependency, so
// XCTest's own assertions are the only ones available here.
// swiftlint:disable prefer_nimble

#if os(macOS)
  import XCTest
  import XCUITestKit

  /// Each quiz window deals and judges its own deck. Two recognition quizzes running at once must
  /// advance independently — the whole reason a quiz is a window rather than a tab.
  final class MacQuizWindowUITests: ZiliUITestCase {
    /// The default deck size, so a fresh quiz's progress reads "1 / 20".
    private static let deckSize = 20

    func testConcurrentRecognitionQuizzesAdvanceIndependently() async throws {
      let app = launch()

      await startRecognitionQuiz(in: app)
      await startRecognitionQuiz(in: app)

      XCTAssertEqual(progressLabels(in: app, reading: 1).count, 2, "Both quizzes start at card 1.")

      app.typeKey(.rightArrow, modifierFlags: .command)

      let advanced = app.staticTexts[progressText(for: 2)]
      XCTAssertTrue(advanced.waitForExistence(timeout: 5), "The frontmost quiz advances.")
      XCTAssertEqual(progressLabels(in: app, reading: 1).count, 1, "The other quiz does not.")
    }

    /// Opens a recognition quiz with ⌘N and starts it from its configuration sheet, leaving the
    /// new window frontmost and showing its first card. The Start click can be swallowed by the
    /// sheet-dismiss transition; re-clicking until one more first-card label appears recovers the
    /// dropped click without racing a click that has registered but not yet dealt.
    private func startRecognitionQuiz(in app: XCUIApplication) async {
      let dealtBefore = progressLabels(in: app, reading: 1).count
      app.typeKey("n", modifierFlags: .command)
      let start = app.buttons["Start Quiz"].firstMatch
      XCTAssertTrue(
        start.wait(timeout: ScaledTimeouts.slowElement),
        "The configuration sheet appears."
      )
      let dealt = await Retry.untilVerified(
        action: { if start.exists { start.forceTap() } },
        until: { self.firstCardCount(in: app, reaches: dealtBefore + 1) }
      )
      XCTAssertTrue(dealt, "The quiz deals its first card.")
    }

    /// Waits for the number of quizzes showing their first card to reach `target`. Waiting rather
    /// than sampling means a Start click that has registered but not yet dealt is not mistaken for
    /// a dropped one and re-issued into the dismissing sheet.
    private func firstCardCount(in app: XCUIApplication, reaches target: Int) -> Bool {
      let predicate = NSPredicate(format: "count >= %d", target)
      let expectation = XCTNSPredicateExpectation(
        predicate: predicate,
        object: progressLabels(in: app, reading: 1)
      )
      return XCTWaiter().wait(for: [expectation], timeout: ScaledTimeouts.element) == .completed
    }

    private func progressLabels(in app: XCUIApplication, reading card: Int) -> XCUIElementQuery {
      app.staticTexts.matching(identifier: progressText(for: card))
    }

    private func progressText(for card: Int) -> String {
      "\(card) / \(Self.deckSize)"
    }
  }
#endif

// swiftlint:enable prefer_nimble
