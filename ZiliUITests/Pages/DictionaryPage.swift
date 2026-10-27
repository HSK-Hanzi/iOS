//
//  DictionaryPage.swift
//  ZiliUITests
//

// This page asserts on the one result it opens by hand, so it asserts with XCTest directly; the
// project has no Nimble dependency.
// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// The Dictionary screen: search the lexicon and drill a result into its full word entry, plus the
/// pre-search prompt and no-results states that book-end a search.
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

  /// Opens the result for exactly `headword` — its row's text, the label on iOS and the value on
  /// macOS, leads with it — and waits for the entry.
  @discardableResult
  func openResult(_ headword: String) async -> WordEntryPage {
    let row = test.app.descendants(matching: .any)
      .matching(identifier: AccessibilityID.dictionaryResultRow)
      .matching(
        NSPredicate(
          format: "label BEGINSWITH %@ OR value BEGINSWITH %@",
          "\(headword),",
          "\(headword),"
        )
      )
      .firstMatch
    XCTAssertTrue(row.wait(), "The result for \(headword).")
    await test.tapWhenSettled(row)
    test.expect(AccessibilityID.wordEntry, "The entry for \(headword).")
    return WordEntryPage(test: test)
  }

  /// Opens the radical index, chooses the radical numbered `radical`, and opens the first
  /// character indexed under it.
  @discardableResult
  func openFirstCharacter(withRadical radical: String) async -> WordEntryPage {
    await test.tap(AccessibilityID.dictionaryRadicals, "The radical index button.")
    await test.tap(AccessibilityID.radicalCell(radical), "The radical numbered \(radical).")
    await test.tap(AccessibilityID.radicalCharacter, "A character under the radical.")
    return WordEntryPage(test: test)
  }
}

// swiftlint:enable prefer_nimble
