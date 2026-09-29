//
//  VoiceDownloadPromptUITests.swift
//  ZiliUITests
//

// The UI test target links XCTest, not Swift Testing, so XCTest's own assertions are all that's
// available here.
// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// The launch prompt to download a better Mandarin voice: declining keeps it away for good,
/// postponing brings it back next launch, and accepting leads to the steps and to Settings.
final class VoiceDownloadPromptUITests: ZiliUITestCase {
  #if os(macOS)
    private static let settingsBundleID = "com.apple.systempreferences"
  #else
    private static let settingsBundleID = "com.apple.Preferences"
  #endif

  private var voicePrompt: VoiceDownloadPage { VoiceDownloadPage(test: self) }

  private var settings: XCUIApplication { XCUIApplication(bundleIdentifier: Self.settingsBundleID) }

  override func tearDownWithError() throws {
    settings.terminate()
    try super.tearDownWithError()
  }

  func testDecliningKeepsThePromptAway() async throws {
    launch(voicePrompt: .fresh)
    voicePrompt.expectPrompt()
    await voicePrompt.decline()

    launch(voicePrompt: .remembered)
    voicePrompt.expectNoPrompt("A declined prompt doesn't return on the next launch.")
  }

  func testPostponingBringsThePromptBackNextLaunch() async throws {
    launch(voicePrompt: .fresh)
    voicePrompt.expectPrompt()
    await voicePrompt.postpone()

    launch(voicePrompt: .remembered)
    voicePrompt.expectPrompt("A postponed prompt returns on the next launch.")
  }

  func testAcceptingLeadsToTheGuideAndSettings() async throws {
    launch(voicePrompt: .fresh)
    await voicePrompt.accept()

    #if os(macOS)
      // Settings opens straight away, with the guide in a window beside it.
      XCTAssertTrue(
        settings.wait(for: .runningForeground, timeout: ScaledTimeouts.element),
        "System Settings opens at Read & Speak."
      )
      voicePrompt.expectGuide("The guide opens in its own window beside Settings.")
    #else
      // Settings would cover the app, so the guide comes first, and opens Settings itself.
      voicePrompt.expectGuide("The guide sheet opens before Settings.")
      XCTAssertNotEqual(settings.state, .runningForeground, "Settings waits for the guide.")
      await voicePrompt.openSettingsFromGuide()
      XCTAssertTrue(
        settings.wait(for: .runningForeground, timeout: ScaledTimeouts.element),
        "The guide opens Settings."
      )
      app.activate()
      voicePrompt.expectGuide("The guide is still there on returning from Settings.")
    #endif
  }
}

// swiftlint:enable prefer_nimble
