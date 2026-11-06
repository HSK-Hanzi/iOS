//
//  SentenceQuizConfigurationForm.swift
//  Zili
//

import SwiftUI

/// The setup fields for a deck of sentences, to hear or to say: the sentences — a corpus's levels in
/// one HSK standard, the learner's favorites, or those missed in `mode` — and how many. Dealing
/// the deck is the form's own job: it resolves the chosen source into sentences and hands the
/// finished ``SentenceQuizSession`` to `start`, recording each sentence answered wrong as a miss in
/// `mode` for a quiz and nothing for practice. A `cancel` handler adds a button beside Start, for a
/// form presented modally.
struct SentenceQuizConfigurationForm: View {
  let library: SentenceLibrary
  let mode: SentenceQuizMode
  let purpose: StudyPurpose

  let cancel: (() -> Void)?
  let start: (SentenceQuizSession) -> Void

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
      QuizStartControls(
        title: purpose.startTitle,
        cancel: cancel,
        isDisabled: sentenceCount == 0,
        start: dealDeck
      )
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
          if missedIDs.isEmpty {
            Text(mode.emptyMissedPrompt)
              .foregroundStyle(.secondary)
          }
      }
    } header: {
      Text("Sentences")
    } footer: {
      Text("\(sentenceCount) sentences selected.")
    }
  }

  private var missedIDs: [String] {
    sentenceMisses.sentencesMissed(in: mode)
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
      case .missed: .missed(missedIDs)
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
    mode: SentenceQuizMode,
    purpose: StudyPurpose = .quiz,
    cancel: (() -> Void)? = nil,
    start: @escaping (SentenceQuizSession) -> Void
  ) {
    self.library = library
    self.mode = mode
    self.purpose = purpose
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
    switch purpose {
      case .quiz:
        start(
          SentenceQuizSession(deck: deck, onMiss: { sentenceMisses.recordMiss($0, mode: mode) })
        )
      case .practice:
        start(SentenceQuizSession(deck: deck))
    }
  }

  /// Which kind of sentence set feeds the quiz.
  private enum SourceKind: Hashable {
    case hskLevels
    case favorites
    case missed
  }
}

/// Loads the real ``SentenceLibrary`` so the level picker and sentence counts reflect the shipped
/// corpora.
#Preview("From bundle") {
  @Previewable @State var library: SentenceLibrary?

  Group {
    if let library {
      SentenceQuizConfigurationForm(library: library, mode: .listening, cancel: {}, start: { _ in })
    } else {
      ProgressView()
    }
  }
  .environment(SentenceFavoritesStore.inMemory())
  .environment(SentenceMissStore.inMemory())
  .task { library = SentenceLibrary.load() }
}

extension SentenceQuizMode {
  /// What a form says when this quiz has missed no sentences to drill.
  fileprivate var emptyMissedPrompt: LocalizedStringKey {
    switch self {
      case .listening: "Miss sentences in a listening quiz to build a deck of them."
      case .speaking: "Miss sentences in a speaking quiz to build a deck of them."
    }
  }
}
