//
//  CharacterSetGrid.swift
//  Zili
//

import SwiftUI

/// A character set a learner can practice: an HSK syllabus band, their favorited words, or the
/// words they've missed in a quiz.
enum StudySet: Hashable {
  case level(HSKLevel)
  case favorites
  case missed
}

/// A grid of the character sets a learner can practice — their favorites, then the HSK syllabus
/// bands of one standard, chosen from a menu. It mirrors ``CharacterSetPickerView`` but navigates
/// instead of multi-selecting: each set is a study-card tile that pushes its ``CharacterSetView``,
/// so the two grids read as the same deck of cards drilling one level deeper.
struct CharacterSetGrid: View {
  let lexicon: Lexicon
  /// The screen's title. Defaults to “Practice” for the tab's own root; the interstitial passes
  /// “Characters” so the drilled grid reads as one branch of the two-card menu.
  var title: LocalizedStringKey = "Practice"
  @Binding var selection: StudySet?

  @Environment(FavoritesStore.self)
  private var favorites

  @Environment(WordMissStore.self)
  private var wordMisses

  @State private var standard: HSKLevel.Standard

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        FavoritesCell(
          wordCount: favorites.favoritedWords.count,
          isSelected: selection == .favorites
        ) {
          selection = .favorites
        }
        MissedCell(
          wordCount: wordMisses.missedWords.count,
          isSelected: selection == .missed
        ) {
          selection = .missed
        }
        if standards.count > 1 {
          Picker("Standard", selection: $standard) {
            ForEach(standards, id: \.self) { standard in
              Text(standard.displayName).tag(standard)
            }
          }
          .pickerStyle(.menu)
        }
        grid
      }
      .padding()
    }
    .navigationTitle(title)
    .onChange(of: standard) { selection = nil }
  }

  private var standards: [HSKLevel.Standard] {
    var seen = Set<HSKLevel.Standard>()
    return lexicon.availableLevels.map(\.standard).filter { seen.insert($0).inserted }.sorted()
  }

  private var levels: [HSKLevel] {
    lexicon.availableLevels.filter { $0.standard == standard }.sorted()
  }

  private var grid: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
      ForEach(levels, id: \.self) { level in
        Button {
          selection = .level(level)
        } label: {
          LevelCell(
            band: level.band,
            wordCount: lexicon.words(in: level).count,
            isSelected: selection == .level(level)
          )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.characterSetLevel(level.levelName))
      }
    }
  }

  init(lexicon: Lexicon, title: LocalizedStringKey = "Practice", selection: Binding<StudySet?>) {
    self.lexicon = lexicon
    self.title = title
    _selection = selection
    _standard = State(initialValue: lexicon.availableLevels.first?.standard ?? .new)
  }
}

/// The favorites set as a study-card tile: a star above the count of starred words, matching the
/// level cells it sits above so the whole grid reads as one deck.
private struct FavoritesCell: View {
  let wordCount: Int
  let isSelected: Bool
  let select: () -> Void

  var body: some View {
    Button(action: select) {
      StudyCardTile {
        VStack(spacing: 4) {
          Label("Favorites", systemImage: "star.fill")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .labelStyle(.titleAndIcon)
          Text("\(wordCount) words")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
        }
      }
      .selectionRing(isSelected)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(AccessibilityID.characterSetFavorites)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// The missed set as a study-card tile: sitting beneath Favorites in a red that echoes the miss
/// badge, a warning glyph above the count of words missed in a quiz.
private struct MissedCell: View {
  let wordCount: Int
  let isSelected: Bool
  let select: () -> Void

  var body: some View {
    Button(action: select) {
      StudyCardTile(palette: HSKPalette.missed) {
        VStack(spacing: 4) {
          Label("Missed", systemImage: "exclamationmark.circle.fill")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .labelStyle(.titleAndIcon)
          Text("\(wordCount) words")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
        }
      }
      .selectionRing(isSelected)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(AccessibilityID.characterSetMissed)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// One band in the grid: its level number above a word count, on the shared ``StudyCardTile``
/// so it matches the word cells it drills into.
private struct LevelCell: View {
  let band: Int
  let wordCount: Int
  var isSelected = false

  var body: some View {
    StudyCardTile(palette: HSKPalette.palette(forBand: band)) {
      VStack(spacing: 4) {
        Text("Level \(band, format: .number)")
          .font(.title3.weight(.semibold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text("\(wordCount) words")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.85))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .selectionRing(isSelected)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("HSK level \(band, format: .number)"))
    .accessibilityValue(Text("\(wordCount) words"))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

#Preview("Character sets · from bundle") {
  CharacterSetGridPreview()
}

/// Loads the real ``Lexicon`` so the grid reflects the shipped syllabus and word counts, with a
/// selection binding so the preview exercises the selected-cell ring.
private struct CharacterSetGridPreview: View {
  @State private var lexicon: Lexicon?
  @State private var selection: StudySet?

  var body: some View {
    NavigationStack {
      Group {
        if let lexicon {
          CharacterSetGrid(lexicon: lexicon, selection: $selection)
        } else {
          ProgressView()
        }
      }
    }
    .environment(FavoritesStore.inMemory())
    .environment(WordMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
