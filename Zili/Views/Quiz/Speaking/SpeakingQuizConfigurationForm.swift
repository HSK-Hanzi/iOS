//
//  SpeakingQuizConfigurationForm.swift
//  Zili
//

import SwiftUI

/// The speaking quiz's setup fields: the words the learner will say, and how many. Dealing the
/// deck is the form's own job — it hands the finished ``QuizSession`` to `start`, wired to record
/// each word said wrong as a speaking miss. A `cancel` handler adds a button beside Start, for a
/// form presented modally.
struct SpeakingQuizConfigurationForm: View {
  let lexicon: Lexicon

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
      QuizStartControls(cancel: cancel, isDisabled: wordCount == 0, start: dealDeck)
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
    cancel: (() -> Void)? = nil,
    start: @escaping (QuizSession) -> Void
  ) {
    self.lexicon = lexicon
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
    start(QuizSession(deck: deck, onMiss: { wordMisses.recordMiss($0, mode: .speaking) }))
  }
}

#Preview("From bundle") {
  SpeakingConfigurationFormPreview()
}

/// Loads the real ``Lexicon`` so the level picker and word counts reflect the shipped data.
private struct SpeakingConfigurationFormPreview: View {
  @State private var lexicon: Lexicon?

  var body: some View {
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
}
