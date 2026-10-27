//
//  HanziGraphic+Encoded.swift
//  Zili
//

import CoreGraphics
import Compression
import Foundation

extension HanziGraphic {
  /// Decodes the compact form `Tools/generate_db.py` stores each graphic in: raw-DEFLATE
  /// compressed, little-endian, with coordinates as `Int16` quarter units —
  ///
  /// - `UInt8` stroke count *n*;
  /// - *n* outlines, each a `UInt16` command count then, per command, its ASCII SVG path letter and
  ///   that command's coordinates;
  /// - *n* medians, each a `UInt16` point count then, per point, its x and y.
  ///
  /// The outlines come back as the SVG path strings the source data spells them as. Fails on data
  /// that doesn't decompress or runs out before the graphic ends.
  init?(encoded: Data) {
    guard let bytes = try? Self.inflate(encoded) else { return nil }
    var reader = EncodedGraphicReader(bytes: bytes)
    guard let strokeCount = reader.byte(),
      let strokes = reader.outlines(count: Int(strokeCount)),
      let medians = reader.medians(count: Int(strokeCount))
    else { return nil }
    self.init(strokes: strokes, medians: medians)
  }

  private static func inflate(_ data: Data) throws -> Data {
    var output = Data()
    let filter = try OutputFilter(.decompress, using: .zlib) { output.append($0 ?? Data()) }
    try filter.write(data)
    try filter.finalize()
    return output
  }
}

/// Reads an encoded graphic's fields in order, returning `nil` once the data runs out.
private struct EncodedGraphicReader {
  /// How many coordinates follow each SVG path command.
  private static let arity: [UInt8: Int] = [
    UInt8(ascii: "M"): 2, UInt8(ascii: "L"): 2, UInt8(ascii: "Q"): 4, UInt8(ascii: "C"): 6,
    UInt8(ascii: "Z"): 0
  ]
  /// Coordinates are stored in quarter units.
  private static let coordinateScale = 4

  let bytes: Data
  private var offset = 0

  init(bytes: Data) {
    self.bytes = bytes
  }

  /// A coordinate as the source data writes it: a whole number bare, a fraction in decimal.
  private static func text(_ quarterUnits: Int16) -> String {
    let value = Int(quarterUnits)
    return value.isMultiple(of: coordinateScale)
      ? String(value / coordinateScale)
      : String(Double(value) / Double(coordinateScale))
  }

  mutating func byte() -> UInt8? {
    guard offset < bytes.count else { return nil }
    defer { offset += 1 }
    return bytes[bytes.startIndex + offset]
  }

  mutating func outlines(count: Int) -> [String]? {
    var outlines = [String]()
    for _ in 0..<count {
      guard let outline = outline() else { return nil }
      outlines.append(outline)
    }
    return outlines
  }

  mutating func medians(count: Int) -> [[MedianPoint]]? {
    var medians = [[MedianPoint]]()
    for _ in 0..<count {
      guard let pointCount = unsigned16() else { return nil }
      var points = [MedianPoint]()
      for _ in 0..<pointCount {
        guard let x = signed16(), let y = signed16() else { return nil }
        points.append(
          MedianPoint(
            x: CGFloat(x) / CGFloat(Self.coordinateScale),
            y: CGFloat(y) / CGFloat(Self.coordinateScale)
          )
        )
      }
      medians.append(points)
    }
    return medians
  }

  private mutating func outline() -> String? {
    guard let commandCount = unsigned16() else { return nil }
    var tokens = [String]()
    for _ in 0..<commandCount {
      guard let letter = byte(), let arity = Self.arity[letter] else { return nil }
      tokens.append(String(UnicodeScalar(letter)))
      for _ in 0..<arity {
        guard let coordinate = signed16() else { return nil }
        tokens.append(Self.text(coordinate))
      }
    }
    return tokens.joined(separator: " ")
  }

  private mutating func unsigned16() -> UInt16? {
    guard let low = byte(), let high = byte() else { return nil }
    return UInt16(low) | UInt16(high) << 8
  }

  private mutating func signed16() -> Int16? {
    unsigned16().map { Int16(bitPattern: $0) }
  }
}
