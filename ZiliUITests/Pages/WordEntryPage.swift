//
//  WordEntryPage.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// A word's full entry, reached from a dictionary result or a practice word cell. Exposes the
/// favorite toggle and asserts the entry is on screen.
@MainActor
struct WordEntryPage: Page {
  let test: ZiliUITestCase

  /// The star that adds or removes the word from Favorites.
  var favoriteToggle: XCUIElement {
    el(AccessibilityID.wordFavoriteToggle)
  }

  /// Asserts the entry is showing.
  @discardableResult
  func expectVisible() -> XCUIElement {
    test.expect(AccessibilityID.wordEntry, "The word's entry.")
  }

  /// Toggles the word's favorite state.
  func toggleFavorite() async {
    await test.tap(AccessibilityID.wordFavoriteToggle, "The favorite toggle.")
  }
}
