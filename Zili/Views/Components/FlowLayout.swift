//
//  FlowLayout.swift
//  Zili
//

import SwiftUI

/// A layout that arranges its subviews left to right, wrapping to a new line when the
/// next subview would overflow the available width — for chips, tags, and badges.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout Void) -> CGSize {
    arrange(subviews, within: proposal.replacingUnspecifiedDimensions().width).size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal _: ProposedViewSize,
    subviews: Subviews,
    cache _: inout Void
  ) {
    let origins = arrange(subviews, within: bounds.width).origins
    for (subview, origin) in zip(subviews, origins) {
      subview.place(
        at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
        proposal: .unspecified
      )
    }
  }

  private func arrange(_ subviews: Subviews, within maxWidth: CGFloat) -> (
    size: CGSize, origins: [CGPoint]
  ) {
    var origins: [CGPoint] = []
    var cursor = CGPoint.zero
    var rowHeight: CGFloat = 0
    var widestRow: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if cursor.x > 0, cursor.x + size.width > maxWidth {
        cursor = CGPoint(x: 0, y: cursor.y + rowHeight + spacing)
        rowHeight = 0
      }
      origins.append(cursor)
      cursor.x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      widestRow = max(widestRow, cursor.x - spacing)
    }
    return (CGSize(width: widestRow, height: cursor.y + rowHeight), origins)
  }
}
