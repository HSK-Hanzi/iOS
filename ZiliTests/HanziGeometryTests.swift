//
//  HanziGeometryTests.swift
//  ZiliTests
//

import CoreGraphics
import SwiftUI
import Testing

@testable import Zili

struct SVGPathTests {
  @Test("A closed polygon parses to a path spanning its points")
  func closedPolygon() {
    let path = SVGPath.path(from: "M0 0 L10 0 L10 10 L0 10 Z")
    #expect(!path.isEmpty)
    #expect(path.boundingRect == CGRect(x: 0, y: 0, width: 10, height: 10))
  }

  /// Separators are noise: commas, runs of spaces, newlines, and leading or back-to-back
  /// delimiters all resolve to the same move-then-line, so every spelling below is equal.
  @Test(arguments: [
    "M0 0L10 10",
    "M0,0 L10,10",
    "M 0 0\nL 10 10",
    "  M0 0  L10 10  ",
    "M,0,,0,L,10,,10"
  ])
  func separatorsAreInterchangeable(_ svg: String) {
    var expected = Path()
    expected.move(to: .zero)
    expected.addLine(to: CGPoint(x: 10, y: 10))
    #expect(SVGPath.path(from: svg) == expected)
  }

  @Test("Signed and decimal coordinates parse")
  func signedAndDecimalCoordinates() {
    let path = SVGPath.path(from: "M-1.5,2 L3 4")
    #expect(path.boundingRect == CGRect(x: -1.5, y: 2, width: 4.5, height: 2))
  }

  @Test("An unrecognized command is skipped while the known ones still parse")
  func unknownCommandsAreIgnored() {
    let path = SVGPath.path(from: "M0 0 L10 10 W5 5")
    #expect(path.boundingRect == CGRect(x: 0, y: 0, width: 10, height: 10))
  }

  @Test("Quadratic and cubic curves parse to a non-empty path")
  func curvesParse() {
    #expect(!SVGPath.path(from: "M0 0 Q5 10 10 0").isEmpty)
    #expect(!SVGPath.path(from: "M0 0 C0 10 10 10 10 0").isEmpty)
  }

  @Test(arguments: ["", "   ", "hello world"])
  func emptyOrGarbageYieldsAnEmptyPath(_ svg: String) {
    #expect(SVGPath.path(from: svg).isEmpty)
  }
}

struct HanziGeometryTests {
  /// The glyph fits the rect's smaller side, so wide or tall rects scale by their short dimension.
  @Test(arguments: [
    (rect: CGRect(x: 0, y: 0, width: 512, height: 512), scale: CGFloat(0.5)),
    (rect: CGRect(x: 0, y: 0, width: 1024, height: 1024), scale: CGFloat(1)),
    (rect: CGRect(x: 0, y: 0, width: 2048, height: 512), scale: CGFloat(0.5))
  ])
  func scaleFitsTheShorterSide(_ example: (rect: CGRect, scale: CGFloat)) {
    #expect(HanziGeometry.scale(in: example.rect) == example.scale)
  }

  /// Placing median points flips the y-axis, halves the grid onto a 512 rect, and centers it:
  /// grid (x, y) lands at (x/2, 450 − y/2).
  @Test("Median points map onto a rect with the documented flip and scale")
  func pointsMapWithFlipAndScale() {
    let rect = CGRect(x: 0, y: 0, width: 512, height: 512)
    let placed = HanziGeometry.points(
      [MedianPoint(x: 0, y: 0), MedianPoint(x: 512, y: 900), MedianPoint(x: 1024, y: 1024)],
      in: rect
    )
    #expect(
      placed == [
        CGPoint(x: 0, y: 450),
        CGPoint(x: 256, y: 0),
        CGPoint(x: 512, y: -62)
      ]
    )
  }

  /// A point placed on a canvas returns to matching space regardless of the canvas size, so the
  /// same grid point yields the same matching coordinate whether drawn at 512 or 1024.
  @Test("A canvas point round-trips into resolution-independent matching space")
  func matchingPointsRoundTrip() {
    let grid = MedianPoint(x: 400, y: 300)
    let matched = CGPoint(x: 400, y: 600)

    for side in [CGFloat(512), CGFloat(1024)] {
      let rect = CGRect(x: 0, y: 0, width: side, height: side)
      let canvas = HanziGeometry.points([grid], in: rect)
      #expect(HanziGeometry.matchingPoints(fromCanvas: canvas, in: rect) == [matched])
    }
  }
}
