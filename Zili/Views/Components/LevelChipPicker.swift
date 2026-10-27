//
//  LevelChipPicker.swift
//  Zili
//

import SwiftUI

/// Picks one or more HSK levels of one standard as tappable chips in their level colors, mirroring
/// the character quiz's ``CharacterSetPickerView``.
struct LevelChipPicker: View {
  @Binding var levels: Set<HSKLevel>
  let available: [HSKLevel]

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
      ForEach(available, id: \.self) { level in
        LevelChip(
          band: level.band,
          isSelected: levels.contains(level),
          toggle: { toggle(level) }
        )
      }
    }
    .padding(.vertical, 4)
  }

  private func toggle(_ level: HSKLevel) {
    if levels.contains(level) {
      levels.remove(level)
    } else {
      levels.insert(level)
    }
  }
}

/// A single tappable level chip in its band's color: a soft wash of the hue when off, the full
/// level gradient when it belongs to the selection.
private struct LevelChip: View {
  let band: Int
  let isSelected: Bool
  let toggle: () -> Void

  @Environment(\.self)
  private var environment

  var body: some View {
    let palette = HSKPalette.palette(forBand: band).resolved(in: environment)
    return Button(action: toggle) {
      Text(band, format: .number)
        .font(.headline)
        .foregroundStyle(isSelected ? Color.white : palette.tint)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(fill(palette), in: .rect(cornerRadius: 10))
        .overlay {
          RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
              palette.tint.opacity(isSelected ? 0 : 0.35),
              lineWidth: isSelected ? 0 : 1
            )
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text("HSK level \(band, format: .number)"))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  private func fill(_ palette: LevelPalette.Resolved) -> AnyShapeStyle {
    isSelected
      ? AnyShapeStyle(palette.promptGradient)
      : AnyShapeStyle(palette.tint.opacity(0.16))
  }
}

#Preview {
  LevelChipPickerPreview()
}

/// Holds the selection the picker toggles, starting with one level chosen.
private struct LevelChipPickerPreview: View {
  @State private var levels: Set<HSKLevel> = [HSKLevel(standard: .newest, band: 2)]

  var body: some View {
    LevelChipPicker(
      levels: $levels,
      available: (1...7).map { HSKLevel(standard: .newest, band: $0) }
    )
    .padding()
  }
}
