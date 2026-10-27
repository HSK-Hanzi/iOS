//
//  LevelTile.swift
//  Zili
//

import SwiftUI

/// One HSK band as a study-card tile in its level colors: the level number above a caption saying
/// what the band holds, such as its word count.
struct LevelTile: View {
  let band: Int
  /// What the band holds, e.g. “150 words”; also the tile's accessibility value.
  let caption: Text
  var isSelected = false

  var body: some View {
    StudyCardTile(palette: HSKPalette.palette(forBand: band)) {
      VStack(spacing: 4) {
        Text("Level \(band, format: .number)")
          .font(.title3.weight(.semibold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        caption
          .font(.caption)
          .foregroundStyle(.white.opacity(0.85))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .selectionRing(isSelected)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("HSK level \(band, format: .number)"))
    .accessibilityValue(caption)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

#Preview {
  LevelTile(band: 3, caption: Text("\(298) words"))
    .frame(width: 120)
    .padding()
}
