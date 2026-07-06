//
//  PracticeCharactersUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Browsing the character syllabus: drill an HSK band into its words and open a word's entry, plus
/// the Missed set's empty state when nothing has been missed.
final class PracticeCharactersUITests: ZiliUITestCase {
  @MainActor
  func testBrowseLevelToWordEntry() async throws {
    launch()
    await goToPracticeCharacters()

    // HSK Level 1 always ships; drilling it fills the set with words, and a word opens its entry.
    await tap(AccessibilityID.characterSetLevel("Level 1"), "The HSK Level 1 tile.")
    expect(AccessibilityID.characterWordCell, "The level's words.")
    await tap(AccessibilityID.characterWordCell, "A word cell.")
    expect(AccessibilityID.wordEntry, "The word's entry.")
  }

  @MainActor
  func testMissedSetIsEmptyWithoutMisses() async throws {
    launch()
    await goToPracticeCharacters()

    // With nothing missed, the Missed set drills into its empty state.
    await tap(AccessibilityID.characterSetMissed, "The Missed set tile.")
    expect(AccessibilityID.characterSetEmptyState, "The empty Missed set.")
  }
}
