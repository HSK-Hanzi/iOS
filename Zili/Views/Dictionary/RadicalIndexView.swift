//
//  RadicalIndexView.swift
//  Zili
//

import SwiftUI

/// Looking a character up by its radical, the way a printed dictionary's radical index works:
/// every radical by stroke count, then a chosen radical's characters by the strokes beyond it.
/// Choosing a character hands it to `choose`.
struct RadicalIndexView: View {
  let characters: CharacterLibrary
  let choose: (String) -> Void

  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    NavigationStack {
      RadicalGrid(radicals: characters.radicals())
        .navigationTitle("Radicals")
        .navigationDestination(for: Radical.self) { radical in
          RadicalCharactersView(
            radical: radical,
            groups: characters.characters(withRadical: radical),
            choose: choose
          )
        }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
          }
        }
    }
  }
}

/// Every radical, in sections by stroke count.
private struct RadicalGrid: View {
  let radicals: [Radical]

  var body: some View {
    ScrollView {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 52), spacing: 8)],
        spacing: 8,
        pinnedViews: .sectionHeaders
      ) {
        ForEach(strokeCounts, id: \.self) { strokes in
          Section {
            ForEach(radicals.filter { $0.strokes == strokes }) { radical in
              NavigationLink(value: radical) {
                GlyphCell(glyph: radical.glyph)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(Text("Radical \(radical.glyph)"))
              .accessibilityIdentifier(AccessibilityID.radicalCell(radical.number))
            }
          } header: {
            StrokeCountHeader(text: Text("^[\(strokes) stroke](inflect: true)"))
          }
        }
      }
      .padding()
    }
  }

  private var strokeCounts: [Int] {
    Array(Set(radicals.map(\.strokes))).sorted()
  }
}

/// A radical's characters, in sections by the strokes each takes beyond the radical.
private struct RadicalCharactersView: View {
  let radical: Radical
  let groups: [RadicalStrokeGroup]
  let choose: (String) -> Void

  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    ScrollView {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 52), spacing: 8)],
        spacing: 8,
        pinnedViews: .sectionHeaders
      ) {
        ForEach(groups) { group in
          Section {
            ForEach(group.characters, id: \.self) { character in
              Button {
                choose(character)
              } label: {
                GlyphCell(glyph: script.render(character))
              }
              .buttonStyle(.plain)
              .accessibilityLabel(Text(script.spoken(character)))
              .accessibilityIdentifier(AccessibilityID.radicalCharacter)
            }
          } header: {
            StrokeCountHeader(text: Text(verbatim: "+\(group.residualStrokes)"))
              .accessibilityLabel(Text("^[\(group.residualStrokes) more stroke](inflect: true)"))
          }
        }
      }
      .padding()
    }
    .navigationTitle(Text(verbatim: radical.glyph))
  }
}

/// A radical or character on a square tile.
private struct GlyphCell: View {
  let glyph: String

  @ScaledMetric(relativeTo: .title2)
  private var side: CGFloat = 52

  var body: some View {
    Text(verbatim: glyph)
      .font(.title2)
      .frame(width: side, height: side)
      .background(.fill.tertiary, in: .rect(cornerRadius: 8))
      .contentShape(.rect)
  }
}

/// A section's stroke count, pinned above its tiles while they scroll.
private struct StrokeCountHeader: View {
  let text: Text

  var body: some View {
    text
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 4)
      .background(.background)
  }
}

#Preview("Radicals · from bundle") {
  RadicalIndexPreview()
}

/// Loads the real character database so the index lists the shipped radicals.
private struct RadicalIndexPreview: View {
  @State private var characters: CharacterLibrary?

  var body: some View {
    Group {
      if let characters {
        RadicalIndexView(characters: characters) { _ in }
      } else {
        ProgressView()
      }
    }
    .task { characters = try? CharacterLibrary.load() }
  }
}
