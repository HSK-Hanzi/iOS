//
//  WordQuizConfigurationForm.swift
//  Zili
//

import SwiftUI

/// The setup fields for a deck of words, to say or to pick out by ear: the words — levels, the
/// learner's favorites, or those missed in `mode` — and how many. Dealing the deck is the form's own
/// job: it hands the finished ``QuizSession`` to `start`, recording each word answered wrong as a
/// miss in `mode` for a quiz and nothing for practice. A `cancel` handler adds a button beside
/// Start, for a form presented modally.
struct WordQuizConfigurationForm: View {
  let lexicon: Lexicon
  let mode: WordQuizMode
  let purpose: StudyPurpose

  let cancel: (() -> Void)?
  let start: (QuizSession) -> Void

  @State private var source: QuizDeckSource
  @State private var savedLevels: Set<HSKLevel>
  @State private var sort = QuizDeckSort.random
  @State private var deckSize: Int? = 20

  @Environment(WordMissStore.self)
  private var wordMisses

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  var body: some View {
    QuizConfigurationLayout {
      QuizSourceSection(
        available: lexicon.availableLevels,
        source: $source,
        savedLevels: $savedLevels,
        sort: $sort,
        missedWords: wordMisses.wordsMissed(in: mode),
        countLabel: Text("\(wordCount) words selected.")
      )
      Section("Deck") {
        QuizDeckSizePicker(title: "Words", deckSize: $deckSize)
      }
    } start: {
      QuizStartControls(
        title: purpose.startTitle,
        cancel: cancel,
        isDisabled: wordCount == 0,
        start: dealDeck
      )
    }
  }

  private var wordCount: Int {
    source.headwords(in: lexicon).count
  }

  /// The sort to deal by: the learner's choice while their favorites are the source, and a random
  /// sample otherwise — a set with no starring dates has no newest or oldest to draw.
  private var deckSort: QuizDeckSort {
    source.isFavorites ? sort : .random
  }

  init(
    lexicon: Lexicon,
    mode: WordQuizMode,
    purpose: StudyPurpose = .quiz,
    cancel: (() -> Void)? = nil,
    start: @escaping (QuizSession) -> Void
  ) {
    self.lexicon = lexicon
    self.mode = mode
    self.purpose = purpose
    self.cancel = cancel
    self.start = start
    let level = lexicon.availableLevels.first ?? HSKLevel(standard: .new, band: 1)
    _source = State(initialValue: .hskLevels([level]))
    _savedLevels = State(initialValue: [level])
  }

  private func dealDeck() {
    let deck = QuizDeckBuilder.build(
      from: lexicon,
      source: source,
      sort: deckSort,
      limit: deckSize,
      romanization: romanization
    )
    switch purpose {
      case .quiz:
        start(QuizSession(deck: deck, onMiss: { wordMisses.recordMiss($0, mode: mode) }))
      case .practice:
        start(QuizSession(deck: deck))
    }
  }
}

/// Loads the real ``Lexicon`` so the level picker and word counts reflect the shipped data.
#Preview("From bundle") {
  @Previewable @State var lexicon: Lexicon?

  Group {
    if let lexicon {
      WordQuizConfigurationForm(lexicon: lexicon, mode: .speaking, cancel: {}, start: { _ in })
    } else {
      ProgressView()
    }
  }
  .environment(WordMissStore.inMemory())
  .task { lexicon = try? await Lexicon.load() }
}
