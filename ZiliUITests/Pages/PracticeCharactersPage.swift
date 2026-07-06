//
//  PracticeCharactersPage.swift
//  ZiliUITests
//

// This page resolves an unidentified confirm-dialog button by hand, so it asserts with XCTest
// directly; the project has no Nimble dependency.
// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// Practice Characters: the HSK level grid and the built-in Favorites and Missed sets. Drilling a
/// set lists its word cells, or its empty state when the set holds nothing; Clear All empties a set
/// through a confirm-first dialog.
@MainActor
struct PracticeCharactersPage: Page {
  let test: ZiliUITestCase

  /// Reaches the character syllabus (its Practice card on iOS, its window on macOS).
  @discardableResult
  static func open(_ test: ZiliUITestCase) async -> Self {
    await test.goToPracticeCharacters()
    return Self(test: test)
  }

  /// Drills the HSK level named `level` (e.g. "Level 1") into its words.
  func openLevel(_ level: String) async {
    await test.tap(AccessibilityID.characterSetLevel(level), "The HSK \(level) tile.")
  }

  /// Drills into the built-in Favorites set.
  func openFavorites() async {
    await test.tap(AccessibilityID.characterSetFavorites, "The Favorites set.")
  }

  /// Drills into the built-in Missed set.
  func openMissed() async {
    await test.tap(AccessibilityID.characterSetMissed, "The Missed set.")
  }

  /// Opens the first word cell in the current set and waits for its entry.
  @discardableResult
  func openFirstWord() async -> WordEntryPage {
    await test.tap(AccessibilityID.characterWordCell, "A word cell.")
    return WordEntryPage(test: test)
  }

  /// Taps Clear All, raising its confirmation dialog.
  func tapClearAll() async {
    await test.tap(AccessibilityID.characterSetClearAll, "Clear All raises the confirm dialog.")
  }

  /// Confirms the "Clear All" dialog. The confirm button carries no identifier and shares its
  /// "Clear All" label with the toolbar button that raised it, so it is resolved by label while
  /// excluding that toolbar button by its identifier.
  func confirmClearAll() {
    let confirm = test.app.buttons
      .matching(
        NSPredicate(
          format: "label == %@ AND identifier != %@",
          "Clear All",
          AccessibilityID.characterSetClearAll
        )
      )
      .firstMatch
    XCTAssertTrue(confirm.wait(), "The Clear All confirmation button.")
    confirm.forceTap()
  }

  /// Asserts the set's words are listed.
  @discardableResult
  func expectWordCells() -> XCUIElement {
    test.expect(AccessibilityID.characterWordCell, "The set's word cells.")
  }

  /// Asserts the set's empty state.
  @discardableResult
  func expectEmptyState() -> XCUIElement {
    test.expect(AccessibilityID.characterSetEmptyState, "The set's empty state.")
  }
}

// swiftlint:enable prefer_nimble
