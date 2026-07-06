//
//  HanziGeometry.swift
//  Zili
//

import CoreGraphics
import SwiftUI

/// Maps makemeahanzi's stroke data into a target rectangle in screen space.
///
/// The source glyphs live in a 1024×1024 grid whose y-axis points **up**; these helpers
/// flip that axis, scale to fit, and center the glyph, mirroring the transform documented
/// by makemeahanzi (`scale(1, -1) translate(0, -900)`).
enum HanziGeometry {
  /// Side length of the square grid the source coordinates occupy.
  static let gridSize: CGFloat = 1024
  /// Brush width, in grid units, wide enough to fill any single stroke when clipped to it.
  static let brushWidthInGrid: CGFloat = 256

  /// The square the source grid occupies, in its own units.
  ///
  /// Placing a stroke in this rect yields *matching space*: grid units, y-down. Scoring a
  /// hand-drawn stroke means bringing both it and its target here, so the tolerances that
  /// judge it are resolution-independent.
  static let gridRect = CGRect(origin: .zero, size: CGSize(width: gridSize, height: gridSize))

  /// The y-offset that flips makemeahanzi's upward axis into screen space.
  private static let flipOffset: CGFloat = 900

  /// Uniform scale that fits the grid into `rect`'s smaller dimension.
  nonisolated static func scale(in rect: CGRect) -> CGFloat {
    min(rect.width, rect.height) / gridSize
  }

  /// A filled stroke outline, positioned for `rect`.
  nonisolated static func strokePath(_ svgPath: String, in rect: CGRect) -> Path {
    SVGPath.path(from: svgPath).applying(transform(in: rect))
  }

  /// A stroke's centerline as an open polyline, positioned for `rect`.
  nonisolated static func medianPath(_ median: [MedianPoint], in rect: CGRect) -> Path {
    let placed = points(median, in: rect)
    var path = Path()
    guard let first = placed.first else { return path }
    path.move(to: first)
    for point in placed.dropFirst() {
      path.addLine(to: point)
    }
    return path
  }

  /// A stroke's centerline as points, positioned for `rect`.
  nonisolated static func points(_ median: [MedianPoint], in rect: CGRect) -> [CGPoint] {
    median.map { $0.cgPoint.applying(transform(in: rect)) }
  }

  /// Brings points drawn on a `rect`-sized canvas into matching space.
  nonisolated static func matchingPoints(fromCanvas points: [CGPoint], in rect: CGRect) -> [CGPoint]
  {
    let canvasToGrid = transform(in: rect).inverted().concatenating(transform(in: gridRect))
    return points.map { $0.applying(canvasToGrid) }
  }

  /// Flip, scale, and center the source grid onto `rect`.
  nonisolated private static func transform(in rect: CGRect) -> CGAffineTransform {
    let scale = scale(in: rect)
    let renderedSide = gridSize * scale
    let originX = rect.minX + (rect.width - renderedSide) / 2
    let originY = rect.minY + (rect.height - renderedSide) / 2
    return CGAffineTransform(
      a: scale,
      b: 0,
      c: 0,
      d: -scale,
      tx: originX,
      ty: originY + flipOffset * scale
    )
  }
}

/// A minimal SVG path parser covering the command set makemeahanzi emits: absolute
/// `M`, `L`, `Q`, `C`, and `Z`. Anything else is ignored.
enum SVGPath {
  nonisolated static func path(from string: String) -> Path {
    var path = Path()
    var scanner = Scanner(string)
    while let command = scanner.nextCommand() {
      switch command {
        case "M":
          if let point = scanner.nextPoint() {
            path.move(to: point)
          }
          while let point = scanner.nextPoint() {
            path.addLine(to: point)
          }
        case "L":
          while let point = scanner.nextPoint() {
            path.addLine(to: point)
          }
        case "Q":
          while let control = scanner.nextPoint(), let end = scanner.nextPoint() {
            path.addQuadCurve(to: end, control: control)
          }
        case "C":
          while let control1 = scanner.nextPoint(),
            let control2 = scanner.nextPoint(),
            let end = scanner.nextPoint()
          {
            path.addCurve(to: end, control1: control1, control2: control2)
          }
        case "Z":
          path.closeSubpath()
        default:
          break
      }
    }
    return path
  }

  /// Walks an SVG `d` string, yielding command letters and absolute coordinate pairs.
  private struct Scanner {
    private let scalars: [Unicode.Scalar]
    private var index = 0

    init(_ string: String) {
      scalars = Array(string.unicodeScalars)
    }

    mutating func nextCommand() -> Character? {
      skipSeparators()
      guard index < scalars.count, isLetter(scalars[index]) else { return nil }
      defer { index += 1 }
      return Character(scalars[index])
    }

    mutating func nextPoint() -> CGPoint? {
      let restore = index
      guard let x = nextNumber(), let y = nextNumber() else {
        index = restore
        return nil
      }
      return CGPoint(x: x, y: y)
    }

    private mutating func nextNumber() -> CGFloat? {
      skipSeparators()
      let start = index
      if index < scalars.count, scalars[index] == "-" || scalars[index] == "+" {
        index += 1
      }
      var sawDigit = false
      while index < scalars.count, isDigit(scalars[index]) {
        index += 1
        sawDigit = true
      }
      if index < scalars.count, scalars[index] == "." {
        index += 1
        while index < scalars.count, isDigit(scalars[index]) {
          index += 1
          sawDigit = true
        }
      }
      guard sawDigit else {
        index = start
        return nil
      }
      let text = String(String.UnicodeScalarView(scalars[start..<index]))
      return Double(text).map { CGFloat($0) }
    }

    private mutating func skipSeparators() {
      while index < scalars.count, isSeparator(scalars[index]) {
        index += 1
      }
    }

    private func isDigit(_ scalar: Unicode.Scalar) -> Bool { ("0"..."9").contains(scalar) }
    private func isLetter(_ scalar: Unicode.Scalar) -> Bool {
      ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }
    private func isSeparator(_ scalar: Unicode.Scalar) -> Bool {
      scalar == " " || scalar == "," || scalar == "\n" || scalar == "\t" || scalar == "\r"
    }
  }
}
