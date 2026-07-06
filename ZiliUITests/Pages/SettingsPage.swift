//
//  SettingsPage.swift
//  ZiliUITests
//

// This page resolves the platform-specific, unidentified reset-dialog confirm by hand, so it
// asserts with XCTest directly; the project has no Nimble dependency.
// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// Settings: the display pickers (character set, romanization), the "Reset All Missed" control with
/// its confirm-first dialog, and the link out to About.
@MainActor
struct SettingsPage: Page {
  let test: ZiliUITestCase

  /// The character-set (script) picker.
  var scriptPicker: XCUIElement { el(AccessibilityID.settingsScriptPicker) }

  /// The romanization picker.
  var romanizationPicker: XCUIElement { el(AccessibilityID.settingsRomanizationPicker) }

  /// The "Reset All Missed" control, disabled once nothing is left to clear.
  var resetMissed: XCUIElement { el(AccessibilityID.settingsResetMissed) }

  /// Reaches Settings (its tab on iOS, its window via ⌘, on macOS) and waits for it.
  @discardableResult
  static func open(_ test: ZiliUITestCase) -> Self {
    test.goToSettings()
    return Self(test: test)
  }

  /// Asserts both display pickers are present.
  func expectDisplayPickers() {
    test.expect(AccessibilityID.settingsScriptPicker, "The character-set picker.")
    test.expect(AccessibilityID.settingsRomanizationPicker, "The romanization picker.")
  }

  /// Taps "Reset All Missed", raising its confirmation dialog.
  func tapResetMissed() async {
    await test.tap(AccessibilityID.settingsResetMissed, "Reset All Missed.")
  }

  /// Confirms the "Reset all missed…" dialog. It surfaces differently per platform: on iOS a
  /// `confirmationDialog` is an action sheet, so its button lives under `app.sheets`; on macOS it
  /// presents inline, where the confirm shares the trigger's "Reset All Missed" label, so the last
  /// match of that label — the newly presented dialog button — is taken.
  func confirmResetMissed() {
    #if os(macOS)
      let confirmations = test.app.buttons.matching(identifier: "Reset All Missed")
      XCTAssertTrue(confirmations.firstMatch.wait(), "The confirmation dialog's confirm button.")
      let confirm = confirmations.element(boundBy: confirmations.count - 1)
    #else
      let confirm = test.app.sheets.buttons["Reset All Missed"]
      XCTAssertTrue(confirm.wait(), "The confirmation dialog's confirm button.")
    #endif
    confirm.forceTap()
  }

  /// Opens the About screen. About carries no accessibility identifiers of its own, so this only
  /// taps the link; callers assert on About's rendered content directly.
  func openAbout() async {
    await test.tap(AccessibilityID.settingsAbout, "The About link.")
  }
}

// swiftlint:enable prefer_nimble
