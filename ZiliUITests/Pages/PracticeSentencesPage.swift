//
//  PracticeSentencesPage.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Practice Sentences: the corpus level grid and the built-in Favorites and Missed sets. Drilling a
/// level lists its sentence rows, and a row opens that sentence's detail; an empty set drills into
/// its empty state.
@MainActor
struct PracticeSentencesPage: Page {
  let test: ZiliUITestCase

  /// Reaches the sentence corpora (its Practice card on iOS, its window on macOS).
  @discardableResult
  static func open(_ test: ZiliUITestCase) async -> Self {
    await test.goToPracticeSentences()
    return Self(test: test)
  }

  /// Opens the corpus level in `band` (1-based) and lists its sentences.
  func openLevel(_ band: Int) async {
    await test.tap(AccessibilityID.sentenceSetLevel(band), "The corpus level \(band).")
  }

  /// Drills into the built-in Missed set.
  func openMissed() async {
    await test.tap(AccessibilityID.sentenceSetMissed, "The Missed set.")
  }

  /// Opens the first sentence row and waits for its detail.
  @discardableResult
  func openFirstSentence() async -> XCUIElement {
    await test.tap(AccessibilityID.sentenceRow, "A sentence row.")
    return test.expect(AccessibilityID.sentenceDetail, "The sentence's detail.")
  }

  /// Asserts the level's sentence list appeared.
  @discardableResult
  func expectSentenceList() -> XCUIElement {
    test.expect(AccessibilityID.sentenceRow, "The level's sentence list.")
  }

  /// Asserts the set's empty state.
  @discardableResult
  func expectEmptyState() -> XCUIElement {
    test.expect(AccessibilityID.sentenceListEmptyState, "The set's empty state.")
  }
}
