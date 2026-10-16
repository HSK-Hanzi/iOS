//
//  PracticeSentencesPage.swift
//  ZiliUITests
//

// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// Practice Sentences: the corpus level grid and the built-in Favorites and Missed sets. Drilling a
/// level lists its sentence rows, and a row opens that sentence's detail; an empty set drills into
/// its empty state.
struct PracticeSentencesPage: Page {
  #if os(macOS)
    /// How long the pointer rests on a word before its peek is drawn and settled.
    private static let peekDelay: TimeInterval = 1
  #endif

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

  /// Taps `word` in the open sentence and waits for its peek, with its reading and meaning.
  func lookUp(_ word: String) async {
    await test.tapWhenSettled(wordInSentence(word))
    test.expect(AccessibilityID.wordPeekOpenEntry, "The peek of \(word).")
  }

  #if os(macOS)
    /// Rests the pointer on `word` in the open sentence until its peek shows the reading and
    /// meaning. Unlike the tapped peek, a popover in a window of its own, this one is drawn inside
    /// the sentence's window.
    func peek(_ word: String) {
      wordInSentence(word).hover()
      Thread.sleep(forTimeInterval: Self.peekDelay)
    }
  #endif

  /// `word` in the open sentence, matched by its exact label app-wide rather than under the detail
  /// view: on macOS a peek rebuilds that subtree as the pointer moves in, and a sentence row
  /// elsewhere is labeled with the whole sentence, never with one word of it.
  private func wordInSentence(_ word: String) -> XCUIElement {
    let element = test.app.descendants(matching: .any)[word].firstMatch
    XCTAssertTrue(element.wait(), "\(word) in the sentence.")
    return element
  }

  /// Asserts the level's sentence list appeared.
  @discardableResult
  func expectSentenceList() -> XCUIElement {
    test.expect(AccessibilityID.sentenceRow, "The level's sentence list.")
  }

  /// Switches VoiceOver on for the rest of the test and walks it forward `stops` times from
  /// wherever it lands, returning what it says at each stop.
  func utterancesWalkingForward(stops: Int) throws -> [String] {
    try VoiceOverSession(test).walk(stops: stops)
  }

  /// Asserts the set's empty state.
  @discardableResult
  func expectEmptyState() -> XCUIElement {
    test.expect(AccessibilityID.sentenceListEmptyState, "The set's empty state.")
  }
}

// swiftlint:enable prefer_nimble
