//
//  SpeakingSentenceRoundView.swift
//  Zili
//

import SwiftUI

/// One sentence's turn at reading aloud, on a flashcard. The card shows the sentence and the
/// microphone listens to the learner read it; when they stop, the card turns over to the sentence
/// with any characters not heard said right marked, its reading, and its translation, under the
/// verdict.
///
/// Practice says the sentence first, for the learner to say back, and lets them try again; a quiz
/// listens straight away and takes the first reading. Either way, under VoiceOver — whose own
/// reading of the card the microphone would hear — the learner starts listening with Say It.
struct SpeakingSentenceRoundView: View {
  let sentence: PracticeSentence
  let lexicon: Lexicon
  let listener: any MandarinListening
  let purpose: StudyPurpose
  let onClose: () -> Void

  @Environment(SentenceQuizSession.self)
  private var session
  @Environment(\.accessibilityVoiceOverEnabled)
  private var isVoiceOverOn
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  @State private var phase = SentencePhase.speaking
  @State private var isFlipped = false
  @State private var attempt: Task<Void, Never>?
  @State private var pronouncer = WordPronouncer(sharesMicrophone: true)
  @State private var stageSize = CGSize.zero
  @State private var topBarBottom: CGFloat = 0
  @State private var feedbackTop: CGFloat = 0
  @State private var cardBottom: CGFloat = 0
  @State private var safeAreaInsets = EdgeInsets()
  @State private var thrown = CGSize.zero
  @State private var isThrowing = false

  var body: some View {
    ZStack {
      #if !os(visionOS)
        if let next = session.peek {
          NextCardPeek(isUncovered: isThrowing, isRisen: thrown != .zero) {
            SentenceFlashcardView(
              sentence: next,
              matched: nil,
              isFlipped: .constant(false),
              contentInsets: cardContentInsets
            )
          }
          .ignoresSafeArea()
        }
      #endif

      SentenceFlashcardView(
        sentence: sentence,
        matched: phase.spoken?.matched,
        isFlipped: flip,
        contentInsets: cardContentInsets,
        onHearCharacter: sayWord(holdingCharacterAt:)
      )
      .onGeometryChange(for: CGFloat.self) {
        $0.frame(in: .global).maxY
      } action: {
        cardBottom = $0
      }
      .offset(thrown)
      #if os(visionOS)
        .frame(maxWidth: 420, maxHeight: 520)
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

        if !isThrowing {
          SentenceFeedback(
            phase: phase,
            listening: reading(of: listener.transcript),
            isHearing: listener.isHearing
          )
          .onGeometryChange(for: CGFloat.self) {
            $0.frame(in: .global).minY
          } action: {
            feedbackTop = $0
          }
        }

        SentenceControls(
          phase: phase,
          purpose: purpose,
          onSay: startListening,
          onSkip: { advance(correct: false) },
          onHear: { pronouncer.speak(sentence.hanzi) },
          onTryAgain: begin,
          onNext: { advance(correct: $0) }
        )
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
    .onAppear(perform: begin)
    .onDisappear(perform: stopAttempt)
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

  /// The card's side, which only the verdict turns over: until then a tap can't reveal the answer.
  private var flip: Binding<Bool> {
    Binding(
      get: { isFlipped },
      set: { if phase.spoken != nil { isFlipped = $0 } }
    )
  }

  /// Keeps the card's answer clear of the floating top bar, of the verdict and everything below it
  /// down to the card's bleeding edge, and of whatever the safe area holds beside the card.
  private var cardContentInsets: EdgeInsets {
    EdgeInsets(
      top: topBarBottom,
      leading: safeAreaInsets.leading,
      bottom: max(cardBottom - feedbackTop, 0),
      trailing: safeAreaInsets.trailing
    )
  }

  /// Turns the card back to the sentence and begins an attempt: practice says the sentence first,
  /// then either listens for it or, under VoiceOver, waits for Say It.
  private func begin() {
    stopAttempt()
    isFlipped = false
    phase = .speaking
    attempt = Task {
      if isVoiceOverOn {
        if purpose == .practice { await pronouncer.say(sentence.hanzi) }
        if !Task.isCancelled { phase = .waiting }
      } else if purpose == .practice {
        await listen { [pronouncer, hanzi = sentence.hanzi] in await pronouncer.say(hanzi) }
      } else {
        await listen()
      }
    }
  }

  private func startListening() {
    stopAttempt()
    attempt = Task { await listen() }
  }

  /// Listens for the sentence once `prelude` has played.
  private func listen(after prelude: @escaping @MainActor @Sendable () async -> Void = {}) async {
    do {
      let heard = try await listener.listen(for: .sentence) {
        await prelude()
        phase = .listening
      }
      if !Task.isCancelled { grade(heard) }
    } catch {
      guard !Task.isCancelled, !(error is CancellationError) else { return }
      phase = .unheard(ErrorPresentation(error).title)
    }
  }

  /// Grades what was heard and turns the card over to the answer, unless nothing Chinese was heard.
  private func grade(_ heard: Heard) {
    let spoken = SpokenSentence(
      heard,
      for: sentence,
      readings: { lexicon.lookup($0).numberedReadings },
      words: words(in:)
    )
    guard let spoken else {
      phase = .unheard(String(localized: "Didn’t catch that."))
      return
    }
    phase = .verdict(spoken, heard: reading(of: spoken.transcript))
    isFlipped = true
  }

  /// Says the word in the sentence holding the character at `position` among its Chinese
  /// characters. The word, rather than the character alone, is said as the sentence says it: 欢 is
  /// light in 喜欢, but said by itself it takes its full tone.
  private func sayWord(holdingCharacterAt position: Int) {
    let run = String(sentence.hanzi.filter(\.isChineseIdeograph))
    let characters = Array(run)
    let word = WordSegmenter.shared.words(in: run, using: WordResolver(lexicon: lexicon))
      .first { $0.contains(position) }
    if let word { pronouncer.speak(String(characters[word])) }
  }

  /// `run`'s characters split into words as a reader would.
  private func words(in run: String) -> [String] {
    let characters = Array(run)
    return WordSegmenter.shared.words(in: run, using: WordResolver(lexicon: lexicon))
      .map { String(characters[$0]) }
  }

  /// How `transcript` reads in the learner's romanization.
  private func reading(of transcript: String) -> String {
    SpokenReading.reading(of: transcript, in: romanization, lexicon: lexicon)
  }

  private func stopAttempt() {
    attempt?.cancel()
    pronouncer.stop()
  }

  /// Moves on to the next sentence, throwing this card off the way a judged flashcard goes.
  private func advance(correct: Bool) {
    guard !isThrowing else { return }
    stopAttempt()
    withTransaction(Transaction(animation: nil)) { isThrowing = true }
    guard !reduceMotion else {
      session.mark(correct: correct)
      return
    }
    withAnimation(ThrowDirection.animation) {
      thrown = ThrowDirection.of(correct ? .correct : .needsReview).offScreenVector(in: stageSize)
    } completion: {
      session.mark(correct: correct)
    }
  }
}

/// Where a turn has got to: the voice saying the sentence, waiting for Say It under VoiceOver,
/// listening to it read, asking for it again after hearing nothing usable, or its verdict.
private enum SentencePhase: Hashable {
  case speaking
  case waiting
  case listening
  case unheard(String)
  case verdict(SpokenSentence, heard: String)

  /// How the sentence was heard, once it has been.
  var spoken: SpokenSentence? {
    if case .verdict(let spoken, _) = self { spoken } else { nil }
  }
}

/// What sits under the card: the microphone and what it hears so far while listening, why to try
/// again, or the verdict — with, when the sentence was read wrong, the reading of what was heard.
private struct SentenceFeedback: View {
  let phase: SentencePhase
  let listening: String
  let isHearing: Bool

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  var body: some View {
    Group {
      switch phase {
        case .speaking, .waiting:
          EmptyView()
        case .listening:
          ListeningIndicator(heard: romanization.spoken(listening), isHearing: isHearing)
        case .unheard(let reason):
          Text(reason)
            .font(.title3.weight(.medium))
        case let .verdict(spoken, heard):
          VStack(spacing: 12) {
            VerdictBadge(outcome: spoken.isCorrect ? .correct : .needsReview)
            if !spoken.isCorrect {
              Text("Heard: \(romanization.spoken(heard))")
                .font(.title3)
                .opacity(0.85)
                .accessibilityIdentifier(AccessibilityID.speakingHeard)
            }
          }
      }
    }
    .multilineTextAlignment(.center)
    .foregroundStyle(QuizStyle.chromeLabel)
    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
  }
}

/// The turn's controls, which are whatever it now asks for: give up on the sentence, start
/// listening, try reading it again in practice or hear it in a quiz, or move on.
private struct SentenceControls: View {
  let phase: SentencePhase
  let purpose: StudyPurpose
  let onSay: () -> Void
  let onSkip: () -> Void
  let onHear: () -> Void
  let onTryAgain: () -> Void
  let onNext: (Bool) -> Void

  var body: some View {
    GlassContainer(spacing: 14) {
      HStack(spacing: 14) {
        switch phase {
          case .speaking, .listening:
            SkipButton(action: onSkip)
          case .waiting:
            SkipButton(action: onSkip)
            QuizJudgementButton(
              title: "Say It",
              systemImage: "mic.fill",
              tint: QuizStyle.accent,
              prominent: true,
              action: onSay
            )
            .accessibilityIdentifier(AccessibilityID.speakingSayIt)
          case .unheard:
            SkipButton(action: onSkip)
            QuizJudgementButton(
              title: "Try Again",
              systemImage: "arrow.counterclockwise",
              tint: QuizStyle.accent,
              prominent: true,
              action: onTryAgain
            )
            .accessibilityIdentifier(AccessibilityID.practiceTryAgain)
          case .verdict(let spoken, _):
            switch purpose {
              case .quiz:
                QuizJudgementButton(title: "Hear It", systemImage: "speaker.wave.2", action: onHear)
              case .practice:
                QuizJudgementButton(
                  title: "Try Again",
                  systemImage: "arrow.counterclockwise",
                  action: onTryAgain
                )
                .accessibilityIdentifier(AccessibilityID.practiceTryAgain)
            }
            QuizJudgementButton(
              title: "Next",
              systemImage: "arrow.right",
              tint: QuizStyle.accent,
              prominent: true
            ) {
              onNext(spoken.isCorrect)
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(AccessibilityID.quizNextButton)
        }
      }
    }
    .frame(maxWidth: 440)
  }
}

private struct SkipButton: View {
  let action: () -> Void

  var body: some View {
    QuizJudgementButton(title: "Skip", systemImage: "forward.fill", action: action)
      .accessibilityIdentifier(AccessibilityID.quizSkipButton)
  }
}
