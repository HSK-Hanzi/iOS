//
//  SpeakingPracticeRoundView.swift
//  Zili
//

import SwiftUI

/// One word's turn in speaking practice, on a flashcard. The card shows the word while the system
/// voice says it; once the voice has finished, the microphone listens to the learner say it back,
/// and when they stop the card turns over to the word's reading and meaning under the verdict on
/// what was heard. The turn asks for no taps until the verdict — except under VoiceOver, whose own
/// speech the microphone would hear, so there the learner starts listening with Say It.
struct SpeakingPracticeRoundView: View {
  private static let front = FlashcardFace(
    showsHanzi: true,
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
  let listener: any MandarinListening
  let onClose: () -> Void

  @Environment(QuizSession.self)
  private var session
  @Environment(\.accessibilityVoiceOverEnabled)
  private var isVoiceOverOn
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  @State private var phase = PracticePhase.speaking
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

        if !isThrowing {
          PracticeFeedback(
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

        PracticeControls(
          phase: phase,
          onSay: startListening,
          onSkip: { advance(.skipped) },
          onTryAgain: sayAndListen,
          onNext: { advance($0) }
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
    .onAppear(perform: sayAndListen)
    .onDisappear(perform: stopAttempt)
    #if os(visionOS)
      .toolbar {
        ToolbarItem(placement: .principal) {
          QuizProgress(index: session.currentIndex, total: session.total)
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Close practice", systemImage: "xmark", action: onClose)
          .accessibilityIdentifier(AccessibilityID.quizCloseButton)
        }
      }
    #endif
  }

  /// The card's side, which only the verdict turns over: until then a tap can't reveal the answer.
  private var flip: Binding<Bool> {
    Binding(
      get: { isFlipped },
      set: { if phase.isGraded { isFlipped = $0 } }
    )
  }

  /// Keeps the card's content clear of the floating top bar, of the verdict and everything below
  /// it down to the card's bleeding edge, and of whatever the safe area holds beside the card.
  private var cardContentInsets: EdgeInsets {
    EdgeInsets(
      top: topBarBottom,
      leading: safeAreaInsets.leading,
      bottom: max(cardBottom - feedbackTop, 0),
      trailing: safeAreaInsets.trailing
    )
  }

  /// Turns the card back to the word, says it, and then listens for it said back — or, under
  /// VoiceOver, waits for Say It.
  private func sayAndListen() {
    stopAttempt()
    isFlipped = false
    phase = .speaking
    attempt = Task {
      if isVoiceOverOn {
        await pronouncer.say(card.hanzi)
        if !Task.isCancelled { phase = .waiting }
      } else {
        await listen { [pronouncer, hanzi = card.hanzi] in await pronouncer.say(hanzi) }
      }
    }
  }

  private func startListening() {
    stopAttempt()
    attempt = Task { await listen() }
  }

  /// Listens for the word once `prelude` has played.
  private func listen(after prelude: @escaping @MainActor @Sendable () async -> Void = {}) async {
    do {
      let heard = try await listener.listen(for: .word) {
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
    switch SpokenVerdict(heard, for: card, lexicon: lexicon, romanization: romanization) {
      case .unheard:
        phase = .unheard(String(localized: "Didn’t catch that."))
      case let .graded(isCorrect, heardReading):
        phase = .verdict(isCorrect ? .correct : .needsReview, heard: heardReading)
        isFlipped = true
    }
  }

  /// How `transcript` reads in the learner's romanization.
  private func reading(of transcript: String) -> String {
    SpokenReading.reading(of: transcript, in: romanization, lexicon: lexicon)
  }

  private func stopAttempt() {
    attempt?.cancel()
    pronouncer.stop()
  }

  /// Moves on to the next word, throwing this card off the way a judged flashcard goes.
  private func advance(_ outcome: QuizSession.Outcome) {
    guard !isThrowing else { return }
    stopAttempt()
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

/// Where a turn has got to: the voice saying the word, waiting for Say It under VoiceOver,
/// listening to it said back, asking for it again after hearing nothing usable, or its verdict.
private enum PracticePhase: Hashable {
  case speaking
  case waiting
  case listening
  case unheard(String)
  case verdict(QuizSession.Outcome, heard: String)

  var isGraded: Bool {
    if case .verdict = self { true } else { false }
  }
}

/// What sits under the card: the microphone and what it hears so far while listening, why to try
/// again, or the verdict — with, when the word was said wrong, the reading of what was heard.
private struct PracticeFeedback: View {
  let phase: PracticePhase
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
        case let .verdict(outcome, heard):
          VStack(spacing: 12) {
            VerdictBadge(outcome: outcome)
            if outcome != .correct {
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

/// The turn's controls, which are whatever it now asks for: give up on the word, start listening,
/// try saying it again, or move on.
private struct PracticeControls: View {
  let phase: PracticePhase
  let onSay: () -> Void
  let onSkip: () -> Void
  let onTryAgain: () -> Void
  let onNext: (QuizSession.Outcome) -> Void

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
            TryAgainButton(prominent: true, action: onTryAgain)
          case .verdict(let outcome, _):
            TryAgainButton(prominent: false, action: onTryAgain)
            QuizJudgementButton(
              title: "Next",
              systemImage: "arrow.right",
              tint: QuizStyle.accent,
              prominent: true
            ) {
              onNext(outcome)
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

private struct TryAgainButton: View {
  let prominent: Bool
  let action: () -> Void

  var body: some View {
    QuizJudgementButton(
      title: "Try Again",
      systemImage: "arrow.counterclockwise",
      tint: prominent ? QuizStyle.accent : nil,
      prominent: prominent,
      action: action
    )
    .accessibilityIdentifier(AccessibilityID.practiceTryAgain)
  }
}
