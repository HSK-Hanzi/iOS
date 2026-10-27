//
//  EncodedGraphicTests.swift
//  ZiliTests
//

import Foundation
import Testing

@testable import Zili

/// Payloads written by `Tools/generate_db.py`'s `encoded_graphic`, so these pin the format both
/// sides share.
struct `Encoded stroke graphics` {
  /// 人 from the bundled stroke data: two strokes whose outlines use every path command the data
  /// does — `M`, `Q`, `L`, `C`, and `Z`.
  private static let person = """
    15cd1177c35018c6f1bcf7dee4bdbd376b02c3416030080c028542cf59a0b09eb3d7764a85406010280c0a8142a1102804068541211fa03028140a8542311f60300814028125e7a1bffc1ee618930fdc20ad65a0ceb2507493a5ba4a57d35e86fa41e69a0abcea144f9a06b8d721c69a328c64262e8266622b0291087ae311772107fa35129010013dc33bc49000d5ec898dc5985365e662801ebe768753db987441297e594dab51ac0a36d71ba04adb10d9f740c73b1feafe1068e18c20755a74e9aca0ea1f805cfbc4321d70faee1dc40ec7484b4cb0835f1ef1868db5c24e9ff68c35a6bac25a3598ab08b77266a59667fe88a1b8f011f399070b90468cf3763eeeb0b4fe64609e95c78f3a649f7609b113c33f
    """

  /// A one-stroke graphic with a negative, a half-unit, and a quarter-unit coordinate.
  private static let fractional = "636466f055f9c7c4e0f3879f83218a892192f3df7f0606160600"

  private static func data(hex: String) throws -> Data {
    var bytes = [UInt8]()
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      bytes.append(try #require(UInt8(hex[index..<next], radix: 16)))
      index = next
    }
    return Data(bytes)
  }

  @Test
  func `decodes outlines back to the source's SVG path strings, and medians to points`() throws {
    let graphic = try #require(HanziGraphic(encoded: try Self.data(hex: Self.person)))

    #expect(
      graphic.strokes == [
        "M 475 485 Q 547 653 563 683 Q 573 695 565 708 Q 558 721 519 742 Q 491 757 480 754 "
          + "Q 462 750 465 730 Q 484 537 292 308 Q 280 296 269 284 Q 212 217 68 102 Q 58 92 66 89 "
          + "Q 76 86 90 92 Q 190 138 274 210 Q 380 294 462 456 L 475 485 Z",
        "M 462 456 Q 480 423 575 292 Q 666 171 733 101 Q 764 67 793 69 Q 881 75 958 79 "
          + "Q 991 80 992 89 Q 993 98 956 112 Q 772 178 740 205 Q 617 304 490 466 Q 481 476 475 485 "
          + "C 457 509 447 482 462 456 Z"
      ]
    )
    #expect(graphic.medians.map(\.count) == [9, 8])
    #expect(graphic.medians[0].first == MedianPoint(x: 483, y: 736))
    #expect(graphic.medians[1].last == MedianPoint(x: 986, y: 90))
  }

  @Test
  func `keeps negative and fractional coordinates exact`() throws {
    let graphic = try #require(HanziGraphic(encoded: try Self.data(hex: Self.fractional)))

    #expect(graphic.strokes == ["M -119 0.5 L 1023 2 Z"])
    #expect(graphic.medians == [[MedianPoint(x: 598.25, y: -0.5), MedianPoint(x: 0, y: 1)]])
  }

  @Test
  func `rejects a payload that is cut short`() throws {
    let whole = try Self.data(hex: Self.person)
    #expect(HanziGraphic(encoded: whole.prefix(whole.count / 2)) == nil)
  }
}
