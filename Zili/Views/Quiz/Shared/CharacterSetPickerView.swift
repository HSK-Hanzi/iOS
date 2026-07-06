//
//  CharacterSetPickerView.swift
//  Zili
//

import SwiftUI

/// Picks one or more HSK syllabus bands to study. A menu chooses the standard; a grid below
/// lists that standard's bands as tappable chips the learner toggles on and off. The
/// selection stays within the chosen standard, so switching standards drops the others'
/// bands. No native control offers a multi-select grid, so the chips are plain buttons.
struct CharacterSetPickerView: View {
  @Binding var levels: Set<HSKLevel>
  let available: [HSKLevel]

  @State private var standard: HSKLevel.Standard

  var body: some View {
    Group {
      Picker("Standard", selection: standardBinding) {
        ForEach(standards, id: \.self) { standard in
          Text(standard.displayName).tag(standard)
        }
      }
      .pickerStyle(.menu)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
        ForEach(bands, id: \.self) { band in
          HSKLevelChip(
            band: band,
            isSelected: levels.contains(HSKLevel(standard: standard, band: band)),
            toggle: { toggle(band) }
          )
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var standards: [HSKLevel.Standard] {
    var seen = Set<HSKLevel.Standard>()
    return available.map(\.standard).filter { seen.insert($0).inserted }.sorted()
  }

  private var bands: [Int] {
    available.filter { $0.standard == standard }.map(\.band).sorted()
  }

  private var standardBinding: Binding<HSKLevel.Standard> {
    Binding(
      get: { standard },
      set: { newStandard in
        standard = newStandard
        levels = levels.filter { $0.standard == newStandard }
      }
    )
  }

  init(levels: Binding<Set<HSKLevel>>, available: [HSKLevel]) {
    _levels = levels
    self.available = available
    let initial = levels.wrappedValue.first?.standard ?? available.first?.standard ?? .new
    _standard = State(initialValue: initial)
  }

  private func toggle(_ band: Int) {
    let level = HSKLevel(standard: standard, band: band)
    if levels.contains(level) {
      levels.remove(level)
    } else {
      levels.insert(level)
    }
  }
}

/// A single tappable band chip in its level's color: a soft wash of the hue when off, the full
/// level gradient when it belongs to the selection.
private struct HSKLevelChip: View {
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

#Preview("Character set") {
  struct Demo: View {
    @State private var levels: Set<HSKLevel> = [HSKLevel(standard: .new, band: 3)]

    private let available: [HSKLevel] =
      (1...9).map { HSKLevel(standard: .new, band: $0) }
      + (1...6).map { HSKLevel(standard: .old, band: $0) }

    var body: some View {
      Form {
        Section("Levels") {
          CharacterSetPickerView(levels: $levels, available: available)
        }
      }
    }
  }

  return Demo()
}
