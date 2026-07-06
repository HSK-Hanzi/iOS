//
//  DictionarySearchUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Looking a word up: search the whole lexicon, then open a result's full entry — plus the
/// empty-search and no-results states that book-end it.
final class DictionarySearchUITests: ZiliUITestCase {
  @MainActor
  func testSearchFindsAWordAndOpensItsEntry() async throws {
    launch()
    goToDictionary()

    // Before typing, the dictionary shows its "search the dictionary" prompt.
    expect(AccessibilityID.dictionaryEmptyState, "The pre-search prompt.")

    type("hao", into: searchField)

    // A ranked result appears; opening one shows the word's full entry. The search keyboard leaves
    // the top row under the search bar and the bottom rows under the keyboard, so tap a mid-list row.
    expect(AccessibilityID.dictionaryResults, "The results list.")
    await tapVisible(
      AccessibilityID.dictionaryResultRow,
      until: AccessibilityID.wordEntry,
      "The word's entry."
    )
  }

  @MainActor
  func testSearchWithNoMatchesShowsTheEmptyState() throws {
    launch()
    goToDictionary()

    type("zzzzzzzz", into: searchField)

    expect(AccessibilityID.dictionaryEmptyState, "The no-results state.")
  }
}
