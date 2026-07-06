//
//  FlashcardQuizConfigurationForm.swift
//  Zili
//

import SwiftUI

/// The recognition quiz's setup fields: the syllabus level to drill, the direction, whether a
/// Hanzi prompt shows its reading, and the deck's size. Dealing the deck is the form's own job —
/// it hands the finished ``QuizSession`` to `start`, and whoever presented the form decides where
/// the quiz runs. A `cancel` handler adds a button beside Start, for a form presented modally.
struct FlashcardQuizConfigurationForm: View {
  let lexicon: Lexicon

  @Bindable var configuration: FlashcardQuizConfiguration

  let cancel: (() -> Void)?
  let start: (QuizSession) -> Void

  /// The bands to restore when the learner switches back from favorites, so the choice survives
  /// a round trip through the other source.
  @State private var savedLevels: Set<HSKLevel>

  @Environment(WordMissStore.self)
  private var wordMisses

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  var body: some View {
    QuizConfigurationLayout {
      QuizSourceSection(
        available: lexicon.availableLevels,
        source: $configuration.source,
        savedLevels: $savedLevels,
        missedWords: wordMisses.wordsMissed(in: .recognizing),
        countLabel: Text("\(wordCount) words selected.")
      )
      studyModeSection
      Section("Deck") {
        QuizDeckSizePicker(title: "Cards", deckSize: $configuration.deckSize)
      }
    } start: {
      QuizStartControls(cancel: cancel, isDisabled: wordCount == 0, start: dealDeck)
    }
  }

  private var studyModeSection: some View {
    Section("Study mode") {
      Picker("Direction", selection: $configuration.direction) {
        ForEach(PromptDirection.allCases, id: \.self) { direction in
          Text(direction.displayName).tag(direction)
        }
      }
      .pickerStyle(.segmented)

      Toggle(
        "Show \(romanization.displayName) with Hanzi",
        isOn: $configuration.showsReadingWithHanzi
      )
      .disabled(configuration.direction == .englishToChinese)
    }
  }

  private var wordCount: Int {
    configuration.source.headwords(in: lexicon).count
  }

  init(
    lexicon: Lexicon,
    configuration: FlashcardQuizConfiguration,
    cancel: (() -> Void)? = nil,
    start: @escaping (QuizSession) -> Void
  ) {
    self.lexicon = lexicon
    _configuration = Bindable(configuration)
    self.cancel = cancel
    self.start = start
    _savedLevels = State(initialValue: configuration.source.hskLevels)
  }

  private func dealDeck() {
    let deck = QuizDeckBuilder.build(
      from: lexicon,
      source: configuration.source,
      limit: configuration.deckSize,
      romanization: romanization
    )
    start(QuizSession(deck: deck, onMiss: { wordMisses.recordMiss($0, mode: .recognizing) }))
  }
}

#Preview("From bundle") {
  FlashcardConfigurationFormPreview()
}

/// Loads the real ``Lexicon`` so the level picker and word counts reflect the shipped data.
private struct FlashcardConfigurationFormPreview: View {
  @State private var lexicon: Lexicon?
  @State private var configuration = FlashcardQuizConfiguration(
    source: .hskLevels([HSKLevel(standard: .new, band: 1)])
  )

  var body: some View {
    Group {
      if let lexicon {
        FlashcardQuizConfigurationForm(
          lexicon: lexicon,
          configuration: configuration,
          cancel: {},
          start: { _ in }
        )
      } else {
        ProgressView()
      }
    }
    .environment(WordMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
