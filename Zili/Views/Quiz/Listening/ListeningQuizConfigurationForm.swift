//
//  ListeningQuizConfigurationForm.swift
//  Zili
//

import SwiftUI

/// The listening quiz's setup fields: the sentences the learner will hear — a corpus's levels, or
/// their favorites — and how many. Dealing the deck is the form's own job: it resolves the chosen
/// source into sentences and hands the finished ``ListeningQuizSession`` to `start`. A `cancel`
/// handler adds a button beside Start, for a form presented modally.
struct ListeningQuizConfigurationForm: View {
  let library: SentenceLibrary

  let cancel: (() -> Void)?
  let start: (ListeningQuizSession) -> Void

  @Environment(SentenceFavoritesStore.self)
  private var favorites

  @Environment(SentenceMissStore.self)
  private var sentenceMisses

  @State private var kind: SourceKind
  @State private var corpusID: String
  @State private var levels: Set<Int>
  @State private var deckSize: Int? = 20

  var body: some View {
    QuizConfigurationLayout {
      sourceSection
      Section("Deck") {
        QuizDeckSizePicker(title: "Sentences", deckSize: $deckSize)
      }
    } start: {
      QuizStartControls(cancel: cancel, isDisabled: sentenceCount == 0, start: dealDeck)
    }
  }

  private var sourceSection: some View {
    Section {
      Picker("Set", selection: $kind) {
        Text("HSK Levels").tag(SourceKind.hskLevels)
        Text("Favorites").tag(SourceKind.favorites)
        Text("Missed").tag(SourceKind.missed)
      }
      .pickerStyle(.segmented)

      switch kind {
        case .hskLevels:
          if library.corpora.count > 1 {
            Picker("Corpus", selection: $corpusID) {
              ForEach(library.corpora) { corpus in
                Text(corpus.title).tag(corpus.id)
              }
            }
            .pickerStyle(.menu)
          }
          SentenceLevelPicker(levels: $levels, available: availableLevels)
        case .favorites:
          if favorites.favoritedIDs.isEmpty {
            Text("Star sentences to build a favorites deck.")
              .foregroundStyle(.secondary)
          }
        case .missed:
          if sentenceMisses.missedSentenceIDs.isEmpty {
            Text("Miss sentences in a listening quiz to build a deck of them.")
              .foregroundStyle(.secondary)
          }
      }
    } header: {
      Text("Sentences")
    } footer: {
      Text("\(sentenceCount) sentences selected.")
    }
  }

  /// The levels the chosen corpus has, ascending — the bands the learner picks among.
  private var availableLevels: [Int] {
    (library.corpus(id: corpusID) ?? library.defaultCorpus)?.levels ?? []
  }

  private var source: SentenceQuizSource {
    switch kind {
      case .hskLevels: .levels(corpusID: corpusID, levels: levels)
      case .favorites: .favorites
      case .missed: .missed(sentenceMisses.missedSentenceIDs)
    }
  }

  private var sentenceCount: Int {
    SentenceQuizDeckBuilder.sentences(
      for: source,
      in: library,
      favoriteIDs: favorites.favoritedIDs
    ).count
  }

  init(
    library: SentenceLibrary,
    cancel: (() -> Void)? = nil,
    start: @escaping (ListeningQuizSession) -> Void
  ) {
    self.library = library
    self.cancel = cancel
    self.start = start
    let corpus = library.defaultCorpus
    _kind = State(initialValue: .hskLevels)
    _corpusID = State(initialValue: corpus?.id ?? "")
    _levels = State(initialValue: Set(corpus?.levels.first.map { [$0] } ?? []))
  }

  private func dealDeck() {
    let deck = SentenceQuizDeckBuilder.build(
      for: source,
      in: library,
      favoriteIDs: favorites.favoritedIDs,
      limit: deckSize
    )
    start(ListeningQuizSession(deck: deck, onMiss: { sentenceMisses.recordMiss($0) }))
  }

  /// Which kind of sentence set feeds the quiz.
  private enum SourceKind: Hashable {
    case hskLevels
    case favorites
    case missed
  }
}

/// Picks one or more sentence levels as tappable chips in their level colors, mirroring the
/// character quiz's ``CharacterSetPickerView`` but over the bare band numbers a corpus indexes by.
private struct SentenceLevelPicker: View {
  @Binding var levels: Set<Int>
  let available: [Int]

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
      ForEach(available, id: \.self) { band in
        SentenceLevelChip(
          band: band,
          isSelected: levels.contains(band),
          toggle: { toggle(band) }
        )
      }
    }
    .padding(.vertical, 4)
  }

  private func toggle(_ band: Int) {
    if levels.contains(band) {
      levels.remove(band)
    } else {
      levels.insert(band)
    }
  }
}

/// A single tappable level chip in its band's color: a soft wash of the hue when off, the full
/// level gradient when it belongs to the selection.
private struct SentenceLevelChip: View {
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

#Preview("From bundle") {
  ListeningConfigurationFormPreview()
}

/// Loads the real ``SentenceLibrary`` so the level picker and sentence counts reflect the shipped
/// corpora.
private struct ListeningConfigurationFormPreview: View {
  @State private var library: SentenceLibrary?

  var body: some View {
    Group {
      if let library {
        ListeningQuizConfigurationForm(library: library, cancel: {}, start: { _ in })
      } else {
        ProgressView()
      }
    }
    .environment(SentenceFavoritesStore.inMemory())
    .environment(SentenceMissStore.inMemory())
    .task { library = await SentenceLibrary.load() }
  }
}
