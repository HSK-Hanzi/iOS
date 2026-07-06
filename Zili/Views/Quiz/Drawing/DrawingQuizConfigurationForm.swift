//
//  DrawingQuizConfigurationForm.swift
//  Zili
//

import SwiftUI

/// The drawing quiz's setup fields: the words whose characters the learner will write, and how
/// many. Dealing the deck is the form's own job — it explodes the chosen words into their
/// drawable characters and hands the finished ``QuizSession`` to `start`. A `cancel` handler adds
/// a button beside Start, for a form presented modally.
struct DrawingQuizConfigurationForm: View {
  let lexicon: Lexicon

  let cancel: (() -> Void)?
  let start: (QuizSession) -> Void

  @State private var source: QuizDeckSource
  @State private var savedLevels: Set<HSKLevel>
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
        missedWords: wordMisses.wordsMissed(in: .writing),
        countLabel: Text("\(characterCount) characters to draw.")
      )
      Section("Deck") {
        QuizDeckSizePicker(title: "Characters", deckSize: $deckSize)
      }
    } start: {
      QuizStartControls(cancel: cancel, isDisabled: characterCount == 0, start: dealDeck)
    }
  }

  /// How many distinct characters the chosen words resolve to — the deck's ceiling, and the
  /// number the learner is choosing among.
  private var characterCount: Int {
    QuizDeckBuilder.drawableCharacters(of: source, in: lexicon).count
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
    let deck = QuizDeckBuilder.characterDeck(
      from: lexicon,
      source: source,
      limit: deckSize,
      romanization: romanization
    )
    start(QuizSession(deck: deck, onMiss: { wordMisses.recordMiss($0, mode: .writing) }))
  }
}

#Preview("From bundle") {
  DrawingConfigurationFormPreview()
}

/// Loads the real ``Lexicon`` so the level picker and character counts reflect the shipped data.
private struct DrawingConfigurationFormPreview: View {
  @State private var lexicon: Lexicon?

  var body: some View {
    Group {
      if let lexicon {
        DrawingQuizConfigurationForm(lexicon: lexicon, cancel: {}, start: { _ in })
      } else {
        ProgressView()
      }
    }
    .environment(WordMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
