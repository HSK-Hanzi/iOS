//
//  ListeningCharactersRoundView.swift
//  Zili
//

import SwiftUI

/// One word's turn at picking a word out by ear, on a flashcard. The card shows nothing to read:
/// the word is said aloud, and the learner picks it from ``ListeningChoices`` beneath. Then the
/// choices give way to the card, turned over to the word's Hanzi, reading, and meaning under the
/// verdict — and, after a wrong pick, the word the learner heard it as.
///
/// A quiz takes the first pick. Practice takes a wrong pick away and says the word again, turning
/// the card once the word is found — a correct verdict only when it was found first time.
struct ListeningCharactersRoundView: View {
  private static let front = FlashcardFace(
    showsHanzi: false,
    showsReading: false,
    showsDefinition: false
  )
  private static let back = FlashcardFace(
    showsHanzi: true,
    showsReading: true,
    showsDefinition: true
  )

  let card: QuizCard
  let lexicon: Lexicon
  let purpose: StudyPurpose
  let onClose: () -> Void

  @Environment(QuizSession.self)
  private var session
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  @State private var phase = ListeningPhase.choosing(ruledOut: [])
  @State private var choices: [String] = []
  @State private var isFlipped = false
  @State private var pronouncer = WordPronouncer()
  @State private var stageSize = CGSize.zero
  @State private var topBarBottom: CGFloat = 0
  @State private var answerPanelTop: CGFloat = 0
  @State private var cardBottom: CGFloat = 0
  @State private var safeAreaInsets = EdgeInsets()
  @State private var thrown = CGSize.zero
  @State private var isThrowing = false

  var body: some View {
    ZStack {
      #if !os(visionOS)
        if let next = session.peek {
          NextCardPeek(isUncovered: isThrowing, isRisen: thrown != .zero) {
            CharacterFlashcardView(
              card: next,
              front: Self.front,
              back: Self.back,
              isFlipped: .constant(false),
              contentInsets: cardContentInsets
            )
          }
          .ignoresSafeArea()
        }
      #endif

      CharacterFlashcardView(
        card: card,
        front: Self.front,
        back: Self.back,
        isFlipped: flip,
        contentInsets: cardContentInsets
      )
      .onGeometryChange(for: CGFloat.self) {
        $0.frame(in: .global).maxY
      } action: {
        cardBottom = $0
      }
      .offset(thrown)
      #if os(visionOS)
        .frame(maxWidth: 360, maxHeight: 480)
      #else
        .ignoresSafeArea()
      #endif

      VStack(spacing: 20) {
        #if !os(visionOS)
          QuizTopBar(index: session.currentIndex, total: session.total, onClose: onClose)
            .onGeometryChange(for: CGFloat.self) {
              $0.frame(in: .global).maxY
            } action: {
              topBarBottom = $0
            }
        #endif

        Spacer(minLength: 0)

        if !phase.isAnswered {
          ReplayButton { pronouncer.speak(card.hanzi) }
          Spacer(minLength: 0)
        }

        VStack(spacing: 20) {
          switch phase {
            case .choosing(let ruledOut):
              ChoiceGrid(choices: choices, ruledOut: ruledOut, pick: pick)
            case let .answered(picked, outcome):
              if !isThrowing {
                AnswerFeedback(
                  outcome: outcome,
                  wrongPick: picked == card.word ? nil : lexicon.lookup(picked)
                )
              }
              AnsweredControls(
                onHear: { pronouncer.speak(card.hanzi) },
                onNext: { advance(outcome) }
              )
          }
        }
        .onGeometryChange(for: CGFloat.self) {
          $0.frame(in: .global).minY
        } action: {
          if !isThrowing { answerPanelTop = $0 }
        }
        .avoidingFold(movingAlong: .horizontal)
      }
      .padding(20)
    }
    .quizAmbientBackground(QuizStyle.ambientGradient)
    .animation(.smooth, value: phase)
    .onGeometryChange(for: CGSize.self) {
      $0.size
    } action: {
      stageSize = $0
    }
    .onGeometryChange(for: EdgeInsets.self) {
      $0.safeAreaInsets
    } action: {
      safeAreaInsets = $0
    }
    .onAppear {
      choices = offeredChoices()
      pronouncer.speak(card.hanzi)
    }
    .onDisappear { pronouncer.stop() }
    #if os(visionOS)
      .toolbar {
        ToolbarItem(placement: .principal) {
          QuizProgress(index: session.currentIndex, total: session.total)
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark", action: onClose)
          .accessibilityIdentifier(AccessibilityID.quizCloseButton)
        }
      }
    #endif
  }

  /// The card's side, which only the answer turns over: until then a tap can't reveal the word.
  private var flip: Binding<Bool> {
    Binding(
      get: { isFlipped },
      set: { if phase.isAnswered { isFlipped = $0 } }
    )
  }

  /// Keeps the card's content clear of the floating top bar, of the choices or verdict and
  /// everything below them down to the card's bleeding edge — as they stood when the card was
  /// thrown, so it leaves as it was — and of whatever the safe area holds beside the card.
  private var cardContentInsets: EdgeInsets {
    EdgeInsets(
      top: topBarBottom,
      leading: safeAreaInsets.leading,
      bottom: max(cardBottom - answerPanelTop, 0),
      trailing: safeAreaInsets.trailing
    )
  }

  /// The word among its distractors, drawn from the syllabus up to the word's own band — words a
  /// learner at that level could be expected to tell it from — or from the whole syllabus when
  /// that leaves too few.
  private func offeredChoices() -> [String] {
    let levels = lexicon.availableLevels.filter { $0.standard == .newest }
    let reachable = levels.filter { $0.band <= card.hskBand ?? .max }
    var generator = SystemRandomNumberGenerator()
    let choose = { (pool: [String]) in
      ListeningChoices.choices(
        for: card.word,
        among: pool,
        readings: readings,
        using: &generator
      )
    }
    let choices = choose(reachable.flatMap { lexicon.words(in: $0) })
    guard choices.count < ListeningChoices.count else { return choices }
    return choose(levels.flatMap { lexicon.words(in: $0) })
  }

  /// A word's readings: every reading any source gives the word being heard, and the syllabus
  /// readings of the words it's offered among — enough to tell them apart without reading every
  /// dictionary for each.
  private func readings(of word: String) -> Set<String> {
    guard word != card.word else { return lexicon.lookup(word).numberedReadings }
    return Set(lexicon.hsk[word].flatMap(\.forms).map(\.transcriptions.numeric))
  }

  private func pick(_ choice: String) {
    guard case .choosing(var ruledOut) = phase, !ruledOut.contains(choice) else { return }
    if choice == card.word {
      answer(choice, ruledOut.isEmpty ? .correct : .needsReview)
    } else if purpose == .quiz {
      answer(choice, .needsReview)
    } else {
      ruledOut.insert(choice)
      phase = .choosing(ruledOut: ruledOut)
      pronouncer.speak(card.hanzi)
    }
  }

  private func answer(_ choice: String, _ outcome: QuizSession.Outcome) {
    phase = .answered(picked: choice, outcome: outcome)
    isFlipped = true
  }

  /// Moves on to the next word, throwing this card off the way a judged flashcard goes.
  private func advance(_ outcome: QuizSession.Outcome) {
    guard !isThrowing else { return }
    pronouncer.stop()
    withTransaction(Transaction(animation: nil)) { isThrowing = true }
    guard !reduceMotion else {
      session.mark(outcome)
      return
    }
    withAnimation(ThrowDirection.animation) {
      thrown = ThrowDirection.of(outcome).offScreenVector(in: stageSize)
    } completion: {
      session.mark(outcome)
    }
  }
}

/// Where a turn has got to: picking the word out, with the wrong picks practice has ruled out, or
/// answered, with the pick and the verdict it earned.
private enum ListeningPhase: Hashable {
  case choosing(ruledOut: Set<String>)
  case answered(picked: String, outcome: QuizSession.Outcome)

  var isAnswered: Bool {
    if case .answered = self { true } else { false }
  }
}

/// The big speaker the learner taps to hear the word again.
private struct ReplayButton: View {
  let action: () -> Void

  @ScaledMetric(relativeTo: .largeTitle)
  private var iconSize: CGFloat = 56

  var body: some View {
    Button(action: action) {
      Label("Hear It Again", systemImage: "speaker.wave.2.fill")
        .labelStyle(.iconOnly)
        .font(.system(size: iconSize))
        .padding(28)
    }
    .buttonStyle(.plain)
    .foregroundStyle(QuizStyle.chromeLabel)
    .glassButton()
    .buttonBorderShape(.circle)
    .accessibilityIdentifier(AccessibilityID.listeningReplay)
  }
}

/// The words to pick from, two by two, each numbered for the keyboard. A word practice has ruled
/// out shrinks away, leaving its place empty so the words left stay where the learner last saw
/// them.
private struct ChoiceGrid: View {
  let choices: [String]
  let ruledOut: Set<String>
  let pick: (String) -> Void

  var body: some View {
    GlassContainer(spacing: 12) {
      Grid(horizontalSpacing: 12, verticalSpacing: 12) {
        ForEach(Array(rows.enumerated()), id: \.offset) { row, words in
          GridRow {
            ForEach(Array(words.enumerated()), id: \.element) { column, word in
              ChoiceSlot(
                word: word,
                number: row * 2 + column + 1,
                isRuledOut: ruledOut.contains(word)
              ) {
                pick(word)
              }
            }
          }
        }
      }
    }
    .frame(maxWidth: 440)
  }

  private var rows: [[String]] {
    stride(from: 0, to: choices.count, by: 2).map {
      Array(choices[$0..<min($0 + 2, choices.count)])
    }
  }
}

/// One word's place among the choices, holding its size once the word has shrunk away.
private struct ChoiceSlot: View {
  private static let ruledOutScale: CGFloat = 0.6

  let word: String
  let number: Int
  let isRuledOut: Bool
  let action: () -> Void

  var body: some View {
    ZStack {
      Button {
      } label: {
        ChoiceLabel(word: word)
      }
      .glassButton()
      .hidden()
      .accessibilityHidden(true)
      if !isRuledOut {
        Button(action: action) {
          ChoiceLabel(word: word)
        }
        .glassButton()
        .keyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: [])
        .accessibilityIdentifier(AccessibilityID.listeningChoice)
        .transition(.scale(scale: Self.ruledOutScale).combined(with: .opacity))
      }
    }
  }
}

/// A word to pick, in Hanzi.
private struct ChoiceLabel: View {
  let word: String

  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    Text(script.spoken(word))
      .font(.system(.title, design: .rounded).weight(.medium))
      .lineLimit(1)
      .minimumScaleFactor(0.5)
      .frame(maxWidth: .infinity, minHeight: 56)
  }
}

/// The verdict on a pick, with — when it was the wrong word — that word and its reading, so the
/// learner can see what they heard the word as.
private struct AnswerFeedback: View {
  let outcome: QuizSession.Outcome
  let wrongPick: WordLookup?

  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified
  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  var body: some View {
    VStack(spacing: 12) {
      VerdictBadge(outcome: outcome)
      if let wrongPick {
        Text("Picked: \(script.spoken(wrongPick.word)) \(pickedReading(of: wrongPick))")
          .font(.title3)
          .opacity(0.85)
          .accessibilityIdentifier(AccessibilityID.listeningPicked)
      }
    }
    .multilineTextAlignment(.center)
    .foregroundStyle(QuizStyle.chromeLabel)
    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
  }

  private func pickedReading(of lookup: WordLookup) -> AttributedString {
    lookup.romanization(romanization).map(romanization.spoken) ?? AttributedString()
  }
}

/// The controls once the word is answered: hear it again, or move on.
private struct AnsweredControls: View {
  let onHear: () -> Void
  let onNext: () -> Void

  var body: some View {
    GlassContainer(spacing: 14) {
      HStack(spacing: 14) {
        QuizJudgementButton(title: "Hear It", systemImage: "speaker.wave.2", action: onHear)
        QuizJudgementButton(
          title: "Next",
          systemImage: "arrow.right",
          tint: QuizStyle.accent,
          prominent: true,
          action: onNext
        )
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier(AccessibilityID.quizNextButton)
      }
    }
    .frame(maxWidth: 440)
  }
}
