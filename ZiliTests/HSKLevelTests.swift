//
//  HSKLevelTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct HSKLevelTests {
  /// A tag is `"<standard>-<band>"`, so a known standard paired with an integer band parses.
  @Test(arguments: [
    (raw: "new-4", standard: HSKLevel.Standard.new, band: 4),
    (raw: "old-6", standard: .old, band: 6),
    (raw: "newest-1", standard: .newest, band: 1)
  ])
  func parsesWellFormedTags(_ example: (raw: String, standard: HSKLevel.Standard, band: Int)) {
    let level = HSKLevel(rawValue: example.raw)
    #expect(level?.standard == example.standard)
    #expect(level?.band == example.band)
  }

  /// Anything but exactly one known standard and one integer band, joined by a single hyphen,
  /// is rejected: no band, a non-integer band, an empty string, extra parts, or a bogus standard.
  @Test(arguments: ["new", "new-x", "", "a-b-c", "bogus-3"])
  func rejectsMalformedTags(_ raw: String) {
    #expect(HSKLevel(rawValue: raw) == nil)
  }

  /// Levels sort by standard first — newest before new before old — then by ascending band.
  @Test
  func sortsByStandardThenBand() {
    let unsorted = [
      HSKLevel(standard: .old, band: 1),
      HSKLevel(standard: .new, band: 2),
      HSKLevel(standard: .newest, band: 3),
      HSKLevel(standard: .new, band: 1),
      HSKLevel(standard: .newest, band: 1)
    ]

    #expect(
      unsorted.sorted() == [
        HSKLevel(standard: .newest, band: 1),
        HSKLevel(standard: .newest, band: 3),
        HSKLevel(standard: .new, band: 1),
        HSKLevel(standard: .new, band: 2),
        HSKLevel(standard: .old, band: 1)
      ]
    )
  }

  /// The standards themselves order by declaration: newest is earliest, old is latest.
  @Test
  func standardOrdersByDeclaration() {
    #expect(HSKLevel.Standard.newest < .new)
    #expect(HSKLevel.Standard.new < .old)
  }
}
