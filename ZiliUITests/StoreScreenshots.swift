//
//  StoreScreenshots.swift
//  ZiliUITests
//

#if os(iOS)
  import XCTest
  import XCUIPromoKit
  import XCUITestKit

  /// Captures the stills `promo/storyboard.json` sets as App Store screenshots and cuts the
  /// creative assets from. `promokit stills` runs it; anywhere else, the test skips.
  final class StoreScreenshots: StoreScreenshotTour {
    /// The character the creative assets show written and looked up.
    private static let creativeCharacter = "zili://word/%E5%85%B6"

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
      try await captureCreativeStills()
    }

    /// 其's dictionary entry, and 其 written with every stroke graded correct.
    private func captureCreativeStills() async throws {
      try follow(link: Self.creativeCharacter)
      WordEntryPage(test: self).expectVisible()
      try PromoStill.capture("entry", in: self)

      let pad = await StrokePracticePage.open(fromEntryIn: self)
      pad.draw(StrokePracticePage.Stroke.qi)
      pad.expectCorrectStrokes(StrokePracticePage.Stroke.qi.count)
      try PromoStill.capture("pad", in: self)
    }
  }
#endif
