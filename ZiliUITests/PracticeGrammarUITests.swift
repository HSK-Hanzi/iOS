//
//  PracticeGrammarUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Practicing grammar: a level lists its grammar points, and a point opens to its explanation and
/// example sentences, one of which opens to its detail.
final class PracticeGrammarUITests: ZiliUITestCase {
  func testChoosePointToExampleSentence() async throws {
    launch()
    await goToPracticeGrammar()

    await tap(AccessibilityID.grammarLevel(1), "The HSK 3.0 Level 1 tile.")
    await tap(AccessibilityID.grammarPoint, "A level 1 grammar point.")
    await tap(AccessibilityID.sentenceRow, "An example of the point.")
    expect(AccessibilityID.sentenceDetail, "The example's detail.")
  }
}
