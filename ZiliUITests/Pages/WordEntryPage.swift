//
//  WordEntryPage.swift
//  ZiliUITests
//

// This page asserts by hand that a word's examples appear, so it asserts with XCTest directly; the
// project has no Nimble dependency.
// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// A word's full entry, reached from a dictionary result or a practice word cell. Exposes the
/// favorite toggle and the example sentences, and asserts the entry is on screen.
struct WordEntryPage: Page {
  #if os(macOS)
    /// How far one scroll of the entry moves it.
    private static let scrollStep: CGFloat = 400
  #endif

  #if !os(iOS)
    /// How many scrolls of the entry it takes at most to reach an example.
    private static let scrollLimit = 10
  #endif

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

  /// Scrolls down to the word's example sentences, opens the first, and waits for its detail.
  ///
  /// visionOS swipes the entry itself: it refuses a gesture addressed to the app as a whole, as
  /// there is no one scene to deliver it to, so XCUITestKit's app-wide scrolling cannot run there.
  @discardableResult
  func openFirstExample() async -> XCUIElement {
    let example = test.app.descendants(matching: .any)
      .matching(identifier: AccessibilityID.sentenceRow).firstMatch
    XCTAssertTrue(example.wait(), "The word's example sentences.")
    #if os(iOS)
      test.app.scrollToElement(example)
    #else
      let entry = test.app.scrollViews
        .containing(.any, identifier: AccessibilityID.sentenceRow).firstMatch
      for _ in 0..<Self.scrollLimit where !example.isHittable {
        #if os(macOS)
          entry.scroll(byDeltaX: 0, deltaY: -Self.scrollStep)
        #else
          entry.swipeUp()
        #endif
      }
    #endif
    await test.tapWhenSettled(example)
    return test.expect(AccessibilityID.sentenceDetail, "The example's detail.")
  }
}

// swiftlint:enable prefer_nimble
