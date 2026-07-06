//
//  DictionaryPage.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// The Dictionary screen: search the lexicon and drill a result into its full word entry, plus the
/// pre-search prompt and no-results states that book-end a search.
@MainActor
struct DictionaryPage: Page {
  let test: ZiliUITestCase

  /// Brings the dictionary forward (its tab on iOS, its window on macOS) and returns the page.
  @discardableResult
  static func open(_ test: ZiliUITestCase) -> Self {
    test.goToDictionary()
    return Self(test: test)
  }

  /// Types `query` into the dictionary's search field.
  func search(_ query: String) {
    test.type(query, into: test.searchField)
  }

  /// Asserts the "search the dictionary" prompt shown before any query is typed.
  @discardableResult
  func expectPreSearchPrompt() -> XCUIElement {
    test.expect(AccessibilityID.dictionaryEmptyState, "The pre-search prompt.")
  }

  /// Asserts the ranked results list appeared.
  @discardableResult
  func expectResults() -> XCUIElement {
    test.expect(AccessibilityID.dictionaryResults, "The results list.")
  }

  /// Asserts the empty state shown when a query matches nothing.
  @discardableResult
  func expectNoResults() -> XCUIElement {
    test.expect(AccessibilityID.dictionaryEmptyState, "The no-results state.")
  }

  /// Opens a mid-list result and waits for its full entry, returning the word entry page. Tapping a
  /// mid-band row dodges the search bar and keyboard that hide the top and bottom rows.
  @discardableResult
  func openFirstResult() async -> WordEntryPage {
    await test.tapVisible(
      AccessibilityID.dictionaryResultRow,
      until: AccessibilityID.wordEntry,
      "The word's entry."
    )
    return WordEntryPage(test: test)
  }
}
