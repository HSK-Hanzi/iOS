//
//  SettingsUITests.swift
//  ZiliUITests
//

// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// Driving Settings: clearing the missed tallies through the confirm-first dialog (which leaves the
/// reset disabled once there's nothing left to clear), and confirming the display pickers are present.
final class SettingsUITests: ZiliUITestCase {
  @MainActor
  func testResetAllMissedClearsAndDisables() async throws {
    launch(seed: [.misses])
    goToSettings()

    // With misses seeded, the reset is offered; tapping it raises the confirm-first dialog.
    let reset = expect(AccessibilityID.settingsResetMissed, "The reset control.")
    XCTAssertTrue(reset.isEnabled, "Reset All Missed is enabled while misses exist.")

    await tap(AccessibilityID.settingsResetMissed, "Reset All Missed.")
    confirmResetAllMissed()

    // Once the tallies are gone there's nothing to clear, so the reset disables itself.
    XCTAssertTrue(
      reset.waitFor(NSPredicate(format: "isEnabled == false")),
      "Reset All Missed disables once the missed tallies are cleared."
    )
    XCTAssertFalse(reset.isEnabled, "Reset All Missed is disabled with no misses left.")
  }

  @MainActor
  func testDisplayPickersArePresent() throws {
    launch()
    goToSettings()

    expect(AccessibilityID.settingsScriptPicker, "The character-set picker.")
    expect(AccessibilityID.settingsRomanizationPicker, "The romanization picker.")
  }

  /// Taps the destructive confirm in the "Reset all missed…" dialog. The dialog surfaces differently
  /// per platform: on iOS a `confirmationDialog` is an action sheet, so its button lives under
  /// `app.sheets`; on macOS it presents inline, where the confirm shares the trigger's "Reset All
  /// Missed" label, so we take the last match of that label — the newly presented dialog button.
  @MainActor
  private func confirmResetAllMissed() {
    #if os(macOS)
      let confirmations = app.buttons.matching(identifier: "Reset All Missed")
      XCTAssertTrue(confirmations.firstMatch.wait(), "The confirmation dialog's confirm button.")
      let confirm = confirmations.element(boundBy: confirmations.count - 1)
    #else
      let confirm = app.sheets.buttons["Reset All Missed"]
      XCTAssertTrue(confirm.wait(), "The confirmation dialog's confirm button.")
    #endif
    confirm.forceTap()
  }
}

// swiftlint:enable prefer_nimble
