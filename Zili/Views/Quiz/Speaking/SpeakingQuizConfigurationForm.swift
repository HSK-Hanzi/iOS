//
//  SpeakingQuizConfigurationForm.swift
//  Zili
//

import SwiftUI

/// The setup fields for saying words aloud, in the speaking quiz or speaking practice: the words
/// the learner will say, and how many. Dealing the deck is the form's own job — it hands the
/// finished ``QuizSession`` to `start`, wired by its ``Purpose``. A `cancel` handler adds a button
/// beside Start, for a form presented modally.
struct SpeakingQuizConfigurationForm: View {
  let lexicon: Lexicon
  let purpose: Purpose

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
        missedWords: wordMisses.wordsMissed(in: .speaking),
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
    purpose: Purpose = .quiz,
    cancel: (() -> Void)? = nil,
    start: @escaping (QuizSession) -> Void
  ) {
    self.lexicon = lexicon
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
        start(QuizSession(deck: deck, onMiss: { wordMisses.recordMiss($0, mode: .speaking) }))
      case .practice:
        start(QuizSession(deck: deck))
    }
  }

  /// What the words are dealt for: a quiz, which records each word said wrong as a speaking miss,
  /// or practice, which records nothing — a word said straight after hearing it says little about
  /// whether it's known.
  enum Purpose {
    case quiz
    case practice

    var startTitle: LocalizedStringKey {
      switch self {
        case .quiz: "Start Quiz"
        case .practice: "Start Practice"
      }
    }
  }
}

/// Loads the real ``Lexicon`` so the level picker and word counts reflect the shipped data.
#Preview("From bundle") {
  @Previewable @State var lexicon: Lexicon?

  Group {
    if let lexicon {
      SpeakingQuizConfigurationForm(lexicon: lexicon, cancel: {}, start: { _ in })
    } else {
      ProgressView()
    }
  }
  .environment(WordMissStore.inMemory())
  .task { lexicon = try? await Lexicon.load() }
}
