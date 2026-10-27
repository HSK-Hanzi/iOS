//
//  ListeningQuizConfigurationForm.swift
//  Zili
//

import SwiftUI

/// The listening quiz's setup fields: the sentences the learner will hear — a corpus's levels in
/// one HSK standard, or their favorites — and how many. Dealing the deck is the form's own job: it resolves the chosen
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
  @State private var standard = HSKLevel.Standard.newest
  @State private var levels: Set<HSKLevel>
  @State private var sort = QuizDeckSort.random
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
    .onChange(of: standard) { selectFirstLevel() }
    .onChange(of: corpusID) { selectFirstLevel() }
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
          Picker("Standard", selection: $standard) {
            ForEach(HSKLevel.Standard.allCases, id: \.self) { standard in
              Text(standard.displayName).tag(standard)
            }
          }
          .pickerStyle(.menu)
          LevelChipPicker(levels: $levels, available: availableLevels)
        case .favorites:
          if favorites.favoritedIDs.isEmpty {
            Text("Star sentences to build a favorites deck.")
              .foregroundStyle(.secondary)
          } else {
            QuizSortPicker(sort: $sort)
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

  /// The levels the chosen corpus has in the chosen standard, ascending — the bands the learner
  /// picks among.
  private var availableLevels: [HSKLevel] {
    (library.corpus(id: corpusID) ?? library.defaultCorpus)?.levels(in: standard) ?? []
  }

  private var source: SentenceQuizSource {
    switch kind {
      case .hskLevels: .levels(corpusID: corpusID, levels: levels)
      case .favorites: .favorites
      case .missed: .missed(sentenceMisses.missedSentenceIDs)
    }
  }

  /// The sort to deal by: the learner's choice while their favorites are the source, and a random
  /// sample otherwise — a set with no starring dates has no newest or oldest to draw.
  private var deckSort: QuizDeckSort {
    kind == .favorites ? sort : .random
  }

  private var sentenceCount: Int {
    SentenceQuizDeckBuilder.count(for: source, in: library, favoriteIDs: favorites.favoritedIDs)
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
    _levels = State(initialValue: Set(corpus?.levels(in: .newest).first.map { [$0] } ?? []))
  }

  private func selectFirstLevel() {
    levels = Set(availableLevels.first.map { [$0] } ?? [])
  }

  private func dealDeck() {
    let deck = SentenceQuizDeckBuilder.build(
      for: source,
      in: library,
      favoriteIDs: favorites.favoritedIDs,
      sort: deckSort,
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
    .task { library = SentenceLibrary.load() }
  }
}
