//
//  SpeakingRoundView.swift
//  Zili
//

import SwiftUI

/// One word's round on the speaking stage: the word to say, with the microphone already listening
/// and showing what it hears so far, then the verdict over the word's reading and the reading of
/// what was heard. Listening starts as the word appears and ends once the learner stops talking, so
/// the round asks for no taps at all — except under VoiceOver, whose own reading of the word the
/// microphone would hear, so there the learner starts it with Say It.
struct SpeakingRoundView: View {
  /// How far a long word may shrink to fit the stage's width.
  private static let hanziMinimumScale = 0.3

  let card: QuizCard
  let lexicon: Lexicon
  let listener: any MandarinListening

  @Environment(QuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss
  @Environment(\.accessibilityVoiceOverEnabled)
  private var isVoiceOverOn
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion
  @Environment(\.self)
  private var environment

  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified
  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  @ScaledMetric(relativeTo: .largeTitle)
  private var hanziSize: CGFloat = 120

  @State private var phase = SpeakingPhase.prompt
  @State private var listening: Task<Void, Never>?
  @State private var pronouncer = WordPronouncer()
  @State private var stageSize = CGSize.zero
  @State private var thrown = CGSize.zero
  @State private var isSkipping = false

  var body: some View {
    VStack(spacing: 24) {
      #if !os(visionOS)
        QuizTopBar(index: session.currentIndex, total: session.total) { dismiss() }
      #endif

      Spacer(minLength: 0)

      VStack(spacing: 20) {
        if let verdict = phase.verdict {
          SpeakingVerdictBadge(outcome: verdict)
        }
        Text(script.spoken(card.hanzi))
          .font(.system(size: hanziSize, weight: .medium))
          .minimumScaleFactor(Self.hanziMinimumScale)
          .lineLimit(1)
        if !isSkipping {
          SpeakingFeedback(
            phase: phase,
            reading: card.reading,
            listening: reading(of: listener.transcript),
            romanization: romanization
          )
        }
      }
      .foregroundStyle(QuizStyle.chromeLabel)
      .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
      .padding(.horizontal, 12)
      .offset(thrown)

      Spacer(minLength: 0)

      SpeakingControls(
        phase: phase,
        onSay: listen,
        onSkip: skip,
        onHear: { pronouncer.speak(card.hanzi) },
        onNext: { session.mark($0) }
      )
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .quizAmbientBackground(stageGradient)
    .animation(.smooth, value: phase)
    .onGeometryChange(for: CGSize.self) {
      $0.size
    } action: {
      stageSize = $0
    }
    .onAppear { if !isVoiceOverOn { listen() } }
    .onDisappear { listening?.cancel() }
    #if os(visionOS)
      .toolbar {
        ToolbarItem(placement: .principal) {
          QuizProgress(index: session.currentIndex, total: session.total)
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Close quiz", systemImage: "xmark") { dismiss() }
          .accessibilityIdentifier(AccessibilityID.quizCloseButton)
        }
      }
    #endif
  }

  /// The stage in the word's HSK band colors, as a flashcard wears them: the prompt face's while
  /// the word is being said, the answer face's once its verdict is in.
  private var stageGradient: LinearGradient {
    let palette = HSKPalette.palette(forBand: card.hskBand).resolved(in: environment)
    return phase.verdict == nil ? palette.promptGradient : palette.answerGradient
  }

  private func listen() {
    phase = .listening
    listening = Task {
      do {
        let heard = try await listener.listen()
        if !Task.isCancelled { grade(heard) }
      } catch {
        guard !Task.isCancelled, !(error is CancellationError) else { return }
        phase = .unheard(ErrorPresentation(error).title)
      }
    }
  }

  /// Grades what was heard. Only its Chinese counts, so a transcript with none — silence, or a
  /// conversation nearby — is asked for again rather than marked wrong.
  private func grade(_ heard: Heard) {
    let heardReading = heard.best.map(reading) ?? ""
    guard !heardReading.isEmpty else {
      phase = .unheard(String(localized: "Didn’t catch that."))
      return
    }
    let isCorrect = SpokenAnswer.matches(heard, word: card.word) {
      lexicon.lookup($0).numberedReadings
    }
    phase = .verdict(isCorrect ? .correct : .needsReview, heard: heardReading)
  }

  /// How `transcript` reads in the learner's romanization — what the learner said, shown by its
  /// sound rather than by the characters the recognizer happened to pick for it.
  private func reading(of transcript: String) -> String {
    SpokenReading.reading(of: transcript, in: romanization, lexicon: lexicon)
  }

  /// Gives up on the word, throwing it up and away the way a skipped flashcard goes. The microphone
  /// is put away first, at once, so only the word leaves.
  private func skip() {
    listening?.cancel()
    guard !isSkipping else { return }
    withTransaction(Transaction(animation: nil)) { isSkipping = true }
    guard !reduceMotion else {
      session.mark(.skipped)
      return
    }
    withAnimation(ThrowDirection.animation) {
      thrown = ThrowDirection.up.offScreenVector(in: stageSize)
    } completion: {
      session.mark(.skipped)
    }
  }
}

/// Where a round has got to: showing the word, listening to it said, asking for it again after
/// hearing nothing usable, or facing its verdict.
private enum SpeakingPhase: Hashable {
  case prompt
  case listening
  case unheard(String)
  case verdict(QuizSession.Outcome, heard: String)

  /// The outcome the word earned, or `nil` while it has yet to be said.
  var verdict: QuizSession.Outcome? {
    if case .verdict(let outcome, _) = self { outcome } else { nil }
  }
}

/// The verdict pressed onto the round once the word has been heard.
private struct SpeakingVerdictBadge: View {
  /// The slant a stamp lands at, as the drawing quiz presses its verdict on.
  private static let tilt = Angle.degrees(-6)

  let outcome: QuizSession.Outcome

  var body: some View {
    QuizVerdictBadge(
      title: outcome == .correct ? "Correct" : "Needs Improvement",
      systemImage: outcome == .correct ? "checkmark.circle.fill" : "xmark.circle.fill",
      color: outcome == .correct ? QuizStyle.correct : QuizStyle.review,
      emphasized: true
    )
    .padding(.horizontal, 20)
    .rotationEffect(Self.tilt)
    .accessibilityIdentifier(
      outcome == .correct ? AccessibilityID.speakingCorrect : AccessibilityID.speakingNeedsReview
    )
    .transition(ScaleTransition(1.6).combined(with: .opacity))
  }
}

/// What sits under the word: nothing yet on the prompt, since saying the word unaided is the test;
/// the microphone and the reading of what it hears so far while listening; why to try again; or,
/// with the verdict, the word's reading — and, when it was said wrong, the reading of what was
/// heard instead.
private struct SpeakingFeedback: View {
  let phase: SpeakingPhase
  let reading: String
  let listening: String
  let romanization: Romanization

  var body: some View {
    switch phase {
      case .prompt:
        EmptyView()
      case .listening:
        ListeningIndicator(heard: romanization.spoken(listening))
      case .unheard(let reason):
        Text(reason)
          .font(.title3.weight(.medium))
      case let .verdict(outcome, heard):
        VStack(spacing: 8) {
          Text(romanization.spoken(reading))
            .spokenByItsHanzi()
            .font(.system(.title, design: .rounded).weight(.medium))
          if outcome != .correct {
            Text("Heard: \(romanization.spoken(heard))")
              .font(.title3)
              .opacity(0.85)
              .accessibilityIdentifier(AccessibilityID.speakingHeard)
          }
        }
        .multilineTextAlignment(.center)
    }
  }
}

/// A pulsing microphone over what has been heard so far, so the learner can see they're heard.
private struct ListeningIndicator: View {
  let heard: AttributedString

  @ScaledMetric(relativeTo: .largeTitle)
  private var iconSize: CGFloat = 44

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "mic.fill")
        .font(.system(size: iconSize))
        .symbolEffect(.pulse)
        .accessibilityLabel("Listening")
      Text(heard.characters.isEmpty ? AttributedString(" ") : heard)
        .font(.title2)
        .opacity(0.85)
    }
  }
}

/// The round's controls, which are whatever it now asks for: say the word, give up on it, or hear
/// it said and move on.
private struct SpeakingControls: View {
  let phase: SpeakingPhase
  let onSay: () -> Void
  let onSkip: () -> Void
  let onHear: () -> Void
  let onNext: (QuizSession.Outcome) -> Void

  var body: some View {
    GlassContainer(spacing: 14) {
      HStack(spacing: 14) {
        switch phase {
          case .prompt, .unheard:
            QuizJudgementButton(title: "Skip", systemImage: "forward.fill", action: onSkip)
              .accessibilityIdentifier(AccessibilityID.quizSkipButton)
            QuizJudgementButton(
              title: phase == .prompt ? "Say It" : "Try Again",
              systemImage: "mic.fill",
              tint: QuizStyle.accent,
              prominent: true,
              action: onSay
            )
            .accessibilityIdentifier(AccessibilityID.speakingSayIt)
          case .listening:
            QuizJudgementButton(title: "Skip", systemImage: "forward.fill", action: onSkip)
              .accessibilityIdentifier(AccessibilityID.quizSkipButton)
          case .verdict(let outcome, _):
            QuizJudgementButton(title: "Hear It", systemImage: "speaker.wave.2", action: onHear)
            QuizJudgementButton(
              title: "Next",
              systemImage: "arrow.right",
              tint: QuizStyle.accent,
              prominent: true
            ) {
              onNext(outcome)
            }
            .accessibilityIdentifier(AccessibilityID.quizNextButton)
        }
      }
    }
    .frame(maxWidth: 360)
  }
}
