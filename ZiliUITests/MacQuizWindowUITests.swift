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
  final class MacQuizWindowUITests: XCTestCase {
    /// The default deck size, so a fresh quiz's progress reads "1 / 20".
    private static let deckSize = 20

    override func setUpWithError() throws {
      continueAfterFailure = false
    }

    @MainActor
    func testConcurrentRecognitionQuizzesAdvanceIndependently() async throws {
      let app = launchApp()

      await startRecognitionQuiz(in: app)
      await startRecognitionQuiz(in: app)

      XCTAssertEqual(progressLabels(in: app, reading: 1).count, 2, "Both quizzes start at card 1.")

      app.typeKey(.rightArrow, modifierFlags: .command)

      let advanced = app.staticTexts[progressText(for: 2)]
      XCTAssertTrue(advanced.waitForExistence(timeout: 5), "The frontmost quiz advances.")
      XCTAssertEqual(progressLabels(in: app, reading: 1).count, 1, "The other quiz does not.")
    }

    /// Launches and waits for the dictionary to load: the File menu's quiz items are inert until
    /// the language database is in hand. Ignoring persisted window state keeps the launch
    /// deterministic — a saved-state window left over from a prior run would otherwise starve
    /// the app's declared scenes of the window slot they need to appear.
    @MainActor
    private func launchApp() -> XCUIApplication {
      let app = XCUIApplication()
      app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
      app.launch()
      let search = app.windows["Dictionary"].searchFields.firstMatch
      XCTAssertTrue(search.waitForExistence(timeout: 60), "The dictionary loads.")
      return app
    }

    /// Opens a recognition quiz with ⌘N and starts it from its configuration sheet, leaving the
    /// new window frontmost and showing its first card. The Start click can be swallowed by the
    /// sheet-dismiss transition; re-clicking until one more first-card label appears recovers the
    /// dropped click without racing a click that has registered but not yet dealt.
    @MainActor
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
    @MainActor
    private func firstCardCount(in app: XCUIApplication, reaches target: Int) -> Bool {
      let predicate = NSPredicate(format: "count >= %d", target)
      let expectation = XCTNSPredicateExpectation(
        predicate: predicate,
        object: progressLabels(in: app, reading: 1)
      )
      return XCTWaiter().wait(for: [expectation], timeout: ScaledTimeouts.element) == .completed
    }

    @MainActor
    private func progressLabels(in app: XCUIApplication, reading card: Int) -> XCUIElementQuery {
      app.staticTexts.matching(identifier: progressText(for: card))
    }

    private func progressText(for card: Int) -> String {
      "\(card) / \(Self.deckSize)"
    }
  }
#endif

// swiftlint:enable prefer_nimble
