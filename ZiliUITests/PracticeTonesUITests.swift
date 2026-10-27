//
//  PracticeTonesUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Practicing tones: choosing a tone pair from the grid lists its words, and a word opens its entry.
final class PracticeTonesUITests: ZiliUITestCase {
  func testChoosePairToWordEntry() async throws {
    launch()
    await goToPracticeTones()

    // Low-then-falling words (准备, 午饭) are taught in the first two levels of every standard.
    await tap(AccessibilityID.tonePairCell(3, 4), "The low-then-falling cell.")
    expect(AccessibilityID.tonePairPlayAll, "The pair's word list.")
    await tap(AccessibilityID.tonePairWord, "A word said with the pair.")
    expect(AccessibilityID.wordEntry, "The word's entry.")
  }
}
