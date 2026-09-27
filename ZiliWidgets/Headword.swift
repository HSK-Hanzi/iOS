//
//  Headword.swift
//  ZiliWidgets
//

import SwiftUI

/// A word as a widget shows it: the characters at the size the family allows, and the reading
/// beneath them when there is room for one.
struct Headword: View {
  /// How far the characters may shrink before the line truncates instead — a compound has twice
  /// the glyphs of a single character in the same width.
  private static let minimumScale = 0.4

  let display: String
  let reading: String?

  /// Set in `init`, so the family picks the base size and Dynamic Type scales from there.
  @ScaledMetric private var size: CGFloat

  var body: some View {
    VStack(alignment: .leading) {
      Text(display)
        .font(.system(size: size, weight: .medium))
        .lineLimit(1)
        .minimumScaleFactor(Self.minimumScale)
      if let reading, !reading.isEmpty {
        Text(reading)
          .font(.title3)
          .foregroundStyle(.secondary)
      }
    }
  }

  init(_ display: String, reading: String? = nil, size: CGFloat) {
    self.display = display
    self.reading = reading
    _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
  }
}
