//
//  FavoritesUITests.swift
//  ZiliUITests
//

// The UI test target links XCTest, not Swift Testing, so XCTest's own assertions are all that's
// available here.
// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// The favorites set in Practice Characters: seeded favorites show as word cells, Clear All empties
/// the set through its confirm-first dialog, and an unseeded run lands straight on the empty state.
final class FavoritesUITests: ZiliUITestCase {
  @MainActor
  func testSeededFavoritesAppearThenClear() async throws {
    launch(seed: [.favorites])
    await goToPracticeCharacters()

    await tap(AccessibilityID.characterSetFavorites, "The Favorites set.")
    expect(AccessibilityID.characterWordCell, "The seeded favorites show as word cells.")

    await tap(AccessibilityID.characterSetClearAll, "Clear All raises the confirm dialog.")
    confirmClearAll()

    expect(AccessibilityID.characterSetEmptyState, "Clearing empties the favorites set.")
  }

  @MainActor
  func testFavoritesAreEmptyWithoutSeed() async throws {
    launch()
    await goToPracticeCharacters()

    await tap(AccessibilityID.characterSetFavorites, "The Favorites set.")

    expect(AccessibilityID.characterSetEmptyState, "An unseeded run has no favorites.")
  }

  /// Taps the "Clear All" button inside the confirmation dialog. The dialog's confirm button carries
  /// no identifier and shares its "Clear All" label with the toolbar button that raised it, so it's
  /// resolved by label while excluding that toolbar button by its identifier.
  @MainActor
  private func confirmClearAll() {
    let confirm = app.buttons
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
}

// swiftlint:enable prefer_nimble
