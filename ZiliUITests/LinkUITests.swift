//
//  LinkUITests.swift
//  ZiliUITests
//

// The UI test target links XCTest, not Swift Testing, so XCTest's own assertions are all that's
// available here.
// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// Following the links the widgets and the Start Review control open the app with, from a launch
/// that is sitting somewhere else entirely.
final class LinkUITests: ZiliUITestCase {
  func testWordLinkOpensItsEntry() throws {
    launch()
    try follow(link: "zili://word/%E5%A5%BD")

    WordEntryPage(test: self).expectVisible()
  }

  func testReviewLinkDealsTheFavorites() throws {
    launch(seed: [.favorites])
    try follow(link: "zili://review")

    // Three seeded favorites, where the form's own default would deal twenty HSK words.
    QuizPage(test: self).expectProgress(card: 1, of: 3, "The review deals the favorites.")
  }

  func testReviewLinkWithNothingStarredStopsAtTheForm() throws {
    launch()
    try follow(link: "zili://review")

    expect(AccessibilityID.quizStartButton, "The form, with nothing to deal.")
    XCTAssertFalse(el(AccessibilityID.quizProgress).exists, "No quiz was dealt.")
  }
}

// swiftlint:enable prefer_nimble
