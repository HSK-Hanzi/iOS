//
//  SentenceSetGrid.swift
//  Zili
//

import SwiftUI

/// A sentence set a learner can practice: a level within a chosen corpus, their favorited
/// sentences, or the sentences they've missed in a listening quiz (favorites and misses both span
/// every corpus). The corpus travels with the level so a drilled set knows which corpus to draw from.
enum SentenceSetSelection: Hashable {
  case level(corpusID: String, level: Int)
  case favorites
  case missed
}

/// A grid of the sentence sets a learner can practice — their favorites, then the HSK bands of the
/// chosen corpus, mirroring ``CharacterSetGrid`` so the two browsers read as the same deck of
/// cards. A corpus picker appears only when more than one corpus shipped (Debug, where the HSK
/// workbook corpus joins the novel one); in Release, with a single corpus, it stays hidden.
struct SentenceSetGrid: View {
  let library: SentenceLibrary
  /// The screen's title, kept concise so the back button carries where the set was reached from.
  var title: LocalizedStringKey = "Sentences"
  @Binding var selection: SentenceSetSelection?

  @Environment(SentenceFavoritesStore.self)
  private var favorites

  @Environment(SentenceMissStore.self)
  private var sentenceMisses

  @State private var corpusID: String

  private var corpus: SentenceCorpus? {
    library.corpus(id: corpusID) ?? library.defaultCorpus
  }

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
        if library.corpora.count > 1 {
          Picker("Corpus", selection: $corpusID) {
            ForEach(library.corpora) { corpus in
              Text(corpus.title).tag(corpus.id)
            }
          }
          .pickerStyle(.menu)
        }
        grid
      }
      .padding()
    }
    .navigationTitle(title)
    .onChange(of: corpusID) { selection = nil }
  }

  private var grid: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
      ForEach(corpus?.levels ?? [], id: \.self) { level in
        let selectionForLevel = SentenceSetSelection.level(
          corpusID: corpus?.id ?? corpusID,
          level: level
        )
        Button {
          selection = selectionForLevel
        } label: {
          LevelCell(
            band: level,
            sentenceCount: corpus?.sentences(in: level).count ?? 0,
            isSelected: selection == selectionForLevel
          )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.sentenceSetLevel(level))
      }
    }
  }

  init(
    library: SentenceLibrary,
    title: LocalizedStringKey = "Sentences",
    selection: Binding<SentenceSetSelection?>
  ) {
    self.library = library
    self.title = title
    _selection = selection
    _corpusID = State(initialValue: library.defaultCorpus?.id ?? "")
  }
}

/// Resolves a ``SentenceSetSelection`` into the list of its sentences — a corpus band collated
/// in source order, or the learner's favorites in starred order with a Clear All button. Shared
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
      case let .level(corpusID, level):
        SentenceListView(
          sentences: library.corpus(id: corpusID)?.sentences(in: level) ?? [],
          title: String(localized: "Level \(level)")
        )
      case .favorites:
        SentenceListView(
          sentences: favorites.favoritedIDs.compactMap { library.sentence(id: $0) },
          title: String(localized: "Favorites"),
          emptyTitle: "No Favorites",
          onClearAll: favorites.clearAll
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

/// The favorites set as a study-card tile: a star above the count of starred sentences, matching
/// the level cells it sits above so the whole grid reads as one deck.
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

/// One band in the grid: its level number above a sentence count, on the shared ``StudyCardTile``
/// so it matches the character grid it sits beside.
private struct LevelCell: View {
  let band: Int
  let sentenceCount: Int
  var isSelected = false

  var body: some View {
    StudyCardTile(palette: HSKPalette.palette(forBand: band)) {
      VStack(spacing: 4) {
        Text("Level \(band, format: .number)")
          .font(.title3.weight(.semibold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text("\(sentenceCount) sentences")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.85))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .selectionRing(isSelected)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("HSK level \(band, format: .number)"))
    .accessibilityValue(Text("\(sentenceCount) sentences"))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

#Preview("Sentence sets · from bundle") {
  SentenceSetGridPreview()
}

/// Loads the real ``SentenceLibrary`` so the grid reflects the shipped corpora and their counts.
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
    .task { library = await SentenceLibrary.load() }
  }
}
