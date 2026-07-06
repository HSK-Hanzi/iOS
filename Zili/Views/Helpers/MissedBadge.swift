//
//  MissedBadge.swift
//  Zili
//

import SwiftUI

/// An item's total quiz misses shown inline beside its title: a red pill of the count with a Reset
/// control tucked inside it. The Reset shows only its icon until a pointer hovers it (on macOS or
/// iPadOS), when the pill grows to reveal its label. The caller places it only when there are misses
/// to report.
struct MissedBadge: View {
  let count: Int
  let reset: () -> Void

  @State private var isHoveringReset = false

  var body: some View {
    HStack {
      Text("Missed \(count, format: .number)×")
      Image(systemName: "circle.fill")
        .font(.system(size: 3))
        .accessibilityHidden(true)
      Button(action: reset) {
        HStack(spacing: 2) {
          Image(systemName: "arrow.counterclockwise")
          if isHoveringReset {
            Text("Reset")
              .fontWeight(.light)
          }
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .onHover { isHoveringReset = $0 }
      .accessibilityLabel(Text("Reset misses"))
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.white)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(.red, in: .capsule)
    .animation(.snappy(duration: 0.15), value: isHoveringReset)
  }
}

#Preview("Beside a title") {
  HStack {
    Text("好").font(.largeTitle)
    MissedBadge(count: 3, reset: {})
  }
  .padding()
}
