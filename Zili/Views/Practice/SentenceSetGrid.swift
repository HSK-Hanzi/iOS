//
//  SentenceSetGrid.swift
//  Zili
//

import SwiftUI

/// A sentence set a learner keeps: their favorited sentences, or the ones they've missed in a
/// listening quiz. Both span every corpus.
enum SentenceSetSelection: Hashable {
  case favorites
  case missed
}

/// The sentence sets a learner keeps — their favorites and the sentences they've missed — on the
/// same study-card tiles ``CharacterSetGrid`` uses, so the two browsers read as one deck of cards.
/// Sentences themselves are found through the words they exemplify, on each word's entry.
struct SentenceSetGrid: View {
  let library: SentenceLibrary
  /// The screen's title, kept concise so the back button carries where the set was reached from.
  var title: LocalizedStringKey = "Sentences"
  @Binding var selection: SentenceSetSelection?

  @Environment(SentenceFavoritesStore.self)
  private var favorites

  @Environment(SentenceMissStore.self)
  private var sentenceMisses

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        FavoritesCell(
          sentenceCount: favorites.favoritedIDs.count,
          isSelected: selection == .favorites
        ) {
          selection = .favorites
        }
        MissedCell(
          sentenceCount: sentenceMisses.missedSentenceIDs.count,
          isSelected: selection == .missed
        ) {
          selection = .missed
        }
      }
      .padding()
    }
    .navigationTitle(title)
  }

  init(
    library: SentenceLibrary,
    title: LocalizedStringKey = "Sentences",
    selection: Binding<SentenceSetSelection?>
  ) {
    self.library = library
    self.title = title
    _selection = selection
  }
}

/// Resolves a ``SentenceSetSelection`` into the list of its sentences — the learner's favorites in
/// starred order with a Clear All button, or the sentences they've missed. Shared
/// by the iOS interstitial's drill-down and the macOS split view's detail column so a set opens
/// the same way on both.
struct SentenceSetContent: View {
  let library: SentenceLibrary
  let selection: SentenceSetSelection

  @Environment(SentenceFavoritesStore.self)
  private var favorites

  @Environment(SentenceMissStore.self)
  private var sentenceMisses

  var body: some View {
    switch selection {
      case .favorites:
        SentenceListView(
          sentences: favorites.favoritedIDs.compactMap { library.sentence(id: $0) },
          title: String(localized: "Favorites"),
          emptyTitle: "No Favorites",
          onClearAll: favorites.clearAll,
          onUnstar: { favorites.remove($0.id) }
        )
      case .missed:
        SentenceListView(
          sentences: sentenceMisses.missedSentenceIDs.compactMap { library.sentence(id: $0) },
          title: String(localized: "Missed"),
          emptyTitle: "No Missed Sentences"
        )
    }
  }
}

/// The favorites set as a study-card tile: a star above the count of starred sentences.
private struct FavoritesCell: View {
  let sentenceCount: Int
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
          Text("\(sentenceCount) sentences")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
        }
      }
      .selectionRing(isSelected)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(AccessibilityID.sentenceSetFavorites)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// The missed set as a study-card tile: sitting beneath Favorites in a red that echoes the miss
/// badge, a warning glyph above the count of sentences missed in a listening quiz.
private struct MissedCell: View {
  let sentenceCount: Int
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
          Text("\(sentenceCount) sentences")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
        }
      }
      .selectionRing(isSelected)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(AccessibilityID.sentenceSetMissed)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

#Preview("Sentence sets · from bundle") {
  SentenceSetGridPreview()
}

/// Loads the real ``SentenceLibrary`` so the grid's sets resolve against the shipped corpora.
private struct SentenceSetGridPreview: View {
  @State private var library: SentenceLibrary?
  @State private var selection: SentenceSetSelection?

  var body: some View {
    NavigationStack {
      Group {
        if let library {
          SentenceSetGrid(library: library, selection: $selection)
        } else {
          ProgressView()
        }
      }
    }
    .environment(SentenceFavoritesStore.inMemory())
    .environment(SentenceMissStore.inMemory())
    .task { library = SentenceLibrary.load() }
  }
}
