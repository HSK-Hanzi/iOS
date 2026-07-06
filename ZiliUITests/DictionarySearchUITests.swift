//
//  DictionarySearchUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Looking a word up: search the whole lexicon, then open a result's full entry — plus the
/// empty-search and no-results states that book-end it.
///
/// This flow is the proof-of-concept for the ``Page`` layer: it drives the app through
/// ``DictionaryPage`` rather than raw accessibility identifiers. The remaining flows still call
/// ``ZiliUITestCase``'s verbs directly and are a follow-up migration.
final class DictionarySearchUITests: ZiliUITestCase {
  @MainActor
  func testSearchFindsAWordAndOpensItsEntry() async throws {
    launch()
    let dictionary = DictionaryPage.open(self)

    // Before typing, the dictionary shows its "search the dictionary" prompt.
    dictionary.expectPreSearchPrompt()

    dictionary.search("hao")

    // A ranked result appears; opening one shows the word's full entry.
    dictionary.expectResults()
    let entry = await dictionary.openFirstResult()
    entry.expectVisible()
  }

  @MainActor
  func testSearchWithNoMatchesShowsTheEmptyState() throws {
    launch()
    let dictionary = DictionaryPage.open(self)

    dictionary.search("zzzzzzzz")

    dictionary.expectNoResults()
  }
}
