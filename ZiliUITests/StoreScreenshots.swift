//
//  StoreScreenshots.swift
//  ZiliUITests
//

#if os(iOS)
  import XCTest
  import XCUIPromoKit
  import XCUITestKit

  /// Captures the stills `promo/storyboard.json` sets as App Store screenshots. `promokit stills`
  /// runs it; anywhere else, the test skips.
  final class StoreScreenshots: StoreScreenshotTour {
    override func setUpWithError() throws {
      try super.setUpWithError()
      try XCTSkipUnless(
        ProcessInfo.processInfo.environment[PromoStill.directoryVariable] != nil,
        "Only `promokit stills` captures the App Store stills."
      )
    }

    override func prepareForLaunch() {
      app.launchArguments += PromoLaunch().arguments
    }

    override func capture(_ shot: Shot) async throws {
      try PromoStill.capture(shot.rawValue, in: self)
    }

    func testCaptureStills() async throws {
      try await takeTour()
    }
  }
#endif
