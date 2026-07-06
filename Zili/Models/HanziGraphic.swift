//
//  HanziGraphic.swift
//  Zili
//

import CoreGraphics
import Foundation

/// The vector geometry needed to draw a single Hanzi character stroke by stroke.
///
/// Sourced from the `makemeahanzi` project. Each stroke is an SVG path (its filled
/// outline) paired by index with a ``median`` — the centerline a brush travels along
/// when the stroke is written.
struct HanziGraphic: Decodable, Hashable, Sendable {
  /// Filled outlines, one per stroke, ordered by the sequence in which they are written.
  ///
  /// Each element is an SVG path `d` string in the makemeahanzi coordinate space.
  let strokes: [String]

  /// Stroke centerlines, index-aligned with ``strokes``.
  let medians: [[MedianPoint]]

  init(strokes: [String], medians: [[MedianPoint]]) {
    (self.strokes, self.medians) = (strokes, medians)
  }

  /// Builds a graphic from a raw property-list value, skipping the `Decodable`
  /// machinery so a whole library can be materialized quickly.
  init?(propertyList: Any) {
    guard let entry = propertyList as? [String: Any],
      let strokes = entry["strokes"] as? [String],
      let medians = entry["medians"] as? [[[NSNumber]]]
    else { return nil }
    self.strokes = strokes
    self.medians = medians.map { stroke in
      stroke.compactMap(MedianPoint.init(pair:))
    }
  }
}

/// A single point on a stroke's centerline, in the makemeahanzi grid.
struct MedianPoint: Decodable, Hashable, Sendable {
  let x: CGFloat
  let y: CGFloat

  var cgPoint: CGPoint { CGPoint(x: x, y: y) }

  init(x: CGFloat, y: CGFloat) {
    (self.x, self.y) = (x, y)
  }

  /// Interprets makemeahanzi's `[x, y]` pair; fails unless it holds exactly two numbers.
  init?(pair: [NSNumber]) {
    guard pair.count == 2 else { return nil }
    self.init(x: CGFloat(truncating: pair[0]), y: CGFloat(truncating: pair[1]))
  }

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    x = try container.decode(CGFloat.self)
    y = try container.decode(CGFloat.self)
  }
}
