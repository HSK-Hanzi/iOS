//
//  VoiceDownloadPage.swift
//  ZiliUITests
//

// The prompt is a system alert whose buttons carry no identifiers, so this page resolves them by
// hand and asserts with XCTest directly; the project has no Nimble dependency.
// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// The launch prompt to download a better Mandarin voice, and the guide it leads to.
///
/// The prompt is a system alert, whose buttons carry no accessibility identifiers of their own, so
/// they are the one place a page matches on a rendered label.
struct VoiceDownloadPage: Page {
  /// How long to watch for a prompt that shouldn't appear. The prompt is presented as the first
  /// window appears, so one that hasn't shown by then isn't coming.
  private static let absenceSeconds: TimeInterval = 3

  let test: ZiliUITestCase

  /// The alert's accepting button, named for what it does on each platform.
  private var acceptButton: XCUIElement {
    #if os(macOS)
      alertButton("Open Settings")
    #else
      alertButton("Download Premium Voice")
    #endif
  }

  /// Asserts the prompt is showing.
  func expectPrompt(_ message: String = "The voice-download prompt.") {
    XCTAssertTrue(acceptButton.wait(), message)
  }

  /// Asserts the prompt stays away.
  func expectNoPrompt(_ message: String) {
    XCTAssertFalse(acceptButton.wait(scaledSeconds: Self.absenceSeconds), message)
  }

  /// Accepts the prompt: on the Mac this opens System Settings and the guide window; elsewhere the
  /// guide sheet alone.
  func accept() async {
    await tapWhenSettled(acceptButton)
  }

  /// Answers "Remind Me Later".
  func postpone() async {
    await tapWhenSettled(alertButton("Remind Me Later"))
  }

  /// Answers "Don't Remind Me".
  func decline() async {
    await tapWhenSettled(alertButton("Don’t Remind Me"))
  }

  /// Asserts the guide is showing, by its Open Settings button.
  @discardableResult
  func expectGuide(_ message: String = "The voice-download guide.") -> XCUIElement {
    test.expect(AccessibilityID.voiceGuideOpenSettings, message)
  }

  /// Taps the guide's Open Settings button.
  func openSettingsFromGuide() async {
    await test.tap(AccessibilityID.voiceGuideOpenSettings, "The guide's Open Settings button.")
  }

  /// A button of the prompt, looked up within the alert: the Mac shows an alert as a sheet on its
  /// window, and an app-wide query there also matches an offscreen copy with no frame to tap.
  private func alertButton(_ label: String) -> XCUIElement {
    #if os(macOS)
      test.app.sheets.buttons[label].firstMatch
    #else
      test.app.alerts.buttons[label].firstMatch
    #endif
  }

  private func tapWhenSettled(_ button: XCUIElement) async {
    XCTAssertTrue(button.wait(), "The prompt's button to tap.")
    await test.tapWhenSettled(button)
  }
}

// swiftlint:enable prefer_nimble
