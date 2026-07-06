//
//  LoadFailurePage.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// The lexicon-load failure gate: when the language database can't be opened, the app shows a retry
/// screen in place of any feature content.
@MainActor
struct LoadFailurePage: Page {
  let test: ZiliUITestCase

  /// Asserts the retry screen is showing.
  @discardableResult
  func expectRetry(_ message: String = "The load-failure retry screen.") -> XCUIElement {
    test.expect(AccessibilityID.loadFailureRetry, message)
  }

  /// Taps "Try Again" to re-attempt the load.
  func retry() async {
    await test.tap(AccessibilityID.loadFailureRetry, "Try Again.")
  }
}
