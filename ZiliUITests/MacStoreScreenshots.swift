//
//  MacStoreScreenshots.swift
//  ZiliUITests
//

// swiftlint:disable prefer_nimble

#if os(macOS)
  import XCTest
  import XCUIPromoKit
  import XCUITestKit

  /// Drives the Mac app through the Mac App Store screenshots and attaches each window capture to
  /// the result bundle. `promokit mac-stills` exports them, and `promokit render` sets them on
  /// 16:10 canvases; anywhere else, the test skips.
  final class MacStoreScreenshots: StoreScreenshotTour {
    /// The app whose windows are captured.
    private static let bundleIdentifier = "codes.tim.Zili"

    /// Draws light whatever the Mac is set to, matching the stills taken in the simulators.
    private static let lightAppearance: [String: DefaultsValue] = [
      "NSRequiresAquaSystemAppearance": true
    ]

    override func setUpWithError() throws {
      try super.setUpWithError()
      try XCTSkipUnless(
        ProcessInfo.processInfo.environment[PromoLaunch.localeVariable] != nil,
        "Only `promokit mac-stills` captures the Mac App Store stills."
      )
    }

    override func tearDown() async throws {
      await app?.terminate()
    }

    override func prepareForLaunch() {
      app.launchArguments += PromoLaunch(defaults: Self.lightAppearance).arguments
    }

    func testCaptureStills() async throws {
      try await takeTour()
    }

    /// Attaches the window `shot` is taken of.
    ///
    /// A window's screenshot is whatever the screen shows inside its frame, so another app's window
    /// over it would be photographed in its place. Zili is brought to the front first, and nothing
    /// is captured unless it is the foreground app and the window takes hits.
    override func capture(_ shot: Shot) async throws {
      let window = window(of: shot.macScene)
      app.activate()
      XCTAssertTrue(
        app.wait(for: .runningForeground, timeout: ScaledTimeouts.element)
          && window.wait() && window.isHittable,
        "The \(shot.macScene) window is in front, so its capture shows nothing but Zili."
      )
      try await PromoStill.capture(
        shot.rawValue,
        of: window,
        ownedBy: Self.bundleIdentifier,
        in: self
      )
    }
  }
#endif

// swiftlint:enable prefer_nimble
