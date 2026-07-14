//
//  DrawingQuizView.swift
//  Zili
//

import SwiftUI

/// Runs a drawing quiz from the shared ``QuizSession``: each character in the deck is shown with
/// its reading, then written by hand on a ``StrokeTestView`` and graded by the strokes it scored.
/// The session is owned by the configuration screen; the ``Lexicon`` comes along so each card's
/// character can be resolved to the glyph it must be written against.
struct DrawingQuizView: View {
  let lexicon: Lexicon

  @Environment(QuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss

  /// The deck only ever holds drawable characters, so a card whose glyph is missing means the
  /// stroke library and the deck have fallen out of step: pass over it rather than stranding the
  /// learner on a blank pad. Each round is keyed to its card, so the next character always enters
  /// on a fresh page.
  var body: some View {
    Group {
      if session.isFinished {
        QuizResultsView(onDone: doneAction)
      } else if let card = session.current, let graphic = graphic(for: card) {
        DrawingRoundView(card: card, graphic: graphic)
          .id(card.word)
      } else if session.current != nil {
        Color.clear.task { session.mark(.skipped) }
      } else {
        QuizEmptyDeckView(description: "The selected levels have no characters to draw.")
      }
    }
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
    #endif
  }

  /// On the Mac the quiz owns its window and the results stay up until it is closed; on iOS the
  /// quiz is a pushed screen, so Done pops it.
  private var doneAction: (() -> Void)? {
    #if os(macOS)
      nil
    #else
      { dismiss() }
    #endif
  }

  private func graphic(for card: QuizCard) -> HanziGraphic? {
    card.word.first.flatMap { lexicon.strokeGraphic(for: $0) }
  }
}

/// The verdict a finished character earns from the strokes the evaluator scored: correct only
/// when every stroke was the right shape, drawn in the right order.
enum DrawingVerdict {
  static func outcome(for result: StrokeTestResult) -> QuizSession.Outcome {
    result.verdicts.allSatisfy { $0 == .correct } ? .correct : .needsReview
  }
}

/// One character's round, on the writing board's fixed indigo stage: the character and its
/// reading, then the practice paper it is written on, then the verdict pressed onto the finished
/// glyph. Each phase swaps what the middle of the board holds and what its one control does.
private struct DrawingRoundView: View {
  let card: QuizCard
  let graphic: HanziGraphic

  @Environment(QuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss

  @State private var phase = DrawingPhase.prompt

  var body: some View {
    VStack(spacing: 24) {
      QuizTopBar(index: session.currentIndex, total: session.total) { dismiss() }

      Spacer(minLength: 0)

      if phase == .prompt {
        CharacterPrompt(card: card)
      } else {
        VStack(spacing: 20) {
          CharacterHeader(card: card)
          WritingPad(graphic: graphic, verdict: phase.verdict, onComplete: grade)
        }
        .transition(.blurReplace)
      }

      Spacer(minLength: 0)

      DrawingControls(
        phase: phase,
        onDraw: { phase = .drawing },
        onSkip: { session.mark(.skipped) },
        onNext: { session.mark($0) }
      )
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .quizAmbientBackground(QuizStyle.promptGradient)
    .animation(.smooth, value: phase)
  }

  private func grade(_ result: StrokeTestResult) {
    phase = .verdict(DrawingVerdict.outcome(for: result))
  }
}

/// Where a round has got to: reading the character, writing it, or facing its verdict.
private enum DrawingPhase: Hashable {
  case prompt
  case drawing
  case verdict(QuizSession.Outcome)

  /// The outcome the finished character earned, or `nil` while it is still being written.
  var verdict: QuizSession.Outcome? {
    if case .verdict(let outcome) = self { outcome } else { nil }
  }
}

/// The character to write, above its reading — the whole prompt, since a drawing quiz asks for
/// the glyph rather than the meaning.
private struct CharacterPrompt: View {
  let card: QuizCard

  @ScaledMetric(relativeTo: .largeTitle)
  private var hanziSize: CGFloat = 140

  var body: some View {
    VStack(spacing: 16) {
      Text(card.hanzi)
        .font(.system(size: hanziSize, weight: .medium))
        .minimumScaleFactor(0.4)
        .foregroundStyle(QuizStyle.chromeLabel)
      if !card.reading.isEmpty {
        Text(card.reading)
          .font(.system(.title, design: .rounded).weight(.medium))
          .foregroundStyle(QuizStyle.chromeLabel.opacity(0.9))
      }
    }
    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    .transition(.blurReplace)
  }
}

/// The character being written, kept above the paper while the learner writes it. A drawing quiz
/// tests the hand, not the memory of which glyph was asked for — the strokes and their order are
/// what is being scored, so the target stays in sight.
private struct CharacterHeader: View {
  let card: QuizCard

  @ScaledMetric(relativeTo: .title)
  private var hanziSize: CGFloat = 44

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 14) {
      Text(card.hanzi)
        .font(.system(size: hanziSize, weight: .medium))
      if !card.reading.isEmpty {
        Text(card.reading)
          .font(.system(.title3, design: .rounded).weight(.medium))
          .foregroundStyle(QuizStyle.chromeLabel.opacity(0.85))
      }
    }
    .foregroundStyle(QuizStyle.chromeLabel)
  }
}

/// The practice paper: a ``StrokeTestView`` on a white sheet, held in the light appearance
/// whatever the system's — Hanzi are written in dark ink on white paper, and the scored strokes'
/// green, red, and purple read against it in both. Once a verdict lands the sheet stops taking
/// strokes and wears the badge.
private struct WritingPad: View {
  private static let cornerRadius: CGFloat = 24

  let graphic: HanziGraphic
  let verdict: QuizSession.Outcome?
  let onComplete: (StrokeTestResult) -> Void

  var body: some View {
    StrokeTestView(graphic: graphic, onComplete: onComplete)
      .padding(12)
      .background {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
          .fill(.white)
      }
      .environment(\.colorScheme, .light)
      .allowsHitTesting(verdict == nil)
      .overlay { badge }
      .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
      .frame(maxWidth: 460)
  }

  @ViewBuilder private var badge: some View {
    if let verdict {
      QuizVerdictBadge(
        title: Self.title(for: verdict),
        systemImage: Self.symbol(for: verdict),
        color: Self.color(for: verdict),
        emphasized: true
      )
      .padding(.horizontal, 20)
      .rotationEffect(.degrees(-6))
      .transition(.scale(scale: 1.6).combined(with: .opacity))
    }
  }

  private static func title(for outcome: QuizSession.Outcome) -> LocalizedStringKey {
    outcome == .correct ? "Correct" : "Needs Improvement"
  }

  private static func symbol(for outcome: QuizSession.Outcome) -> String {
    outcome == .correct ? "checkmark.circle.fill" : "xmark.circle.fill"
  }

  private static func color(for outcome: QuizSession.Outcome) -> Color {
    outcome == .correct ? QuizStyle.correct : QuizStyle.review
  }
}

/// The board's single control, which is whatever the round now asks for: start writing, give up
/// on the character, or accept the verdict and move on.
private struct DrawingControls: View {
  let phase: DrawingPhase
  let onDraw: () -> Void
  let onSkip: () -> Void
  let onNext: (QuizSession.Outcome) -> Void

  var body: some View {
    GlassContainer(spacing: 14) {
      switch phase {
        case .prompt:
          QuizJudgementButton(
            title: "Draw it!",
            systemImage: "hand.draw",
            tint: QuizStyle.accent,
            prominent: true,
            action: onDraw
          )
          .accessibilityIdentifier(AccessibilityID.drawingDrawButton)
        case .drawing:
          QuizJudgementButton(title: "Skip", systemImage: "forward.fill", action: onSkip)
            .accessibilityIdentifier(AccessibilityID.quizSkipButton)
        case .verdict(let outcome):
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
    .frame(maxWidth: 320)
  }
}

#Preview("Prompt · 永") {
  DrawingQuizPreview()
}

/// Loads the real ``Lexicon`` so the pad draws the shipped stroke data, over a short deck.
private struct DrawingQuizPreview: View {
  private static let deck = [
    QuizCard(word: "永", hanzi: "永", reading: "yǒng", definition: "forever"),
    QuizCard(word: "人", hanzi: "人", reading: "rén", definition: "person")
  ]

  @State private var lexicon: Lexicon?

  var body: some View {
    NavigationStack {
      if let lexicon {
        DrawingQuizView(lexicon: lexicon)
          .environment(QuizSession(deck: Self.deck))
      } else {
        ProgressView()
      }
    }
    .environment(FavoritesStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
