//
//  HSKPaletteTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct HSKPaletteTests {
  /// Scoped to a standard the word belongs to, the color comes from its band *within that
  /// standard* — not its lowest band across the syllabus.
  @Test
  func bandInMatchingStandardIgnoresOtherStandards() {
    let levels = [
      HSKLevel(standard: .old, band: 1),
      HSKLevel(standard: .new, band: 6)
    ]

    #expect(HSKPalette.band(of: levels, inStandard: .new) == 6)
  }

  /// Off a standard (`nil`) the word keeps one identity color: its lowest band anywhere.
  @Test
  func bandWithNoStandardTakesTheMinimumBand() {
    let levels = [
      HSKLevel(standard: .old, band: 5),
      HSKLevel(standard: .new, band: 2),
      HSKLevel(standard: .newest, band: 4)
    ]

    #expect(HSKPalette.band(of: levels, inStandard: nil) == 2)
  }

  /// A standard the word doesn't belong to has no band, so it falls back to the lowest band.
  @Test
  func bandFallsBackToMinimumWhenStandardHasNoMatch() {
    let levels = [
      HSKLevel(standard: .old, band: 3),
      HSKLevel(standard: .new, band: 7)
    ]

    #expect(HSKPalette.band(of: levels, inStandard: .newest) == 3)
  }

  /// A word outside the syllabus has no band, whether or not a standard is asked for.
  @Test(arguments: [nil, HSKLevel.Standard.new])
  func bandOfEmptyLevelsIsNil(_ standard: HSKLevel.Standard?) {
    #expect(HSKPalette.band(of: [HSKLevel](), inStandard: standard) == nil)
  }

  /// A missing or sub-one band wears the neutral gray, which also suppresses a colored title.
  @Test(arguments: [nil, 0, -1, -10])
  func paletteIsNeutralForMissingOrNonPositiveBands(_ band: Int?) {
    #expect(HSKPalette.palette(forBand: band).isNeutral)
  }

  /// Each of the ten bands gets a real color, not the neutral fallback.
  @Test(arguments: 1...10)
  func paletteIsColoredForValidBands(_ band: Int) {
    #expect(!HSKPalette.palette(forBand: band).isNeutral)
  }

  /// Bands beyond the tenth wrap rather than crash, so an unexpected value still gets a color.
  @Test(arguments: [11, 20, 21, 100])
  func paletteWrapsBandsBeyondTheTenth(_ band: Int) {
    #expect(!HSKPalette.palette(forBand: band).isNeutral)
  }
}
